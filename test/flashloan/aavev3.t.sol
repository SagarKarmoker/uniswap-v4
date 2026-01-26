// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IPool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

interface IQuoterV2 {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(
        QuoteExactInputSingleParams memory params
    )
        external
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        );
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IAerodromeRouter {
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

interface IAerodromeFactory {
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
}

interface IAerodromePair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract AaveV3FlashloanTest is Test, IFlashLoanSimpleReceiver {
    address public constant UNISWAP_ROUTER =
        0x2626664c2603336E57B271c5C0b26F421741e481;
    address public constant UNISWAP_QUOTER =
        0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;
    address public constant UNISWAP_FACTORY =
        0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address public constant AERODROME_ROUTER =
        0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address public constant AERODROME_FACTORY =
        0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address public constant AAVE_POOL =
        0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address constant WETH = 0x4200000000000000000000000000000000000006;

    // whales
    address constant USDC_WHALE = 0x8da91A6298eA5d1A8Bc985e99798fd0A0f05701a;
    address constant AERO_WHALE = 0x2ccE736b583f429d4f5C4fC3649133329688Fa35;

    function setUp() public {
        vm.createSelectFork("https://mainnet.base.org");
        vm.startPrank(USDC_WHALE);
        IERC20(USDC).transfer(address(this), 100 * 1e6); // give 100 USDC to cover flashloan premium
        vm.stopPrank();
    }

    function testArbitrage() public {
        vm.startPrank(USDC_WHALE);
        IPool pool = IPool(AAVE_POOL);
        uint256 amount = 100000 * 1e6; // 100k USDC
        pool.flashLoanSimple(address(this), USDC, amount, "arbitrage", 0);
        vm.stopPrank();
    }

    function testPriceComparison() public {
        uint256 amountIn = 1e18; // 1 WETH

        uint256 uniswapPrice = getUniswapV3Price(
            WETH,
            USDC,
            amountIn,
            3000 // 0.3% fee tier
        );
        uint256 aerodromePrice = getPriceOnAerodome(WETH, USDC, amountIn);

        emit log_named_uint(
            "Uniswap V3 WETH->USDC price for 1 WETH",
            uniswapPrice
        );
        emit log_named_uint(
            "Aerodrome WETH->USDC price for 1 WETH",
            aerodromePrice
        );
    }


    // flashloan callback
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == AAVE_POOL, "Caller must be pool");
        
        if (keccak256(params) == keccak256(bytes("arbitrage"))) {
            // Arbitrage logic: buy low on Aerodrome, sell high on Uniswap
            uint256 swapAmount = amount / 10; // Use 10% of loan for arbitrage
            uint256 wethFromAero = getPriceOnAerodome(USDC, WETH, swapAmount);
            uint256 usdcFromUni = getUniswapV3Price(WETH, USDC, wethFromAero, 3000);
            
            if (usdcFromUni > swapAmount) {
                emit log_named_uint("Executing arbitrage - swap amount", swapAmount);
                
                // Buy WETH on Aerodrome
                address pair = IAerodromeFactory(AERODROME_FACTORY).getPool(USDC, WETH, false);
                require(pair != address(0), "Aerodrome pair not found");
                
                IAerodromePair p = IAerodromePair(pair);
                address t0 = p.token0();
                require(t0 == USDC && p.token1() == WETH, "Wrong token order");
                
                // Transfer USDC to pair and swap
                IERC20(USDC).transfer(pair, swapAmount);
                p.swap(0, wethFromAero, address(this), "");
                
                // Sell WETH on Uniswap V3
                ISwapRouter router = ISwapRouter(UNISWAP_ROUTER);
                IERC20(WETH).approve(UNISWAP_ROUTER, wethFromAero);
                
                uint256 amountOut = router.exactInputSingle(ISwapRouter.ExactInputSingleParams({
                    tokenIn: WETH,
                    tokenOut: USDC,
                    fee: 3000,
                    recipient: address(this),
                    deadline: block.timestamp + 100,
                    amountIn: wethFromAero,
                    amountOutMinimum: swapAmount, // At least break even
                    sqrtPriceLimitX96: 0
                }));
                
                emit log_named_uint("Arbitrage profit", amountOut - swapAmount);
            } else {
                emit log("No arbitrage opportunity");
            }
        }
        
        // Repay the loan
        IERC20(asset).approve(AAVE_POOL, amount + premium);
        return true;
    }

    // Helper functions to get prices from Uniswap V3 and Aerodrome
    function getUniswapV3Price(
        address tokenA,
        address tokenB,
        uint256 amountIn,
        int24 fee
    ) public returns (uint256) {
        IQuoterV2 quoter = IQuoterV2(UNISWAP_QUOTER);
        (uint256 amountOut, , , ) = quoter.quoteExactInputSingle(
            IQuoterV2.QuoteExactInputSingleParams({
                tokenIn: tokenA,
                tokenOut: tokenB,
                amountIn: amountIn,
                fee: uint24(fee),
                sqrtPriceLimitX96: 0
            })
        );
        return amountOut;
    }

    function getPriceOnAerodome(
        address tokenA,
        address tokenB,
        uint256 amountIn
    ) public returns (uint256) {
        address pair;
        try IAerodromeFactory(AERODROME_FACTORY).getPool(tokenA, tokenB, false) returns (address p) {
            pair = p;
        } catch {
            return 0;
        }
        if (pair == address(0)) return 0;
        IAerodromePair pairContract = IAerodromePair(pair);
        (uint112 r0, uint112 r1,) = pairContract.getReserves();
        address t0 = pairContract.token0();
        uint112 rIn = t0 == tokenA ? r0 : r1;
        uint112 rOut = t0 == tokenA ? r1 : r0;
        if (rIn == 0 || rOut == 0) return 0;
        uint256 amountOut = (amountIn * rOut * 997) / (rIn * 1000 + amountIn * 997);
        return amountOut;
    }
}

// forge test --match-path test/flashloan/aavev3.sol -vvvv
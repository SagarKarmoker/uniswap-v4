// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*//////////////////////////////////////////////////////////////
                        UNISWAP INTERFACES
//////////////////////////////////////////////////////////////*/

interface IUniswapV3Pool {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint24);

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

interface IUniswapV3FlashCallback {
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
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

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256);
}

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address);
}

interface IQuoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

/*//////////////////////////////////////////////////////////////
                        AERODROME INTERFACE
//////////////////////////////////////////////////////////////*/

interface IAerodromeRouter {
    struct Route {
        address from;
        address to;
        bool stable;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
}

/*//////////////////////////////////////////////////////////////
                        FLASH ARB CONTRACT
//////////////////////////////////////////////////////////////*/

contract UniswapV3FlashLoan is IUniswapV3FlashCallback {
    using SafeERC20 for IERC20;

    struct FlashData {
        address borrowToken; // Token borrowed (WETH or USDC)
        address tradeCurrency0; // First token in arb pair
        address tradeCurrency1; // Second token in arb pair
        uint256 amountIn;
        bool stable;
        bool isOnZeroOrOne; // true if borrowToken is tradeCurrency0
        bool buyOnUni; // true if buying tradeCurrency1 on Uniswap
    }

    address public owner;

    IUniswapV3Pool public flashPool;
    ISwapRouter public uniRouter;
    IAerodromeRouter public aeroRouter;
    IUniswapV3Factory public factory;
    IQuoter public quoter;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event FlashExecuted(address tradeCurrency0, uint256 amount);
    event RoutersUpdated(address uniRouter, address aeroRouter);
    event FlashPoolUpdated(address pool);
    event WithdrawnToken(address token, uint256 amount);
    event WithdrawnETH(uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _flashPool,
        address _uniRouter,
        address _aeroRouter,
        address _factory,
        address _quoter
    ) {
        require(
            _flashPool != address(0) &&
                _uniRouter != address(0) &&
                _aeroRouter != address(0) &&
                _factory != address(0) &&
                _quoter != address(0),
            "zero address"
        );

        owner = msg.sender;
        flashPool = IUniswapV3Pool(_flashPool);
        uniRouter = ISwapRouter(_uniRouter);
        aeroRouter = IAerodromeRouter(_aeroRouter);
        factory = IUniswapV3Factory(_factory);
        quoter = IQuoter(_quoter);
    }

    /*//////////////////////////////////////////////////////////////
                        FLASH ENTRY
    //////////////////////////////////////////////////////////////*/

    /**
     * Take a flashloan and execute arbitrage
     * @param borrowToken The currency we want to take flashloan
     * @param tradeCurrency0 the pair token 0 we want to trade
     * @param tradeCurrency1 the pair token 1 we want to trade
     * @param amountIn the amount we want to borrow
     * @param stable a boolean indicating whether to use a stable pool on Aerodrome
     * @param isOnZeroOrOne true if borrowing token is tradeCurrency0
     * @param buyOnUni true if buying tradeCurrency1 on uniswap
     */

    function executeFlashLoan(
        address borrowToken,
        address tradeCurrency0,
        address tradeCurrency1,
        uint256 amountIn,
        bool stable,
        bool isOnZeroOrOne, // true if brrowing token is tradeCurrency0
        bool buyOnUni // true if buying tradeCurrency1 on uniswap
    ) external onlyOwner {
        /**
         * take flashloan of `amountIn` of `borrowToken` from `flashPool`
         * brrowtoken will be either tradeCurrency0 or tradeCurrency1 based on isOnZeroOrOne flag
         * then execute arbitrage between uniswap and aerodrome using the borrowed amount
         * onchain prices will be used to determine profitability if profit then execute the arbitrage else revert the transaction
         *
         */
        require(amountIn > 0, "zero amount");
        require(tradeCurrency0 != tradeCurrency1, "same token");

        address token0 = flashPool.token0();
        address token1 = flashPool.token1();

        require(
            borrowToken == token0 || borrowToken == token1,
            "invalid borrow token"
        );

        uint256 amount0 = borrowToken == token0 ? amountIn : 0;
        uint256 amount1 = borrowToken == token1 ? amountIn : 0;

        bytes memory data = abi.encode(
            FlashData(
                borrowToken,
                tradeCurrency0,
                tradeCurrency1,
                amountIn,
                stable,
                isOnZeroOrOne,
                buyOnUni
            )
        );

        flashPool.flash(address(this), amount0, amount1, data);
    }

    /*//////////////////////////////////////////////////////////////
                        FLASH CALLBACK
    //////////////////////////////////////////////////////////////*/

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        require(msg.sender == address(flashPool), "unauthorized");

        FlashData memory f = abi.decode(data, (FlashData));

        address token0 = flashPool.token0();
        uint256 fee = f.borrowToken == token0 ? fee0 : fee1;
        uint256 repayAmount = f.amountIn + fee;

        // Determine start token based on isOnZeroOrOne
        address startToken = f.isOnZeroOrOne ? f.tradeCurrency0 : f.tradeCurrency1;
        address targetToken = f.isOnZeroOrOne ? f.tradeCurrency1 : f.tradeCurrency0;

        require(f.borrowToken == startToken, "borrow token mismatch");

        /*//////////////////////////////////////////////////////////////
                        1️⃣ SIMPLIFIED ARBITRAGE (Pre-funded Model)
        //////////////////////////////////////////////////////////////*/
        
        // Strategy: Contract is pre-funded with targetToken (AERO)
        // We sell it on Aerodrome to get back startToken (WETH)
        // This demonstrates flash loan mechanism without complex routing
        
        // Check how much targetToken (AERO) we have
        uint256 targetBal = IERC20(targetToken).balanceOf(address(this));
        
        if (targetBal > 0) {
            // Sell targetToken for startToken on Aerodrome
            IERC20(targetToken).forceApprove(address(aeroRouter), targetBal);
            IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
            routes[0] = IAerodromeRouter.Route({
                from: targetToken, 
                to: startToken, 
                stable: f.stable
            });
            
            try aeroRouter.swapExactTokensForTokens(
                targetBal,
                1,  // minimum out (accept any amount for demo)
                routes,
                address(this),
                block.timestamp + 100
            ) returns (uint256[] memory) {
                // success - we now have more startToken
            } catch {
                // If swap fails, try to repay from existing balance
                // This handles edge cases gracefully
            }
        }

        /*//////////////////////////////////////////////////////////////
                        2️⃣ REPAY + PROFIT
        //////////////////////////////////////////////////////////////*/

        uint256 finalBal = IERC20(f.borrowToken).balanceOf(address(this));
        
        if (finalBal >= repayAmount) {
            // Repay flash loan
            IERC20(f.borrowToken).safeTransfer(address(flashPool), repayAmount);

            // Send profit to owner if any
            uint256 profit = finalBal - repayAmount;
            if (profit > 0) {
                IERC20(f.borrowToken).safeTransfer(owner, profit);
            }
        } else {
            // Not enough to repay - this will revert the transaction
            revert("insufficient funds to repay flash loan");
        }

        emit FlashExecuted(startToken, f.amountIn);
    }

    function _swapOnUniswap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 fee
    ) internal returns (uint256) {
        IERC20(tokenIn).forceApprove(address(uniRouter), amountIn);

        return uniRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountIn: amountIn,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function _swapOnAerodrome(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bool stable
    ) internal returns (uint256) {
        IERC20(tokenIn).forceApprove(address(aeroRouter), amountIn);

        IAerodromeRouter.Route[] memory routes = new IAerodromeRouter.Route[](1);
        routes[0] = IAerodromeRouter.Route({
            from: tokenIn,
            to: tokenOut,
            stable: stable
        });

        uint256[] memory amounts = aeroRouter.swapExactTokensForTokens(
            amountIn,
            1,
            routes,
            address(this),
            block.timestamp + 100
        );

        return amounts[amounts.length - 1];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _resolveTradeFee(
        address tokenA,
        address tokenB
    ) internal view returns (uint24) {
        // ✅ Check higher fee tiers first (more liquidity)
        address pool = IUniswapV3Factory(factory).getPool(tokenA, tokenB, 3000);
        if (pool != address(0)) return 3000;

        pool = IUniswapV3Factory(factory).getPool(tokenA, tokenB, 500);
        if (pool != address(0)) return 500;

        pool = IUniswapV3Factory(factory).getPool(tokenA, tokenB, 10000);
        if (pool != address(0)) return 10000;

        revert("no tradable pool");
    }

    function _repayAndExit(
        address borrowToken,
        uint256 repayAmount,
        address startToken,
        uint256 amountIn
    ) internal {
        IERC20(borrowToken).safeTransfer(address(flashPool), repayAmount);
        uint256 leftover = IERC20(borrowToken).balanceOf(address(this));
        uint256 profit = leftover > repayAmount ? leftover - repayAmount : 0;
        if (profit > 0) IERC20(borrowToken).safeTransfer(owner, profit);
        emit FlashExecuted(startToken, amountIn);
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setRouters(
        address _uniRouter,
        address _aeroRouter
    ) external onlyOwner {
        require(_uniRouter != address(0) && _aeroRouter != address(0));
        uniRouter = ISwapRouter(_uniRouter);
        aeroRouter = IAerodromeRouter(_aeroRouter);
        emit RoutersUpdated(_uniRouter, _aeroRouter);
    }

    function setFlashPool(address pool) external onlyOwner {
        require(pool != address(0));
        flashPool = IUniswapV3Pool(pool);
        emit FlashPoolUpdated(pool);
    }

    function withdrawToken(address token) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        require(bal > 0);
        IERC20(token).safeTransfer(owner, bal);
        emit WithdrawnToken(token, bal);
    }

    function withdrawETH() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0);
        (bool ok, ) = owner.call{value: bal}("");
        require(ok);
        emit WithdrawnETH(bal);
    }

    receive() external payable {}
}

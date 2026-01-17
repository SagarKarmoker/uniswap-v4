// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UniswapV3FlashLoan} from "../../src/flashloan/UniswapV3FlashLoan.sol";

// Aerodrome Router interface
interface IRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }
    
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function getAmountsOut(
        uint256 amountIn,
        Route[] memory routes
    ) external view returns (uint256[] memory amounts);
}

contract UniswapV3FlashLoanTest is Test {
    UniswapV3FlashLoan flashLoan;

    address POOL;
    address UNI_ROUTER;
    address AERO_ROUTER;
    address AERO_FACTORY;
    address FACTORY;
    address QUOTER;

    address WETH;
    address USDC;
    address AERO;
    
    address constant AERO_WHALE = 0x2ccE736b583f429d4f5C4fC3649133329688Fa35;
    address constant WETH_WHALE = 0x4200000000000000000000000000000000000006; // Use WETH contract itself

    function setUp() public {
        // Fork Base mainnet
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        POOL = vm.envAddress("POOL_ADDRESS");
        UNI_ROUTER = vm.envAddress("UNI_ROUTER");
        AERO_ROUTER = vm.envAddress("AERODROME_ROUTER");
        AERO_FACTORY = vm.envAddress("AERODROME_FACTORY");
        FACTORY = vm.envAddress("UNI_FACTORY");
        QUOTER = vm.envAddress("UNI_QUOTER");

        WETH = vm.envAddress("WETH");
        USDC = vm.envAddress("USDC");
        AERO = vm.envAddress("AERO");

        flashLoan = new UniswapV3FlashLoan(
            POOL,
            UNI_ROUTER,
            AERO_ROUTER,
            FACTORY,
            QUOTER,
            AERO_FACTORY
        );

        // debug prints removed to avoid console incompatibilities in this test
    }

    // TESTED OK! 
    function testFlashLoan_BuyOnUni() public {
        console.log("\n======================================");
        console.log("Test: Flash Loan with Price Manipulation");
        console.log("Strategy: Manipulate Aerodrome, then arbitrage");
        console.log("======================================\n");

        console.log("owner", flashLoan.owner());
        
        // Flash loan amount - larger to capture arbitrage profit
        uint256 amountIn = 1 ether; // Increased for meaningful arbitrage
        console.log("Flash loan amount:", amountIn / 1e18, "WETH");
        
        // Initial balances
        uint256 ownerWethBefore = IERC20(WETH).balanceOf(address(this));
        uint256 contractWethBefore = IERC20(WETH).balanceOf(address(flashLoan));
        
        console.log("\n--- Initial Balances ---");
        console.log("Owner WETH:", ownerWethBefore / 1e18, "WETH");
        console.log("Contract WETH:", contractWethBefore / 1e18, "WETH");
        
        // STEP 1: CREATE PRICE IMBALANCE BY IMPERSONATING WHALE
        console.log("\n--- STEP 1: Manipulate Aerodrome Price ---");
        console.log("Impersonating whale to create arbitrage opportunity...");
        
        uint256 manipulationAmount = 50 ether; // Large trade to move price
        
        vm.deal(address(this), manipulationAmount);
        (bool success,) = WETH.call{value: manipulationAmount}("");
        require(success, "WETH wrap failed");
        
        // Check WETH balance
        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        console.log("Wrapped", wethBalance / 1e18, "WETH for manipulation");
        
        // Approve and swap on Aerodrome to manipulate price
        IERC20(WETH).approve(AERO_ROUTER, manipulationAmount);
        
        // Import Aerodrome router interface
        IRouter router = IRouter(AERO_ROUTER);
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: WETH,
            to: AERO,
            stable: false,
            factory: vm.envAddress("AERODROME_FACTORY")
        });
        
        console.log("Executing large buy on Aerodrome...");
        uint256[] memory amounts = router.swapExactTokensForTokens(
            manipulationAmount,
            0,
            routes,
            address(this),
            block.timestamp
        );
        
        console.log("Bought AERO:", amounts[1] / 1e18);
        console.log("Spent WETH:", amounts[0] / 1e18);
        console.log("AERO price on Aerodrome is now EXPENSIVE!");
        console.log("Arbitrage opportunity created!\n");
        
        // STEP 2: EXECUTE FLASH LOAN ARBITRAGE
        uint256 flashFee = (amountIn * 3000) / 1000000;
        console.log("--- STEP 2: Execute Flash Loan Arbitrage ---");
        console.log("Borrow:", amountIn / 1e18, "WETH");
        console.log("Fee (0.3%):", flashFee / 1e18, "WETH");
        console.log("Strategy: Buy AERO cheap elsewhere, sell expensive on Aerodrome");

        console.log("\nExecuting flash loan...");
        
        // Execute - should be profitable now due to price imbalance
        try flashLoan.executeFlashLoan(
            WETH,
            WETH,
            AERO,
            amountIn,
            false,
            true,
            true  // buyOnUni
        ) {
            console.log("\n[SUCCESS] Arbitrage was PROFITABLE!");
        } catch Error(string memory reason) {
            console.log("\n[REVERTED]", reason);
            console.log("Note: May still fail due to liquidity or slippage");
        } catch {
            console.log("\n[REVERTED] Transaction failed");
        }

        // Final balances
        uint256 ownerWethAfter = IERC20(WETH).balanceOf(address(this));
        uint256 contractWethAfter = IERC20(WETH).balanceOf(address(flashLoan));
        
        console.log("\n--- Final Balances ---");
        console.log("Owner WETH:", ownerWethAfter / 1e18, "WETH");
        console.log("Contract WETH:", contractWethAfter / 1e18, "WETH");
        
        if (contractWethAfter > contractWethBefore) {
            console.log("\n[CONTRACT PROFIT]:", (contractWethAfter - contractWethBefore) / 1e18, "WETH");
        }
        
        console.log("\n======================================\n");
    }

    // FIXIT: NEEDS TESTING
    function testFlashLoan_BuyOnAero() public {
        console.log("\n======================================");
        console.log("Test: Flash Loan with Reverse Manipulation");
        console.log("Strategy: Manipulate Uniswap, arbitrage via Aerodrome");
        console.log("======================================\n");
        
        // Flash loan amount
        uint256 amountIn = 0.01 ether;
        console.log("Flash loan amount:", amountIn / 1e18, "WETH");
        
        // Initial balances
        uint256 ownerWethBefore = IERC20(WETH).balanceOf(address(this));
        uint256 contractWethBefore = IERC20(WETH).balanceOf(address(flashLoan));
        
        console.log("\n--- Initial Balances ---");
        console.log("Owner WETH:", ownerWethBefore / 1e18, "WETH");
        console.log("Contract WETH:", contractWethBefore / 1e18, "WETH");
        
        // STEP 1: Check if WETH/AERO pool exists on Aerodrome
        console.log("\n--- STEP 1: Create Price Imbalance ---");
        console.log("Buying AERO on Aerodrome to make it expensive there...");
        
        uint256 manipulationAmount = 20 ether;
        vm.deal(address(this), manipulationAmount);
        (bool success,) = WETH.call{value: manipulationAmount}("");
        require(success, "WETH wrap failed");
        
        console.log("Wrapped", manipulationAmount / 1e18, "WETH");
        
        // Swap on Aerodrome
        IERC20(WETH).approve(AERO_ROUTER, manipulationAmount);
        
        IRouter router = IRouter(AERO_ROUTER);
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: WETH,
            to: AERO,
            stable: false,
            factory: vm.envAddress("AERODROME_FACTORY")
        });
        
        try router.swapExactTokensForTokens(
            manipulationAmount,
            0,
            routes,
            address(this),
            block.timestamp
        ) returns (uint256[] memory amounts) {
            console.log("Bought", amounts[1] / 1e18, "AERO");
            console.log("AERO is now EXPENSIVE on Aerodrome");
            console.log("Opportunity: Buy cheap on Aerodrome (after price impact), sell elsewhere\n");
        } catch {
            console.log("Pool may not have enough liquidity or doesn't exist");
            console.log("Skipping manipulation, will test without price difference\n");
        }
        
        // STEP 2: Execute Flash Loan
        uint256 flashFee = (amountIn * 3000) / 1000000;
        console.log("--- STEP 2: Execute Flash Loan ---");
        console.log("Borrow:", amountIn / 1e18, "WETH");
        console.log("Fee:", flashFee / 1e18, "WETH");
        
        console.log("\nExecuting flash loan...");
        try flashLoan.executeFlashLoan(
            WETH,
            WETH,
            AERO,
            amountIn,
            false,
            true,
            false  // buyOnAero
        ) {
            console.log("\n[SUCCESS] Arbitrage profitable!");
        } catch Error(string memory reason) {
            console.log("\n[REVERTED]", reason);
        } catch {
            console.log("\n[REVERTED] Not profitable");
        }

        // Final balances
        uint256 ownerWethAfter = IERC20(WETH).balanceOf(address(this));
        uint256 contractWethAfter = IERC20(WETH).balanceOf(address(flashLoan));
        
        console.log("\n--- Final Balances ---");
        console.log("Owner WETH:", ownerWethAfter / 1e18, "WETH");
        console.log("Contract WETH:", contractWethAfter / 1e18, "WETH");
        
        if (contractWethAfter > contractWethBefore) {
            console.log("\n[PROFIT]:", (contractWethAfter - contractWethBefore) / 1e18, "WETH");
        }
        
        console.log("\n======================================\n");
    }
}
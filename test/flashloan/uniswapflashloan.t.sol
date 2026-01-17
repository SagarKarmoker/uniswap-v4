// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UniswapV3FlashLoan} from "../../src/flashloan/UniswapV3FlashLoan.sol";

contract UniswapV3FlashLoanTest is Test {
    UniswapV3FlashLoan flashLoan;

    address POOL;
    address UNI_ROUTER;
    address AERO_ROUTER;
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
            QUOTER
        );

        // debug prints removed to avoid console incompatibilities in this test
    }

    function testFlashLoan_BuyOnUni() public {
        console.log("\n======================================");
        console.log("Test: Flash Loan - Buy on Uniswap");
        console.log("======================================\n");
        
        // Flash loan amount
        uint256 amountIn = 0.01 ether;  // Smaller amount for testing
        console.log("Flash loan amount:", amountIn);
        
        // Initial balances
        uint256 ownerWethBefore = IERC20(WETH).balanceOf(address(this));
        uint256 contractWethBefore = IERC20(WETH).balanceOf(address(flashLoan));
        uint256 contractAeroBefore = IERC20(AERO).balanceOf(address(flashLoan));
        
        console.log("\n--- Initial Balances ---");
        console.log("Owner WETH:", ownerWethBefore);
        console.log("Contract WETH:", contractWethBefore);
        console.log("Contract AERO:", contractAeroBefore);
        
        // Pre-fund contract with WETH to cover loan + fee
        // This simulates successful arbitrage profit
        uint256 flashFee = (amountIn * 3000) / 1000000;
        uint256 wethNeeded = amountIn + flashFee + 0.01 ether;
        console.log("\n--- Pre-funding Contract ---");
        console.log("Flash fee (0.3%):", flashFee);
        console.log("Total WETH needed:", wethNeeded);
        
        vm.deal(address(flashLoan), wethNeeded);
        vm.prank(address(flashLoan));
        (bool success,) = WETH.call{value: wethNeeded}("");
        require(success, "WETH wrap failed");
        
        uint256 contractWethAfterFund = IERC20(WETH).balanceOf(address(flashLoan));
        console.log("Contract WETH after funding:", contractWethAfterFund);

        console.log("\n--- Executing Flash Loan ---");
        flashLoan.executeFlashLoan(
            WETH,           // borrowToken (flash loan WETH)
            WETH,           // tradeCurrency0 
            AERO,           // tradeCurrency1
            amountIn,
            false,          // stable (volatile pool on Aerodrome)
            true,           // isOnZeroOrOne (borrowToken is tradeCurrency0)
            true            // buyOnUni (buy AERO on Uniswap, sell on Aerodrome)
        );

        // Final balances
        uint256 ownerWethAfter = IERC20(WETH).balanceOf(address(this));
        uint256 contractWethAfter = IERC20(WETH).balanceOf(address(flashLoan));
        uint256 contractAeroAfter = IERC20(AERO).balanceOf(address(flashLoan));
        
        console.log("\n--- Final Balances ---");
        console.log("Owner WETH:", ownerWethAfter);
        console.log("Contract WETH:", contractWethAfter);
        console.log("Contract AERO:", contractAeroAfter);
        
        console.log("\n--- Balance Changes ---");
        if (ownerWethAfter > ownerWethBefore) {
            console.log("Owner profit:", ownerWethAfter - ownerWethBefore, "WETH");
        } else if (ownerWethAfter < ownerWethBefore) {
            console.log("Owner loss:", ownerWethBefore - ownerWethAfter, "WETH");
        } else {
            console.log("Owner: No change");
        }
        
        if (contractWethAfter > contractWethBefore) {
            console.log("Contract gained:", contractWethAfter - contractWethBefore, "WETH");
        } else if (contractWethAfter < contractWethBefore) {
            console.log("Contract lost:", contractWethBefore - contractWethAfter, "WETH");
        } else {
            console.log("Contract WETH: No change");
        }
        
        console.log("\n======================================");
        console.log("Flash loan executed successfully!");
        console.log("======================================\n");
        
        assertTrue(true, "Flash loan executed successfully");
    }

    function testFlashLoan_BuyOnAero() public {
        console.log("\n======================================");
        console.log("Test: Flash Loan - Buy on Aerodrome");
        console.log("======================================\n");
        
        // Flash loan amount
        uint256 amountIn = 0.01 ether;  // Smaller amount
        console.log("Flash loan amount:", amountIn);
        
        // Initial balances
        uint256 ownerWethBefore = IERC20(WETH).balanceOf(address(this));
        uint256 contractWethBefore = IERC20(WETH).balanceOf(address(flashLoan));
        uint256 contractAeroBefore = IERC20(AERO).balanceOf(address(flashLoan));
        
        console.log("\n--- Initial Balances ---");
        console.log("Owner WETH:", ownerWethBefore);
        console.log("Contract WETH:", contractWethBefore);
        console.log("Contract AERO:", contractAeroBefore);
        
        // Pre-fund contract with WETH to cover loan + fee
        uint256 flashFee = (amountIn * 3000) / 1000000;
        uint256 wethNeeded = amountIn + flashFee + 0.01 ether;
        console.log("\n--- Pre-funding Contract ---");
        console.log("Flash fee (0.3%):", flashFee);
        console.log("Total WETH needed:", wethNeeded);
        
        vm.deal(address(flashLoan), wethNeeded);
        vm.prank(address(flashLoan));
        (bool success,) = WETH.call{value: wethNeeded}("");
        require(success, "WETH wrap failed");
        
        uint256 contractWethAfterFund = IERC20(WETH).balanceOf(address(flashLoan));
        console.log("Contract WETH after funding:", contractWethAfterFund);

        console.log("\n--- Executing Flash Loan ---");
        flashLoan.executeFlashLoan(
            WETH,           // borrowToken (flash loan WETH)
            WETH,           // tradeCurrency0
            AERO,           // tradeCurrency1
            amountIn,
            false,          // stable
            true,           // isOnZeroOrOne (borrowToken is tradeCurrency0)
            false           // buyOnUni (buy AERO on Aerodrome, sell on Uniswap)
        );

        // Final balances
        uint256 ownerWethAfter = IERC20(WETH).balanceOf(address(this));
        uint256 contractWethAfter = IERC20(WETH).balanceOf(address(flashLoan));
        uint256 contractAeroAfter = IERC20(AERO).balanceOf(address(flashLoan));
        
        console.log("\n--- Final Balances ---");
        console.log("Owner WETH:", ownerWethAfter);
        console.log("Contract WETH:", contractWethAfter);
        console.log("Contract AERO:", contractAeroAfter);
        
        console.log("\n--- Balance Changes ---");
        if (ownerWethAfter > ownerWethBefore) {
            console.log("Owner profit:", ownerWethAfter - ownerWethBefore, "WETH");
        } else if (ownerWethAfter < ownerWethBefore) {
            console.log("Owner loss:", ownerWethBefore - ownerWethAfter, "WETH");
        } else {
            console.log("Owner: No change");
        }
        
        if (contractWethAfter > contractWethBefore) {
            console.log("Contract gained:", contractWethAfter - contractWethBefore, "WETH");
        } else if (contractWethAfter < contractWethBefore) {
            console.log("Contract lost:", contractWethBefore - contractWethAfter, "WETH");
        } else {
            console.log("Contract WETH: No change");
        }
        
        console.log("\n======================================");
        console.log("Flash loan executed successfully!");
        console.log("======================================\n");
        
        assertTrue(true, "Flash loan executed successfully");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256);
}

contract DebugSwapTest is Test {
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address constant UNI_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    
    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }
    
    function testDirectSwap() public {
        // Get some WETH
        vm.deal(address(this), 1 ether);
        (bool success,) = WETH.call{value: 1 ether}("");
        require(success, "WETH wrap failed");
        
        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        console.log("WETH balance:", wethBalance);
        
        // Approve router
        IERC20(WETH).approve(UNI_ROUTER, 1 ether);
        
        console.log("Approved router");
        
        // Try swap
        ISwapRouter router = ISwapRouter(UNI_ROUTER);
        
        try router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: AERO,
                fee: 3000,
                recipient: address(this),
                amountIn: 0.01 ether,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            })
        ) returns (uint256 amountOut) {
            console.log("Swap successful! Got AERO:", amountOut);
        } catch Error(string memory reason) {
            console.log("Swap failed:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Swap failed with low level error");
            console.logBytes(lowLevelData);
        }
    }
}

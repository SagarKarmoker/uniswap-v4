// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0; 

import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {UniswapV4Swapper} from "../../src/uniswapv4/UniV4Swap.sol";

contract UniswapV4SwapScript is Script {
    function run() external {
        // Base network Uniswap V4 addresses
        address routerAddress = 0x6fF5693b99212Da76ad316178A184AB56D299b43; // Universal Router
        address poolManagerAddress = 0x498581fF718922c3f8e6A244956aF099B2652b2b; // PoolManager
        address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Permit2

        // deployer private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deployer Address:", msg.sender);
        console.log("Deploying Uniswap V4 Swapper...");

        UniswapV4Swapper swapper = new UniswapV4Swapper(
            routerAddress,
            poolManagerAddress,
            permit2Address
        );
        // console.log("Owner of Swapper:", swapper.owner());

        console.log("Uniswap V4 Swapper deployed at:", address(swapper));
        vm.stopBroadcast();
    }
}

// source .env && forge script script/uniswap.s.sol --rpc-url $FORK_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY
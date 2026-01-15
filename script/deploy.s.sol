// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {MTK} from "../src/MTK.sol";
import {console} from "forge-std/Test.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        // Get the deployer private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // scripting start here
        MTK mtk = new MTK();

        console.log("MTK deployed at:", address(mtk));

        address owner = mtk.totalSupply() > 0 ? msg.sender : address(0);
        console.log("Deployer address:", owner);

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}

// command to run the script
// source .env
// forge script script/deploy.s.sol:DeployScript --rpc-url $BASE_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast 
// forge script script/deploy.s.sol:DeployScript --rpc-url $FORK_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast 
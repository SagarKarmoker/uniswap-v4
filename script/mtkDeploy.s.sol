// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MTK.sol";
import "../src/veMTK.sol";
import "../src/Staking.sol";

contract DeployMTK is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // deployer
        address deployer = msg.sender;
        console.log("Deployer address:", deployer);

        // 1. Deploy MTK token
        MTK mtk = new MTK();
        console.log("MTK deployed at:", address(mtk));

        // 2. Deploy veMTK token
        veMTK vemtk = new veMTK();
        console.log("veMTK deployed at:", address(vemtk));

        // 3. Deploy MTKStaking contract
        MTKStaking staking = new MTKStaking(address(mtk), address(vemtk), 500000 * 10**18);
        console.log("MTKStaking deployed at:", address(staking));

        // 4. Transfer veMTK ownership to staking contract
        // (so staking can mint/burn veMTK)
        vemtk.transferOwnership(address(staking));
        console.log("veMTK ownership transferred to staking contract");

        // 5. Stake some tokens for deployer to demonstrate rewards
        uint256 stakeAmount = 1000 * 10**18; // 1000 MTK (assuming 18 decimals)
        mtk.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);
        console.log("Staked", stakeAmount / 1e18, "MTK for deployer");

        // simulate
        // vm.warp(block.timestamp + 7 days);
        // vm.roll(block.number + 7200);
        // // check the reward balance
        // uint256 reward = staking.earned(deployer);
        // console.log("Reward balance after 7 days:", reward / 1e18, "MTK");

        // // transfer reward to staking contract
        // mtk.transfer(address(staking), reward);

        // // withdraw reward
        // staking.claimReward();
        // console.log("Claimed reward of", reward / 1e18, "MTK");

        // // after claiming check earned again
        // uint256 rewardAfter = staking.earned(deployer);
        // console.log("Reward balance after claiming:", rewardAfter / 1e18, "MTK");

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("MTK:", address(mtk));
        console.log("veMTK:", address(vemtk));
        console.log("MTKStaking:", address(staking));
    }
}

// forge script script/mtkDeploy.s.sol:DeployMTK --rpc-url $FORK_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../src/MTK.sol";
import "../src/veMTK.sol";
import "../src/Staking.sol";

contract StakingTest is Test {
    MTK public mtk;
    veMTK public vemtk;
    MTKStaking public staking;

    address public deployer = address(1);
    address public alice = address(2);
    address public bob = address(3);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant STAKE_AMOUNT = 1000 * 10**18;
    uint256 public constant LOCK_DURATION = 7 days;

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy MTK token (mints to deployer)
        mtk = new MTK();

        // Deploy veMTK token
        vemtk = new veMTK();

        // Deploy staking contract
        staking = new MTKStaking(address(mtk), address(vemtk), 500000 * 10**18);

        // Transfer veMTK ownership to staking contract
        vemtk.transferOwnership(address(staking));

        // Transfer some MTK to test users
        mtk.transfer(alice, STAKE_AMOUNT * 2);
        mtk.transfer(bob, STAKE_AMOUNT * 2);

        vm.stopPrank();
    }

    function testDeployment() public {
        assertEq(address(staking.mtk()), address(mtk));
        assertEq(address(staking.vemtk()), address(vemtk));
        assertEq(staking.LOCK_DURATION(), LOCK_DURATION);
        assertEq(mtk.balanceOf(deployer), INITIAL_SUPPLY - STAKE_AMOUNT * 4);
        assertEq(mtk.balanceOf(alice), STAKE_AMOUNT * 2);
        assertEq(mtk.balanceOf(bob), STAKE_AMOUNT * 2);
    }

    function testStake() public {
        vm.startPrank(alice);

        // Approve staking contract
        mtk.approve(address(staking), STAKE_AMOUNT);

        // Stake tokens
        staking.stake(STAKE_AMOUNT);

        // Check stake data
        (uint256 amount, uint256 unlockTime, uint256 lastClaimTime) = staking.stakes(alice);
        assertEq(amount, STAKE_AMOUNT);
        assertEq(unlockTime, block.timestamp + LOCK_DURATION);

        // Check veMTK balance
        assertEq(vemtk.balanceOf(alice), STAKE_AMOUNT);
        console.log("veMTK balance after staking:", vemtk.balanceOf(alice));

        // Check MTK balance decreased
        assertEq(mtk.balanceOf(alice), STAKE_AMOUNT);

        vm.stopPrank();
    }

    function testCannotStakeZero() public {
        vm.startPrank(alice);
        vm.expectRevert("amount = 0");
        staking.stake(0);
        vm.stopPrank();
    }

    function testCannotStakeTwice() public {
        vm.startPrank(alice);

        mtk.approve(address(staking), STAKE_AMOUNT * 2);
        staking.stake(STAKE_AMOUNT);

        vm.expectRevert("already staked");
        staking.stake(STAKE_AMOUNT);

        vm.stopPrank();
    }

    function testCannotWithdrawBeforeLock() public {
        vm.startPrank(alice);

        mtk.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);

        vm.expectRevert("still locked");
        staking.withdraw();

        vm.stopPrank();
    }

    function testWithdrawAfterLock() public {
        vm.startPrank(alice);

        mtk.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);

        // Fast forward time
        vm.warp(block.timestamp + LOCK_DURATION + 1);

        uint256 aliceBalanceBefore = mtk.balanceOf(alice);
        uint256 stakingBalanceBefore = mtk.balanceOf(address(staking));
        uint256 reward = staking.earned(alice);

        // Transfer reward tokens to staking contract to simulate reward funding
        vm.stopPrank();
        vm.prank(deployer);
        mtk.transfer(address(staking), reward * 3); // Send extra to ensure balance for principal + reward
        vm.startPrank(alice);

        staking.withdraw();

        // Check balances
        assertEq(mtk.balanceOf(alice), aliceBalanceBefore + STAKE_AMOUNT + reward);
        assertEq(mtk.balanceOf(address(staking)), stakingBalanceBefore - STAKE_AMOUNT - reward);

        // Check veMTK burned
        assertEq(vemtk.balanceOf(alice), 0);

        // Check stake cleared
        (uint256 amount, , ) = staking.stakes(alice);
        assertEq(amount, 0);

        vm.stopPrank();
    }

    function testClaimReward() public {
        vm.startPrank(alice);

        mtk.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);

        // Fast forward time
        vm.warp(block.timestamp + 1 days);

        uint256 reward = staking.earned(alice);
        console.log("Reward calculated:", reward);
        console.log("MAX_REWARDS:", staking.MAX_REWARDS());
        console.log("TOTAL_REWARD_PAID:", staking.TOTAL_REWARD_PAID());
        assertGt(reward, 0);

        uint256 aliceBalanceBefore = mtk.balanceOf(alice);
        uint256 stakingBalanceBefore = mtk.balanceOf(address(staking));
        console.log("Alice balance before:", aliceBalanceBefore);
        console.log("Staking balance before:", stakingBalanceBefore);

        // Transfer reward tokens to staking contract
        vm.stopPrank();
        vm.prank(deployer);
        mtk.transfer(address(staking), reward * 2); // Send extra to ensure balance
        vm.startPrank(alice);

        staking.claimReward();

        uint256 aliceBalanceAfter = mtk.balanceOf(alice);
        uint256 stakingBalanceAfter = mtk.balanceOf(address(staking));
        console.log("Alice balance after:", aliceBalanceAfter);
        console.log("Staking balance after:", stakingBalanceAfter);
        console.log("Expected Alice balance:", aliceBalanceBefore + reward);

        // Check balances (allow for small rounding differences)
        assertApproxEqAbs(mtk.balanceOf(alice), aliceBalanceBefore + reward, 1);
        assertApproxEqAbs(mtk.balanceOf(address(staking)), stakingBalanceBefore - reward, 1);

        // Check lastClaimTime updated
        (, , uint256 lastClaimTime) = staking.stakes(alice);
        assertEq(lastClaimTime, block.timestamp);

        vm.stopPrank();
    }

    function testClaimRewardNoStake() public {
        vm.startPrank(alice);
        vm.expectRevert("no stake");
        staking.claimReward();
        vm.stopPrank();
    }

    function testClaimRewardNoTimePassed() public {
        vm.startPrank(alice);

        mtk.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);

        vm.expectRevert("no time passed");
        staking.claimReward();

        vm.stopPrank();
    }

    function testEarned() public {
        vm.startPrank(alice);

        mtk.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);

        // Initially no rewards
        uint256 earned = staking.earned(alice);
        assertEq(earned, 0);

        // After 1 day (10% APY)
        vm.warp(block.timestamp + 1 days);
        earned = staking.earned(alice);
        // 1000 * 10% * 1/365 ≈ 0.27397 MTK
        uint256 expected = (STAKE_AMOUNT * 10 * 1 days) / (100 * 365 days);
        assertEq(earned, expected);

        // After 30 days
        vm.warp(block.timestamp + 30 days);
        earned = staking.earned(alice);
        expected = (STAKE_AMOUNT * 10 * 31 days) / (100 * 365 days); // 31 days total
        assertEq(earned, expected);

        vm.stopPrank();
    }

    function testEarnedNoStake() public {
        uint256 earned = staking.earned(alice);
        assertEq(earned, 0);
    }

    function testMultipleUsers() public {
        // Alice stakes
        vm.startPrank(alice);
        mtk.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Bob stakes
        vm.startPrank(bob);
        mtk.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Check both have veMTK
        assertEq(vemtk.balanceOf(alice), STAKE_AMOUNT);
        assertEq(vemtk.balanceOf(bob), STAKE_AMOUNT);

        // Check stakes are separate
        (uint256 aliceAmount, ,) = staking.stakes(alice);
        (uint256 bobAmount, ,) = staking.stakes(bob);
        assertEq(aliceAmount, STAKE_AMOUNT);
        assertEq(bobAmount, STAKE_AMOUNT);
    }

    function testCannotWithdrawNoStake() public {
        vm.startPrank(alice);
        vm.expectRevert("no stake");
        staking.withdraw();
        vm.stopPrank();
    }

    function testVeMTKNonTransferable() public {
        vm.startPrank(alice);

        mtk.approve(address(staking), STAKE_AMOUNT);
        staking.stake(STAKE_AMOUNT);

        // Try to transfer veMTK (should fail)
        vm.expectRevert("veMTK is non-transferable");
        vemtk.transfer(bob, STAKE_AMOUNT);

        vm.stopPrank();
    }
}

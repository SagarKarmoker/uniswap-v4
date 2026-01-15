// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./veMTK.sol";

contract MTKStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public immutable mtk;
    veMTK public immutable vemtk;

    uint256 public immutable MAX_REWARDS;
    uint256 public TOTAL_REWARD_PAID;

    uint256 public constant LOCK_DURATION = 7 days;

    struct Stake {
        uint256 amount;
        uint256 unlockTime;
        uint256 lastClaimTime;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 staked, uint256 reward);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _mtk, address _veMTK, uint256 _maxRewards) {
        mtk = IERC20(_mtk);
        vemtk = veMTK(_veMTK);
        MAX_REWARDS = _maxRewards;
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "amount = 0");
        require(stakes[msg.sender].amount == 0, "already staked");

        mtk.safeTransferFrom(msg.sender, address(this), amount);

        stakes[msg.sender] = Stake({
            amount: amount,
            unlockTime: block.timestamp + LOCK_DURATION,
            lastClaimTime: block.timestamp
        });

        // mint 1:1 veMTK instantly
        vemtk.mint(msg.sender, amount);
        emit Staked(msg.sender, amount, block.timestamp + LOCK_DURATION);
    }

    function withdraw() external nonReentrant {
        Stake memory s = stakes[msg.sender];
        require(s.amount > 0, "no stake");
        require(block.timestamp >= s.unlockTime, "still locked");

        uint256 reward = earned(msg.sender);

        delete stakes[msg.sender];

        // Update total rewards paid
        TOTAL_REWARD_PAID += reward;

        // burn veMTK 1:1
        vemtk.burn(msg.sender, s.amount);

        mtk.safeTransfer(msg.sender, s.amount + reward);
        emit Withdrawn(msg.sender, s.amount, reward);
    }

    function claimReward() external nonReentrant {
        require(stakes[msg.sender].amount > 0, "no stake");
        require(
            block.timestamp > stakes[msg.sender].lastClaimTime,
            "no time passed"
        );

        uint256 reward = earned(msg.sender);
        require(reward > 0, "no reward");

        stakes[msg.sender].lastClaimTime = block.timestamp;

        // Update total rewards paid
        TOTAL_REWARD_PAID += reward;

        // For simplicity, rewards are paid in MTK from contract's balance
        mtk.safeTransfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function timeLeft(address user) external view returns (uint256) {
        if (block.timestamp >= stakes[user].unlockTime) return 0;
        return stakes[user].unlockTime - block.timestamp;
    }

    function earned(address user) public view returns (uint256) {
        // Simple reward calculation: 10% APY
        Stake memory s = stakes[user];
        if (s.amount == 0) return 0;

        // total supply cap on rewards
        uint256 totalSupply = totalVeMTK();
        if (totalSupply == 0) return 0;

        uint256 duration = block.timestamp - s.lastClaimTime;

        // Base reward: 10% APY
        uint256 baseReward = (s.amount * 10 * duration) / (100 * 365 days);

        // Adjust reward based on total veMTK supply
        uint256 userVe = vemtk.balanceOf(user);
        uint256 weightedReward = (baseReward * userVe) / totalSupply;

        // Ensure we don't exceed MAX_REWARDS
        if (TOTAL_REWARD_PAID + weightedReward > MAX_REWARDS) {
            if (TOTAL_REWARD_PAID >= MAX_REWARDS) {
                return 0;
            } else {
                weightedReward = MAX_REWARDS - TOTAL_REWARD_PAID;   
            }
        }
        return weightedReward;
    }

    // helpter function to get stake info
    function totalVeMTK() public view returns (uint256) {
        return vemtk.totalSupply();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IStaking.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPool is IStaking, ReentrancyGuard, Ownable {
    // KK Token 合约
    IToken public immutable kkToken;
    
    // 每区块产出10个代币数量 
    uint256 public constant REWARD_PER_BLOCK = 10e18; // 
    
    // 用户质押信息
    struct UserInfo {
        uint256 amount;         // 质押数量
        uint256 rewardDebt;     // 已结算的奖励债务
        uint256 lastStakeBlock; // 最后质押区块
    }
    
    // 总质押量
    uint256 public totalStaked;
    
    // 每份额累积奖励
    uint256 public accRewardPerShare;
    
    // 上次更新区块
    uint256 public lastRewardBlock;
    
    // 用户信息映射
    mapping(address => UserInfo) public userInfo;
    
    constructor(address _kkToken) Ownable(msg.sender) {
        kkToken = IToken(_kkToken);
        lastRewardBlock = block.number;
    }
    
    // 更新奖励池状态
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        uint256 blocksSinceLastReward = block.number - lastRewardBlock;
        uint256 rewards = blocksSinceLastReward * REWARD_PER_BLOCK;
        
        accRewardPerShare += (rewards * 1e18) / totalStaked;
        lastRewardBlock = block.number;
    }
    
    // 质押 ETH
    function stake() external payable override nonReentrant {
        require(msg.value > 0, "Cannot stake 0");
        
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        
        // 如果用户已经有质押，先结算之前的奖励
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
            if (pending > 0) {
                kkToken.mint(msg.sender, pending);
            }
        }
        
        user.amount += msg.value;
        totalStaked += msg.value;
        user.lastStakeBlock = block.number;
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;
        
        emit Staked(msg.sender, msg.value);
    }
    
    // 赎回质押的 ETH
    function unstake(uint256 amount) external override nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "Insufficient balance");
        
        updatePool();
        
        // 计算待领取的奖励
        uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
        if (pending > 0) {
            kkToken.mint(msg.sender, pending);
        }
        
        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;
        
        // 转账 ETH 给用户
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }
    
    // 领取奖励
    function claim() external override nonReentrant {
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.amount * accRewardPerShare / 1e18) - user.rewardDebt;
        
        require(pending > 0, "No rewards to claim");
        
        user.rewardDebt = user.amount * accRewardPerShare / 1e18;
        kkToken.mint(msg.sender, pending);
        
        emit RewardClaimed(msg.sender, pending);
    }
    
    // 查询质押余额
    function balanceOf(address account) external view override returns (uint256) {
        return userInfo[account].amount;
    }
    
    // 查询待领取奖励
    function earned(address account) external view override returns (uint256) {
        UserInfo storage user = userInfo[account];
        uint256 currentAccRewardPerShare = accRewardPerShare;
        
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocksSinceLastReward = block.number - lastRewardBlock;
            uint256 rewards = blocksSinceLastReward * REWARD_PER_BLOCK;
            currentAccRewardPerShare += (rewards * 1e18) / totalStaked;
        }
        
        return (user.amount * currentAccRewardPerShare / 1e18) - user.rewardDebt;
    }
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
} 
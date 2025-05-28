// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ETH质押池合约
 * @dev 允许用户质押ETH获取KK代币奖励
 * 每个区块产出10个KK代币，根据质押时长和数量公平分配
 */
contract ETHStakingPool is IStaking {
    // 使用SafeERC20库来安全地处理ERC20代币转账
    using SafeERC20 for IERC20;

    // KK代币合约地址，设置为不可变以节省gas
    IToken public immutable kkToken;
    
    // 每个区块产生的KK代币数量，设置为常量
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18; // 10个KK代币
    
    // 首次质押的区块高度，用于计算奖励
    uint256 public stakingStartBlock;
    
    // 合约中质押的所有ETH数量
    uint256 public totalStaked;
    
    // 每个份额能够拿到的KK代币数量，使用1e12作为精度
    uint256 public accKKPerShare;
    
    // 上次更新奖励的区块，用于计算新的奖励
    uint256 public lastRewardBlock;

    /**
     * @dev 用户信息结构体
     * amount: 用户质押的ETH数量
     * rewardDebt: 奖励债务，用于计算用户应得的奖励
     */
    struct UserInfo {
        uint256 amount;         // 用户质押的ETH数量
        uint256 rewardDebt;     // 奖励债务
    }

    // 用户地址到用户信息的映射
    mapping(address => UserInfo) public userInfo;

    // 事件定义
    event Staked(address indexed user, uint256 amount);      // 质押事件
    event Unstaked(address indexed user, uint256 amount);    // 解除质押事件
    event RewardPaid(address indexed user, uint256 reward);  // 奖励发放事件

    /**
     * @dev 构造函数
     * @param _kkToken KK代币合约地址
     */
    constructor(IToken _kkToken) {
        // 初始化KK代币合约地址
        kkToken = _kkToken;
    }

    /**
     * @dev 更新奖励池状态
     * 计算从上次更新到当前区块的奖励，并更新每份奖励数量
     */
    function updatePool() public {
        // 如果当前区块小于等于上次更新区块，直接返回
        if (block.number <= lastRewardBlock) {
            return;
        }

        // 如果总质押量为0，只更新最后奖励区块
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        // 计算经过的区块数
        uint256 multiplier = block.number - lastRewardBlock;
        // 计算这段时间内产生的总奖励
        uint256 reward = multiplier * REWARD_PER_BLOCK;
        // 更新每份奖励数量，使用1e12作为精度
        accKKPerShare = accKKPerShare + (reward * 1e12 / totalStaked);
        // 更新最后奖励区块
        lastRewardBlock = block.number;
    }

    /**
     * @dev 质押ETH到合约
     * 用户可以质押任意数量的ETH，质押时会自动计算并发放之前的奖励
     */
    function stake() external payable override {
        // 确保质押数量大于0
        require(msg.value > 0, "Cannot stake 0 ETH");
        
        // 更新奖励池状态
        updatePool();
        
        // 获取用户信息
        UserInfo storage user = userInfo[msg.sender];
        
        // 如果用户已有质押，计算并发放之前的奖励
        if (user.amount > 0) {
            // 计算待发放的奖励
            uint256 pending = user.amount * accKKPerShare / 1e12 - user.rewardDebt;
            if (pending > 0) {
                // 安全地转账KK代币给用户
                safeKKTransfer(msg.sender, pending);
                // 触发奖励发放事件
                emit RewardPaid(msg.sender, pending);
            }
        }

        // 更新用户的质押数量
        user.amount += msg.value;
        // 更新用户的奖励债务
        user.rewardDebt = user.amount * accKKPerShare / 1e12;

        // 更新总质押量
        totalStaked += msg.value;

        // 触发质押事件
        emit Staked(msg.sender, msg.value);
    }

    /**
     * @dev 赎回质押的ETH
     * @param amount 赎回数量
     * 用户可以赎回部分或全部质押的ETH，同时会计算并发放奖励
     */
    function unstake(uint256 amount) external override {
        // 获取用户信息
        UserInfo storage user = userInfo[msg.sender];
        // 确保用户有足够的质押数量
        require(user.amount >= amount, "Insufficient staked amount");

        // 更新奖励池状态
        updatePool();

        // 计算并发放奖励
        uint256 pending = user.amount * accKKPerShare / 1e12 - user.rewardDebt;
        if (pending > 0) {
            // 安全地转账KK代币给用户
            safeKKTransfer(msg.sender, pending);
            // 触发奖励发放事件
            emit RewardPaid(msg.sender, pending);
        }

        // 更新用户的质押数量
        user.amount -= amount;
        // 更新用户的奖励债务
        user.rewardDebt = user.amount * accKKPerShare / 1e12;

        // 更新总质押量
        totalStaked -= amount;

        // 将ETH转回给用户
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");

        // 触发解除质押事件
        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev 领取KK代币收益
     * 用户可以随时领取已累积的奖励
     */
    function claim() external override {
        // 更新奖励池状态
        updatePool();
        
        // 获取用户信息
        UserInfo storage user = userInfo[msg.sender];
        // 确保用户有质押
        require(user.amount > 0, "No staked amount");

        // 计算待发放的奖励
        uint256 pending = user.amount * accKKPerShare / 1e12 - user.rewardDebt;
        if (pending > 0) {
            // 安全地转账KK代币给用户
            safeKKTransfer(msg.sender, pending);
            // 更新用户的奖励债务
            user.rewardDebt = user.amount * accKKPerShare / 1e12;
            // 触发奖励发放事件
            emit RewardPaid(msg.sender, pending);
        }
    }

    /**
     * @dev 获取质押的ETH数量
     * @param account 质押账户
     * @return 质押的ETH数量
     */
    function balanceOf(address account) external view override returns (uint256) {
        return userInfo[account].amount;
    }

    /**
     * @dev 获取待领取的KK代币收益
     * @param account 质押账户
     * @return 待领取的KK代币收益
     */
    function earned(address account) external view override returns (uint256) {
        // 获取用户信息
        UserInfo storage user = userInfo[account];
        // 获取当前每份奖励数量
        uint256 _accKKPerShare = accKKPerShare;
        
        // 如果当前区块大于上次更新区块且总质押量不为0，计算新的奖励
        if (block.number > lastRewardBlock && totalStaked != 0) {
            // 计算经过的区块数
            uint256 multiplier = block.number - lastRewardBlock;
            // 计算这段时间内产生的总奖励
            uint256 reward = multiplier * REWARD_PER_BLOCK;
            // 更新每份奖励数量
            _accKKPerShare = _accKKPerShare + (reward * 1e12 / totalStaked);
        }
        
        // 返回用户应得的奖励
        return user.amount * _accKKPerShare / 1e12 - user.rewardDebt;
    }

    /**
     * @dev 安全的KK代币转账函数
     * @param _to 接收地址
     * @param _amount 转账数量
     * 如果合约中的KK代币余额不足，则转账所有可用余额
     */
    function safeKKTransfer(address _to, uint256 _amount) internal {
        // 获取合约中的KK代币余额
        uint256 kkBal = kkToken.balanceOf(address(this));
        // 如果余额不足，转账所有可用余额
        if (_amount > kkBal) {
            kkToken.transfer(_to, kkBal);
        } else {
            // 否则转账指定数量
            kkToken.transfer(_to, _amount);
        }
    }

    // 允许合约接收ETH的回退函数
    receive() external payable {}
} 
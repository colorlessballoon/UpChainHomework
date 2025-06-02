pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleLeverageDEX
 * @dev 一个基于vAMM的简单杠杆去中心化交易所实现
 * 允许用户使用杠杆进行多空交易，包含清算机制
 */
contract SimpleLeverageDEX {
    // vAMM 相关参数
    uint public vK;          // 恒定乘积公式中的K值 (vETHAmount * vUSDCAmount)
    uint public vETHAmount;  // 虚拟ETH池中的数量（模拟流动性池中的ETH）
    uint public vUSDCAmount; // 虚拟USDC池中的数量（模拟流动性池中的USDC）

    // USDC代币合约接口
    IERC20 public USDC;

    /**
     * @dev 用户持仓信息结构体
     * @param margin   用户存入的保证金（实际USDC数量）
     * @param borrowed 用户借入的资金量（USDC）
     * @param position 虚拟ETH持仓量（正数表示多头，负数表示空头）
     * @param entryPrice 开仓时的价格（USDC/ETH，精度1e18）
     */
    struct PositionInfo {
        uint256 margin;
        uint256 borrowed;
        int256 position;
        uint256 entryPrice;
    }
    
    // 用户地址到持仓信息的映射
    mapping(address => PositionInfo) public positions;

    /**
     * @dev 构造函数，初始化vAMM池
     * @param vEth 初始虚拟ETH数量
     * @param vUSDC 初始虚拟USDC数量
     * @param usdcAddress USDC代币合约地址
     */
    constructor(uint vEth, uint vUSDC, address usdcAddress) {
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC; // 计算初始恒定乘积
        USDC = IERC20(usdcAddress);
    }

    /**
     * @dev 开立杠杆头寸
     * @param _margin 保证金数量（USDC）
     * @param level 杠杆倍数（例如5表示5倍杠杆）
     * @param long 是否做多（true=做多，false=做空）
     */
    function openPosition(uint256 _margin, uint level, bool long) external {
        // 检查用户没有未平仓头寸
        require(positions[msg.sender].position == 0, "Position already open");
        // 杠杆倍数必须为正
        require(level > 0, "Leverage level must be positive");

        PositionInfo storage pos = positions[msg.sender];
        
        // 从用户转账保证金到合约
        USDC.transferFrom(msg.sender, address(this), _margin);
        
        // 计算总交易金额（保证金*杠杆）
        uint amount = _margin * level;
        // 计算借入金额（总金额-保证金）
        uint256 borrowAmount = amount - _margin;

        // 记录持仓信息
        pos.margin = _margin;
        pos.borrowed = borrowAmount;
        pos.entryPrice = getPrice(); // 记录开仓价格

        if (long) {
            // 做多逻辑：用USDC买入vETH
            // 根据恒定乘积公式计算能获得的vETH数量
            uint vETHOut = (vETHAmount * amount) / (vUSDCAmount + amount);
            // 更新vAMM池状态
            vUSDCAmount += amount;    // USDC池增加
            vETHAmount -= vETHOut;    // ETH池减少
            pos.position = int256(vETHOut); // 记录多头持仓（正数）
        } else {
            // 做空逻辑：借vETH卖出获得USDC
            // 根据恒定乘积公式计算能获得的vUSDC数量
            uint vUSDCOut = (vUSDCAmount * amount) / (vETHAmount + amount);
            // 更新vAMM池状态
            vETHAmount += amount;     // ETH池增加（相当于借入ETH）
            vUSDCAmount -= vUSDCOut;  // USDC池减少
            pos.position = -int256(amount); // 记录空头持仓（负数，数值为借入的ETH量）
        }
    }

    /**
     * @dev 平仓并结算头寸
     * 计算盈亏后返还用户资金，并更新vAMM池状态
     */
    function closePosition() external {
        PositionInfo storage pos = positions[msg.sender];
        // 检查用户有未平仓头寸
        require(pos.position != 0, "No open position");

        // 计算当前盈亏
        int256 pnl = calculatePnL(msg.sender);
        uint256 totalValue;
        
        // 处理盈利/亏损情况
        if (pnl >= 0) {
            // 盈利：保证金+盈利部分
            totalValue = pos.margin + uint256(pnl);
        } else {
            // 亏损：保证金-亏损部分（最多亏完保证金）
            totalValue = pos.margin > uint256(-pnl) ? pos.margin - uint256(-pnl) : 0;
        }

        // 返还用户资金
        USDC.transfer(msg.sender, totalValue);
        
        // 根据持仓方向进行平仓操作
        if (pos.position > 0) {
            // 多头平仓：卖出vETH换回vUSDC
            uint amount = uint256(pos.position);
            uint vUSDCBack = (vUSDCAmount * amount) / (vETHAmount + amount);
            // 更新vAMM池
            vETHAmount += amount;    // ETH池增加（用户卖出）
            vUSDCAmount -= vUSDCBack; // USDC池减少
        } else {
            // 空头平仓：买回vETH偿还借入
            uint amount = uint256(-pos.position);
            uint vETHBack = (vETHAmount * amount) / (vUSDCAmount + amount);
            // 更新vAMM池
            vUSDCAmount += amount;  // USDC池增加（用户支付）
            vETHAmount -= vETHBack;  // ETH池减少
        }

        // 删除用户持仓记录
        delete positions[msg.sender];
    }

    /**
     * @dev 清算其他用户的头寸
     * @param _user 被清算的用户地址
     * 条件：亏损超过保证金的80%
     * 清算人可获得部分奖励
     */
    function liquidatePosition(address _user) external {
        // 不能清算自己
        require(_user != msg.sender, "Cannot liquidate yourself");
        PositionInfo memory position = positions[_user];
        // 检查被清算用户有未平仓头寸
        require(position.position != 0, "No open position");
        
        // 计算被清算用户的盈亏
        int256 pnl = calculatePnL(_user);
        // 检查清算条件：亏损且亏损超过保证金的80%
        require(pnl < 0 && uint256(-pnl) > position.margin * 8 / 10, "Position not liquidatable");

        // 清算人获得保证金10%作为奖励
        uint256 reward = position.margin / 10;
        USDC.transfer(msg.sender, reward);
        
        // 注意：剩余保证金保留在合约中（视为协议收入）
        // 借入的资金已经在vAMM中处理，无需额外操作
        
        // 删除被清算用户的持仓记录
        delete positions[_user];
    }

    /**
     * @dev 计算用户当前盈亏
     * @param user 用户地址
     * @return 盈亏金额（正数表示盈利，负数表示亏损）
     */
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory pos = positions[user];
        // 无持仓则盈亏为0
        if (pos.position == 0) return 0;
        
        // 获取当前价格
        uint256 currentPrice = getPrice();
        
        if (pos.position > 0) {
            // 多头盈亏计算：(当前价格 - 入场价格) * 持仓量
            uint256 positionValue = uint256(pos.position) * currentPrice / 1e18;
            uint256 entryValue = uint256(pos.position) * pos.entryPrice / 1e18;
            return int256(positionValue) - int256(entryValue);
        } else {
            // 空头盈亏计算：(入场价格 - 当前价格) * 持仓量
            uint256 positionSize = uint256(-pos.position);
            uint256 entryValue = positionSize * pos.entryPrice / 1e18;
            uint256 currentValue = positionSize * currentPrice / 1e18;
            return int256(entryValue) - int256(currentValue);
        }
    }

    /**
     * @dev 获取当前vAMM中的价格（USDC/ETH）
     * @return 价格（1 ETH = x USDC，精度1e18）
     */
    function getPrice() public view returns (uint256) {
        // 价格 = USDC池总量 / ETH池总量，乘以1e18保持精度
        return (vUSDCAmount * 1e18) / vETHAmount;
    }
}
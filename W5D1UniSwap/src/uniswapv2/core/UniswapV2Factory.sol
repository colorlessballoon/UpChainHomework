// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

/**
 * @title UniswapV2Factory
 * @dev Uniswap V2 工厂合约，负责创建和管理交易对
 * 主要功能：
 * 1. 创建新的交易对
 * 2. 设置协议费用接收地址
 * 3. 查询已存在的交易对
 */
contract UniswapV2Factory is IUniswapV2Factory {
    // 协议费用接收地址
    address public feeTo;
    // 协议费用设置权限地址
    address public feeToSetter;

    // 交易对映射，key为代币地址对，value为交易对合约地址
    mapping(address => mapping(address => address)) public getPair;
    // 所有已创建的交易对列表
    address[] public allPairs;

    /**
     * @dev 创建交易对事件
     * @param token0 代币0地址
     * @param token1 代币1地址
     * @param pair 交易对合约地址
     * @param pairCount 当前交易对总数
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    /**
     * @dev 构造函数
     * @param _feeToSetter 初始费用设置权限地址
     */
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @dev 获取所有已创建的交易对数量
     * @return 交易对总数
     */
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /**
     * @dev 创建新的交易对
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return pair 新创建的交易对合约地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // 确保代币地址不同
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        // 对代币地址进行排序，确保token0 < token1
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // 确保代币地址不为零地址
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        // 确保交易对不存在
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');

        // 创建新的交易对合约
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // 初始化交易对
        IUniswapV2Pair(pair).initialize(token0, token1);

        // 更新状态
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // 填充反向映射
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev 设置协议费用接收地址
     * @param _feeTo 新的费用接收地址
     */
    function setFeeTo(address _feeTo) external {
        // 只有feeToSetter可以调用
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    /**
     * @dev 设置协议费用设置权限地址
     * @param _feeToSetter 新的费用设置权限地址
     */
    function setFeeToSetter(address _feeToSetter) external {
        // 只有当前feeToSetter可以调用
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KKToken
 * @dev KK代币合约，继承自IToken接口
 * 实现了ERC20标准，并添加了铸造和销毁功能
 */
contract KKToken is IToken, ERC20, Ownable {
    // 代币精度
    uint8 private constant DECIMALS = 18;
    
    // 最大供应量：10亿个代币
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18;

    /**
     * @dev 构造函数
     * @param initialSupply 初始供应量
     */
    constructor(uint256 initialSupply) ERC20("KK Token", "KK") {
        // 确保初始供应量不超过最大供应量
        require(initialSupply <= MAX_SUPPLY, "Initial supply exceeds max supply");
        // 铸造初始供应量给部署者
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev 铸造新代币，仅限所有者调用
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external override onlyOwner {
        // 确保铸造后总供应量不超过最大供应量
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        // 铸造新代币
        _mint(to, amount);
    }

    /**
     * @dev 销毁代币
     * @param amount 销毁数量
     */
    function burn(uint256 amount) external {
        // 销毁调用者的代币
        _burn(msg.sender, amount);
    }

    /**
     * @dev 获取代币精度
     * @return 代币精度
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @dev 获取最大供应量
     * @return 最大供应量
     */
    function maxSupply() public pure returns (uint256) {
        return MAX_SUPPLY;
    }
} 
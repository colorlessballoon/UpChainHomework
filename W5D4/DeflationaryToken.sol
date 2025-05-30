// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeflationaryToken is ERC20 {
    uint256 private _totalShares;   // 总份额（动态变化）
    uint256 private _totalSupply;   // 名义总供应量（恒定）
    mapping(address => uint256) private _shares; // 用户份额

    uint256 public lastRebaseTime;  // 上次 rebase 时间
    uint256 public constant YEAR = 365 days;
    uint256 public constant DEFLATION_RATE = 1; // 1% 通缩

    constructor(uint256 initialSupply) ERC20("Deflationary Token", "DFT") {
        _totalSupply = initialSupply;
        _totalShares = initialSupply;
        _shares[msg.sender] = initialSupply;
        lastRebaseTime = block.timestamp;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    // 返回通缩后的余额（自动计算）
    function balanceOf(address account) public view override returns (uint256) {
        if (_totalShares == 0) return 0;
        return (_shares[account] * _totalSupply) / _totalShares;
    }

    // 每年自动通缩 1%
    function rebase() public {
        require(block.timestamp >= lastRebaseTime + YEAR, "Not yet");

        // 计算新供应量（减少 1%）
        uint256 newSupply = (_totalSupply * (100 - DEFLATION_RATE)) / 100;
        
        // 更新总份额（保持 _shares 不变，仅调整 _totalShares）
        _totalShares = (_totalShares * newSupply) / _totalSupply;
        _totalSupply = newSupply;

        lastRebaseTime = block.timestamp;
    }

    // 转账时处理份额
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        uint256 senderBalance = balanceOf(sender);
        require(senderBalance >= amount, "Insufficient balance");

        // 计算份额对应的数量
        uint256 senderShares = (_shares[sender] * amount) / senderBalance;
        _shares[sender] -= senderShares;
        _shares[recipient] += senderShares;

        emit Transfer(sender, recipient, amount);
    }

    // 返回通缩后的总供应量
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
}
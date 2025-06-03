// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Bank is Ownable(msg.sender) {
    uint256 public totalDeposits;
    
    // 接收ETH存款
    receive() external payable {
        totalDeposits += msg.value;
    }
    
    // 仅管理员可提取资金
    function withdraw(uint256 amount, address payable recipient) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        totalDeposits -= amount;
        recipient.transfer(amount);
    }
    
    // 获取合约余额
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // 添加所有权转移方法
    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        _transferOwnership(newOwner);
    }
}
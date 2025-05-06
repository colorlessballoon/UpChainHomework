// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol"; 

contract TokenBank{

    BaseERC20 public token; 
    address public owner;
    uint256 public totalDeposits;
    mapping(address => uint256) public balances;

    constructor(address tokenAddress) {
        token = BaseERC20(tokenAddress); 
        owner = msg.sender;
    }


    function deposit(uint256 amount) public {
        require(amount > 0, "Deposit amount must be greater than 0"); 
        token.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount; 
        totalDeposits += amount;
    }

    function withdraw() public {
        require(msg.sender == owner, "Only owner can withdraw");
        token.transfer(owner, totalDeposits); 
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./IBank.sol";

contract Admin{
    address public owner;
    constructor() {
        owner = msg.sender;
    }
    function adminWithDraw(IBank bank) public{
        require(msg.sender == owner, "Only the owner can withdraw");
        require(address(bank).balance >= 0, "Bank contract has insufficient balance");
        bank.withDraw();
    }
    receive() external payable {
        // This contract can receive ether
    }   
}
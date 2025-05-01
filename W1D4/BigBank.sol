// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./Bank.sol";

contract BigBank is Bank {


    modifier depositLimit(){
        require(msg.value > 0.001 ether, "Minimum deposit is 0.001 ether");
        _;
    }

    function adminTransfer(address newAdmin) public {
        require(msg.sender == owner, "Only the owner can transfer admin");
        owner = newAdmin;
    }


    function deposit() public payable depositLimit override {
        super.deposit();
    }

    function withDraw() public override {
        super.withDraw();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./Bank.sol";

contract Admin{
    address public adminOwner;
    constructor() {
        adminOwner = msg.sender;
    }
    function bigbankWithDraw(BigBank bigbank,uint256 amount) public {
        require(msg.sender == adminOwner, "Only the owner can withdraw");
        bigbank.withDraw(amount);
    }

}

contract BigBank is Bank{

    Admin public admin;
    address public adminOwner;
    constructor(address adminAddress){
        admin = Admin(adminAddress);
        owner = adminAddress;
        adminOwner = admin.adminOwner();
    }


    modifier depositLimit(){
        require(msg.value > 0.001 ether, "Minimum deposit is 0.001 ether");
        _;
    }

    

    function deposit() public payable depositLimit override {
        super.deposit();
    }

    function withDraw(uint256 amount) public override {
        require(msg.sender == owner, "Only the owner can withdraw");
        require(amount <= address(this).balance, "Insufficient balance in the contract");
        payable(adminOwner).transfer(amount);
    }
}
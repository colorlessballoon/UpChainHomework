// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./IBank.sol";

contract Bank is IBank {
    mapping(address => uint) public balances;
    address[3] public top3;
    address public owner;


    constructor() {
        owner = msg.sender;
    }

    function withDraw() public virtual{
        require(msg.sender == owner, "(Bank)Only the owner can withdraw");
        payable(owner).transfer(address(this).balance);
        
    }
    
    function deposit() public payable virtual{
        require(msg.value >= 0, "Transfer amount must be greater than 0");
        balances[msg.sender] += msg.value;
        updateTop3();
    }

    function updateTop3() public {
        for(uint i = 0; i < top3.length; i++){
            if(msg.sender == top3[i]) break;
            if (balances[msg.sender] > balances[top3[i]]) {
                for (uint j = top3.length - 1; j > i; j--) {
                    top3[j] = top3[j - 1];
                }
                top3[i] = msg.sender;
                break;
            }
        }
    }

    receive() external payable {
        deposit();
    }
}
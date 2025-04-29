// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract Counter{
    uint public counter;

    constructor(){
        counter = 0;
    }

    function add(uint256 x) public{
        counter += x;
    }

    function get() view external returns(uint256){
        return counter;
    }
    
    
}
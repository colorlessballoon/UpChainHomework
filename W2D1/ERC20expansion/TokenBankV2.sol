// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenBank.sol";

contract TokenBankV2 is TokenBank {

    
    constructor(address tokenAddress) TokenBank(tokenAddress) {
        
    }
    function tokensReceived(address tokenOwner, uint256 _amount)external returns (bool) {
        require(msg.sender == address(token), "TokenBankV2: Only token contract can call this function");
        require(_amount > 0, "TokenBankV2: Amount must be greater than 0");
        balances[tokenOwner] += _amount;
        return true;
    }
    
}
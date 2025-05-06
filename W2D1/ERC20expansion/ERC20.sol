// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract BaseERC20 {
    string public name; 
    string public symbol; 
    uint8 public decimals; 

    uint256 public totalSupply; 

    mapping (address => uint256) balances; 

    mapping (address => mapping (address => uint256)) allowances; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(){
        // write your code here
        // set name,symbol,decimals,totalSupply
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 100000000 * (10 ** uint256(decimals)); // 1 million tokens with 18 decimals
        balances[msg.sender] = totalSupply;  
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        return balances[_owner]; // return the balance of the owner
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance"); // check if the sender has enough balance
        balances[msg.sender] -= _value; 
        balances[_to] += _value; 
        emit Transfer(msg.sender, _to, _value);  
        return true;   
    }
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(balances[_from] > _value, "ERC20: transfer amount exceeds balance"); 
        require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance"); 
        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value; 
        
        emit Transfer(_from, _to, _value); 
        return true; 
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        // write your code here
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {   
        // write your code here     
        return allowances[_owner][_spender]; 
    }

    function isContract(address _addr) internal view returns (bool) {
        return _addr.code.length > 0;
    }
    function transferWithCallback(address _to, uint256 _value) public returns (bool success) {
        if(isContract(_to)) {
            bool back = transfer(_to, _value);
            require(back, "ERC20: transfer failed"); // check if the transfer was successful
            (bool success1, ) = _to.call(
                abi.encodeWithSignature("tokensReceived(address,uint256)", msg.sender, _value)
            ); // call the callback function on the contract
            require(success1, "ERC20: tokensReceived failed"); // check if the callback was successful
            return true; // return true if the transfer and callback were successful
        }
        else{
            return transfer(_to, _value);
        }
    }
}
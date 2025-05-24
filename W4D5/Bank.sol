// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {AutomationCompatibleInterface} from "@chainlink/contracts@1.4.0/src/v0.8/automation/AutomationCompatible.sol";


contract AutomatedBank is AutomationCompatibleInterface {
    
    address public immutable owner;
    uint256 public totalDeposits;
     
    event Deposited(address indexed depositor,uint256 amount);
    event Withdrawn(address indexed to,uint256 amount);
    event UpkeepPerformed(uint256 amountTransferred);

    constructor() {
        owner = msg.sender;
    }


    function deposit() external payable{
        totalDeposits += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdrawRamaining()external {
        require(msg.sender == owner, "Only owner can call");
        uint256 balance = address(this).balance;
        (bool success,) = owner.call{value: balance}("");
        require(success,"Withdrawal failed");
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        upkeepNeeded = totalDeposits >= 0.02 ether;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        require(totalDeposits >= 0.02 ether,"Minimum threshold not reached");
        uint256 amountToTranfer = totalDeposits / 2;
        (bool success,) = owner.call{value: amountToTranfer}("");
        require(success,"Transfer failed");
        totalDeposits -= amountToTranfer;
        emit Withdrawn(owner, amountToTranfer);
        emit UpkeepPerformed(amountToTranfer);
    }
}

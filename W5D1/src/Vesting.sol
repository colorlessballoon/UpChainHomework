// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vesting {
    mapping(address => uint256) public erc20released;
    address public immutable beneficiary;
    uint256 public immutable start;
    uint256 public immutable cliffDuration; // 12个月
    uint256 public immutable vestingDuration; // 24个月
    event ERC20Released(address indexed token, uint256 amount);

    constructor(address beneficiaryAddress) {
        require(beneficiaryAddress != address(0), "Beneficiary cannot be zero address");
        beneficiary = beneficiaryAddress;
        start = block.timestamp;
        cliffDuration = 12 * 30 days; // 12个月
        vestingDuration = 24 * 30 days; // 24个月
    }

    function release(address token) external {
        uint256 releasable = vestedAmount(token, block.timestamp) - erc20released[token];
        erc20released[token] += releasable;
        require(IERC20(token).transfer(beneficiary, releasable), "Token transfer failed");
        emit ERC20Released(token, releasable);
        IERC20(token).approve(beneficiary, releasable);
    }

    function vestedAmount(address token, uint256 timestamp) public view returns (uint256) {
        uint256 totalAllocation = IERC20(token).balanceOf(address(this)) + erc20released[token];
        
        if (timestamp < start + cliffDuration) {
            return 0; // cliff期间没有代币释放
        } else if (timestamp >= start + cliffDuration + vestingDuration) {
            return totalAllocation; // 完全归属
        } else {
            // 线性释放计算
            uint256 timeSinceCliff = timestamp - (start + cliffDuration);
            return (totalAllocation * timeSinceCliff) / vestingDuration;
        }
    }
}
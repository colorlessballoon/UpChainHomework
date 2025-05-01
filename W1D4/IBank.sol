// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IBank {
    function withDraw() external;
    function deposit() external payable;
    function updateTop3() external;
    function balances(address account) external view returns (uint256);
    function top3(uint256 index) external view returns (address);
    function owner() external view returns (address);
    receive() external payable;
}
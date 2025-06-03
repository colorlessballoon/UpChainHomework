// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovToken is ERC20, Ownable {
    constructor() ERC20("Governance Token", "GOV") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10**decimals()); // 初始发行100万枚
    }

    // 为其他地址铸造代币（测试用）
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
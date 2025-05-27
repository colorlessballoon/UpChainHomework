// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        // 铸造100万个代币给合约部署者
        // 使用18位小数，所以100万个代币 = 1000000 * 10^18
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
} 
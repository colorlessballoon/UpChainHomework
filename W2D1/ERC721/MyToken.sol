// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MyToken is ERC20{
    constructor()
        ERC20("MyToken", "MTK")
    {
        _mint(msg.sender, 1 * 10 ** 8 * 10 ** 10);
    }

    function transferWithCall(
        address to,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        if(to.code.length > 0) {
            (bool success, bytes memory result) = to.call(
                abi.encodeWithSignature("tokensReceived(address,uint256,bytes)", msg.sender, amount, data)
            );
            require(success && (result.length == 0 || abi.decode(result, (bool))), "Transfer failed");
            return success;
        }
        else
        {
            _transfer(msg.sender, to, amount);
            return true;
        }
    }
}
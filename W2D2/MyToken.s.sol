// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() external returns (MyToken) {
        vm.startBroadcast();
        MyToken token = new MyToken("CLToken", "CLTK");
        vm.stopBroadcast();
        return token;
    }
}
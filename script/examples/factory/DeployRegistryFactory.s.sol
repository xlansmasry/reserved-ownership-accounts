// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

import {AccountRegistryFactory} from "../../../src/examples/factory/AccountRegistryFactory.sol";

contract DeployRegistryFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new AccountRegistryFactory{
            salt: 0x1337133713371337133713371337133713371337133713371337133713371337
        }();

        vm.stopBroadcast();
    }
}

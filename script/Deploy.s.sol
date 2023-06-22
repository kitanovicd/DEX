// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Script} from "forge-std/Script.sol";
import {DEX} from "../src/DEX.sol";
import {MintableERC20} from "../test/mock/MintableERC20.sol";

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new MintableERC20("Token1", "T1");
        new MintableERC20("Token2", "T2");
        new DEX();

        vm.stopBroadcast();
    }
}

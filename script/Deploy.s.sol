// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Script} from "forge-std/Script.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";

contract Deploy is Script {
    function setUp() public {}

    function run() public {
        /*  vm.startBroadcast();

        token1 = new MintableERC20("Token1", "T1");
        token2 = new MintableERC20("Token2", "T2");

        token1.mint(0x0, 100000000000000000 ether);
        token2.mint(0x0, 100000000000000000 ether);
        token1.mint(0x0, 100000000000000000 ether);
        token2.mint(0x0, 100000000000000000 ether);

        liquidityPool = new LiquidityPool(
            token1,
            token2,
            5,
            10,
            "Liquidity Pool",
            "LP"
        );

        vm.stopBroadcast();*/
    }
}

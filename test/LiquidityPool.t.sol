// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MintableERC20} from "./Mock/MintableERC20.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {console} from "forge-std/Console.sol";

contract LiquidityPoolTest is Test {
    string public constant SYMBOL = "LP";
    string public constant NAME = "LiquidityPoolToken";

    address public alice;
    address public bob;

    MintableERC20 public token1;
    MintableERC20 public token2;
    LiquidityPool public liquidityPool;

    function setUp() public {
        alice = makeAddr("Alice");
        bob = makeAddr("Bob");

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        token1 = new MintableERC20("Token1", "T1");
        token2 = new MintableERC20("Token2", "T2");

        token1.mint(alice, 100000000000000000 ether);
        token2.mint(alice, 100000000000000000 ether);
        token1.mint(bob, 100000000000000000 ether);
        token2.mint(bob, 100000000000000000 ether);

        liquidityPool = new LiquidityPool(token1, token2, NAME, SYMBOL);
    }

    function testSetup() public {
        assertEq(liquidityPool.name(), NAME);
        assertEq(liquidityPool.symbol(), SYMBOL);
        assertEq(liquidityPool.totalSupply(), 0);
        assertEq(address(liquidityPool.token1()), address(token1));
        assertEq(address(liquidityPool.token2()), address(token2));
    }

    function testAddLiquidityFirstTime(
        uint256 amount1,
        uint256 amount2
    ) public {
        amount1 = bound(amount1, 0, 100 ether);
        amount2 = bound(amount1, 0, 100 ether);

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);

        uint256 aliceToken1BalanceBefore = token1.balanceOf(alice);
        uint256 aliceToken2BalanceBefore = token2.balanceOf(alice);

        liquidityPool.addLiquidity(amount1, amount2, 0);

        uint256 aliceToken1BalanceAfter = token1.balanceOf(alice);
        uint256 aliceToken2BalanceAfter = token2.balanceOf(alice);
        uint256 toMint = Math.sqrt(amount1 * amount2);

        assertEq(liquidityPool.totalSupply(), toMint);
        assertEq(liquidityPool.balanceOf(alice), toMint);
        assertEq(token1.balanceOf(address(liquidityPool)), amount1);
        assertEq(token2.balanceOf(address(liquidityPool)), amount2);
        assertEq(aliceToken1BalanceAfter, aliceToken1BalanceBefore - amount1);
        assertEq(aliceToken2BalanceAfter, aliceToken2BalanceBefore - amount2);
    }

    function testAddLiquidityNonFirstTime(
        uint256 amount1Alice,
        uint256 amount2Alice,
        uint256 amount1Bob,
        uint256 amount2Bob
    ) public {
        amount1Alice = bound(amount1Alice, 1 ether, 10 ether);
        amount2Alice = bound(amount2Alice, 1 ether, 10 ether);
        amount1Bob = bound(amount1Bob, 1 ether, 10 ether);
        amount2Bob = bound(
            amount2Bob,
            (amount1Bob * amount2Alice) / amount1Alice,
            1000 ether
        );
        vm.startPrank(alice);

        uint256 token1AliceBalanceBefore = token1.balanceOf(alice);
        uint256 token2AliceBalanceBefore = token2.balanceOf(alice);

        token1.approve(address(liquidityPool), amount1Alice);
        token2.approve(address(liquidityPool), amount2Alice);
        liquidityPool.addLiquidity(amount1Alice, amount2Alice, 0);

        uint256 token1AliceBalanceAfter = token1.balanceOf(alice);
        uint256 token2AliceBalanceAfter = token2.balanceOf(alice);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 token1BobBalanceBefore = token1.balanceOf(bob);
        uint256 token2BobBalanceBefore = token2.balanceOf(bob);

        token1.approve(address(liquidityPool), amount1Bob);
        token2.approve(address(liquidityPool), amount2Bob);
        liquidityPool.addLiquidity(amount1Bob, amount2Bob, 0);

        uint256 token1BobBalanceAfter = token1.balanceOf(bob);
        uint256 token2BobBalanceAfter = token2.balanceOf(bob);
        uint256 lpAliceBalance = liquidityPool.balanceOf(alice);
        uint256 lpBobBalance = liquidityPool.balanceOf(bob);

        uint256 aliceShouldHave = (lpBobBalance * amount1Alice) / amount1Bob;

        assertTrue(
            lpAliceBalance >= aliceShouldHave - 10 &&
                lpAliceBalance <= aliceShouldHave + 10
        );
        assertEq(
            token1.balanceOf(address(liquidityPool)),
            token1AliceBalanceBefore -
                token1AliceBalanceAfter +
                token1BobBalanceBefore -
                token1BobBalanceAfter
        );
        assertEq(
            token2.balanceOf(address(liquidityPool)),
            token2AliceBalanceBefore -
                token2AliceBalanceAfter +
                token2BobBalanceBefore -
                token2BobBalanceAfter
        );
    }

    function testAddLiquidityRevertInsufficientLiquidity(
        uint256 amount1,
        uint256 amount2
    ) public {
        amount1 = bound(amount1, 1 ether, 100 ether);
        amount2 = bound(amount2, 1 ether, 100 ether);

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);

        uint256 shouldReceive = Math.sqrt(amount1 * amount2);

        vm.expectRevert(bytes("Insufficient liquidity"));
        liquidityPool.addLiquidity(amount1, amount2, shouldReceive + 1);
    }
}

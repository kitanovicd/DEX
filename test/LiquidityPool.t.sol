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
    uint256 public constant FEE_PERCENTAGE = 5;
    uint256 public constant MAX_SWAP_PERCENTAGE = 10;

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

        liquidityPool = new LiquidityPool(
            token1,
            token2,
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );
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

    function testRemoveLiquidity(
        uint256 amount1,
        uint256 amount2,
        uint256 burnAmount
    ) public {
        amount1 = bound(amount1, 1 ether, 100 ether);
        amount2 = bound(amount2, 1 ether, 100 ether);

        vm.startPrank(alice);

        uint256 token1BalanceBefore = token1.balanceOf(alice);
        uint256 token2BalanceBefore = token2.balanceOf(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        uint256 aliceLpBalanceBefore = liquidityPool.balanceOf(alice);
        burnAmount = bound(burnAmount, 1000, aliceLpBalanceBefore);

        liquidityPool.removeLiquidity(burnAmount, 0, 0);
        vm.stopPrank();

        uint256 token1BalanceAfter = token1.balanceOf(alice);
        uint256 token2BalanceAfter = token2.balanceOf(alice);
        uint256 receivedAmountToken1 = (amount1 * burnAmount) /
            aliceLpBalanceBefore;
        uint256 receivedAmountToken2 = (amount2 * burnAmount) /
            aliceLpBalanceBefore;

        assertEq(
            token1BalanceAfter,
            token1BalanceBefore - amount1 + receivedAmountToken1
        );
        assertEq(
            token2BalanceAfter,
            token2BalanceBefore - amount2 + receivedAmountToken2
        );
        assertEq(
            liquidityPool.balanceOf(alice),
            aliceLpBalanceBefore - burnAmount
        );
        assertEq(
            liquidityPool.totalSupply(),
            aliceLpBalanceBefore - burnAmount
        );
        assertEq(
            token1.balanceOf(address(liquidityPool)),
            amount1 - receivedAmountToken1
        );
        assertEq(
            token2.balanceOf(address(liquidityPool)),
            amount2 - receivedAmountToken2
        );
    }

    function testRemoveLiquidityInsufficientAmount1(
        uint256 amount1,
        uint256 amount2,
        uint256 burnAmount
    ) public {
        amount1 = bound(amount1, 1 ether, 100 ether);
        amount2 = bound(amount2, 1 ether, 100 ether);
        burnAmount = bound(burnAmount, 1 ether, Math.sqrt(amount1 * amount2));

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        uint256 expectedToReceiveToken1 = (amount1 * burnAmount) /
            liquidityPool.balanceOf(alice);

        vm.expectRevert(bytes("Insufficient amount1"));
        liquidityPool.removeLiquidity(
            burnAmount,
            expectedToReceiveToken1 + 1,
            0
        );

        vm.stopPrank();
    }

    function testRemoveLiquidityInsufficientAmount2(
        uint256 amount1,
        uint256 amount2,
        uint256 burnAmount
    ) public {
        amount1 = bound(amount1, 1 ether, 100 ether);
        amount2 = bound(amount2, 1 ether, 100 ether);
        burnAmount = bound(burnAmount, 1 ether, Math.sqrt(amount1 * amount2));

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        uint256 expectedToReceiveToken2 = (amount2 * burnAmount) /
            liquidityPool.balanceOf(alice);

        vm.expectRevert(bytes("Insufficient amount2"));
        liquidityPool.removeLiquidity(
            burnAmount,
            0,
            expectedToReceiveToken2 + 1
        );

        vm.stopPrank();
    }

    function testSwapExactInput(
        uint256 amount1,
        uint256 amount2,
        uint256 amountToSwap
    ) public {
        amount1 = bound(amount1, 10 ether, 100 ether);
        amount2 = bound(amount2, 1 ether, 100 ether);
        amountToSwap = bound(amountToSwap, 1 ether, amount1 / 10);

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 token1BobBalanceBefore = token1.balanceOf(bob);
        uint256 token2BobBalanceBefore = token2.balanceOf(bob);
        uint256 feeAmount = (amountToSwap * FEE_PERCENTAGE) / 100;
        uint256 shouldReceiveToken2Amount = (amount2 *
            (amountToSwap - feeAmount)) / amount1;

        token1.approve(address(liquidityPool), amountToSwap);
        liquidityPool.swapExactInput(token1, token2, amountToSwap, 0);

        vm.stopPrank();

        uint256 token1BobBalanceAfter = token1.balanceOf(bob);
        uint256 token2BobBalanceAfter = token2.balanceOf(bob);

        assertEq(token1BobBalanceAfter, token1BobBalanceBefore - amountToSwap);
        assertTrue(
            token2BobBalanceAfter >=
                token2BobBalanceBefore + shouldReceiveToken2Amount - 10 &&
                token2BobBalanceAfter <=
                token2BobBalanceBefore + shouldReceiveToken2Amount + 10
        );
        assertEq(
            token1.balanceOf(address(liquidityPool)),
            amount1 + amountToSwap
        );
        assertTrue(
            token2.balanceOf(address(liquidityPool)) <=
                amount2 - shouldReceiveToken2Amount + 10 &&
                token2.balanceOf(address(liquidityPool)) >=
                amount2 - shouldReceiveToken2Amount - 10
        );
    }

    function testSwapExactInputRevertInsufficientAmountOut(
        uint256 amount1,
        uint256 amount2,
        uint256 amountToSwap
    ) public {
        amount1 = bound(amount1, 10 ether, 100 ether);
        amount2 = bound(amount2, 1 ether, 100 ether);
        amountToSwap = bound(amountToSwap, 1 ether, amount1 / 10);

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 shouldReceiveToken2Amount = (amount2 *
            ((amountToSwap * (100 - FEE_PERCENTAGE)) / 100)) / amount1;

        token1.approve(address(liquidityPool), amountToSwap);

        vm.expectRevert(bytes("Insufficient amountOut"));
        liquidityPool.swapExactInput(
            token1,
            token2,
            amountToSwap,
            shouldReceiveToken2Amount + 1
        );

        vm.stopPrank();
    }

    function testSwapExactInputRevertExceedsMaxSwapPercentage(
        uint256 amount1,
        uint256 amount2,
        uint256 amountToSwap
    ) public {
        amount1 = bound(amount1, 10 ether, 100 ether);
        amount2 = bound(amount2, 1 ether, 100 ether);

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 amountToSwap = ((amount1 * MAX_SWAP_PERCENTAGE) / 100) + 1;
        token1.approve(address(liquidityPool), amountToSwap);

        vm.expectRevert(bytes("Exceeds max swap percentage"));
        liquidityPool.swapExactInput(token1, token2, amountToSwap, 0);

        vm.stopPrank();
    }

    function testSwapExactOutput(
        uint256 amount1,
        uint256 amount2,
        uint256 amountToReceive
    ) public {
        amount1 = bound(amount1, 10 ether, 100 ether);
        amount2 = bound(amount2, 10 ether, 100 ether);
        amountToReceive = bound(amountToReceive, 1 ether, amount2 / 10);

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 token1BobBalanceBefore = token1.balanceOf(bob);
        uint256 token2BobBalanceBefore = token2.balanceOf(bob);
        uint256 maxAmountIn = (((amount1 * (amountToReceive)) / amount2) *
            (100 + FEE_PERCENTAGE)) / 100;

        token1.approve(address(liquidityPool), maxAmountIn);
        liquidityPool.swapExactOutput(
            token1,
            token2,
            maxAmountIn,
            amountToReceive
        );

        vm.stopPrank();

        uint256 token1BobBalanceAfter = token1.balanceOf(bob);
        uint256 token2BobBalanceAfter = token2.balanceOf(bob);

        assertEq(token1BobBalanceAfter, token1BobBalanceBefore - maxAmountIn);
        assertEq(
            token2BobBalanceAfter,
            token2BobBalanceBefore + amountToReceive
        );
        assertEq(
            token1.balanceOf(address(liquidityPool)),
            amount1 + maxAmountIn
        );
        assertEq(
            token2.balanceOf(address(liquidityPool)),
            amount2 - amountToReceive
        );
    }

    function testSwapExactOutputRevertInsufficientAmountIn(
        uint256 amount1,
        uint256 amount2,
        uint256 amountToReceive
    ) public {
        amount1 = bound(amount1, 10 ether, 100 ether);
        amount2 = bound(amount2, 10 ether, 100 ether);
        amountToReceive = bound(amountToReceive, 1 ether, amount2 / 10);

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 maxAmountIn = (((amount1 * (amountToReceive)) / amount2) *
            (100 + FEE_PERCENTAGE)) / 100;

        token1.approve(address(liquidityPool), maxAmountIn - 1);

        vm.expectRevert(bytes("Insufficient amountIn"));
        liquidityPool.swapExactOutput(
            token1,
            token2,
            maxAmountIn - 1,
            amountToReceive
        );

        vm.stopPrank();
    }

    function testSwapExactOutputRevertExceedsMaxSwapPercentage(
        uint256 amount1,
        uint256 amount2
    ) public {
        amount1 = bound(amount1, 10 ether, 100 ether);
        amount2 = bound(amount2, 10 ether, 100 ether);

        vm.startPrank(alice);

        token1.approve(address(liquidityPool), amount1);
        token2.approve(address(liquidityPool), amount2);
        liquidityPool.addLiquidity(amount1, amount2, 0);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 maxAmountIn = type(uint256).max;
        uint256 amountToReceive = ((amount2 * MAX_SWAP_PERCENTAGE) / 100) + 1;

        token1.approve(address(liquidityPool), maxAmountIn);

        vm.expectRevert(bytes("Exceeds max swap percentage"));
        liquidityPool.swapExactOutput(
            token1,
            token2,
            maxAmountIn,
            amountToReceive
        );

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MintableERC20} from "./mock/MintableERC20.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {DEX} from "../src/DEX.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/Console.sol";

contract DEXTest is Test {
    string public constant SYMBOL = "LP";
    string public constant NAME = "LiquidityPoolToken";
    uint256 public constant FEE_PERCENTAGE = 5;
    uint256 public constant MAX_SWAP_PERCENTAGE = 10;

    address public alice;
    address public bob;

    MintableERC20 public token1;
    MintableERC20 public token2;
    DEX public dex;

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

        dex = new DEX();
    }

    function testCreateLiquidityPool() public {
        address liquidityPoolAddress = dex.createLiquidityPool(
            address(token1),
            address(token2),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );

        assertEq(
            dex.liquidityPools(address(token1), address(token2)),
            liquidityPoolAddress
        );
        assertEq(
            dex.liquidityPools(address(token2), address(token1)),
            liquidityPoolAddress
        );

        LiquidityPool liquidityPool = LiquidityPool(liquidityPoolAddress);
        assertEq(address(liquidityPool.token1()), address(token1));
        assertEq(address(liquidityPool.token2()), address(token2));
        assertEq(liquidityPool.feePercentage(), FEE_PERCENTAGE);
        assertEq(liquidityPool.maxSwapPercentage(), MAX_SWAP_PERCENTAGE);
        assertEq(liquidityPool.name(), NAME);
        assertEq(liquidityPool.symbol(), SYMBOL);
    }

    function testCreateLiquidityPoolRevertSameTokens() public {
        vm.expectRevert(
            bytes("DEX: Cannot create liquidity pool with same tokens")
        );
        dex.createLiquidityPool(
            address(token1),
            address(token1),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );
    }

    function testCreateLiquidityPoolRevertPoolAlreadyExists() public {
        dex.createLiquidityPool(
            address(token1),
            address(token2),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );

        vm.expectRevert(bytes("DEX: Liquidity pool already exists"));
        dex.createLiquidityPool(
            address(token1),
            address(token2),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );
    }

    function testAddLiquidity(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 100, 100000 ether);
        amount2 = bound(amount2, 100, 100000 ether);

        address liquidityPoolAddress = dex.createLiquidityPool(
            address(token1),
            address(token2),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );

        vm.startPrank(alice);
        token1.approve(address(dex), amount1);
        token2.approve(address(dex), amount2);

        uint256 token1BalanceBefore = token1.balanceOf(alice);
        uint256 token2BalanceBefore = token2.balanceOf(alice);
        uint256 liquidityPoolToken1BalanceBefore = token1.balanceOf(
            liquidityPoolAddress
        );
        uint256 liquidityPoolToken2BalanceBefore = token2.balanceOf(
            liquidityPoolAddress
        );

        dex.addLiquidity(address(token1), address(token2), amount1, amount2, 0);
        vm.stopPrank();

        uint256 token1BalanceAfter = token1.balanceOf(alice);
        uint256 token2BalanceAfter = token2.balanceOf(alice);
        uint256 liquidityPoolToken1BalanceAfter = token1.balanceOf(
            liquidityPoolAddress
        );
        uint256 liquidityPoolToken2BalanceAfter = token2.balanceOf(
            liquidityPoolAddress
        );

        assertEq(token1BalanceAfter, token1BalanceBefore - amount1);
        assertEq(token2BalanceAfter, token2BalanceBefore - amount2);
        assertEq(
            liquidityPoolToken1BalanceAfter,
            liquidityPoolToken1BalanceBefore + amount1
        );
        assertEq(
            liquidityPoolToken2BalanceAfter,
            liquidityPoolToken2BalanceBefore + amount2
        );
        assertEq(
            LiquidityPool(liquidityPoolAddress).balanceOf(alice),
            Math.sqrt(amount1 * amount2)
        );
        assertTrue(IERC20(liquidityPoolAddress).totalSupply() > 0);
    }

    function testAddLiquidityReturnExtraAmount(
        uint256 amount1,
        uint256 amount2,
        uint256 extraAmount
    ) public {
        amount1 = bound(amount1, 100, 100000 ether);
        amount2 = bound(amount2, 100, 100000 ether);
        extraAmount = bound(extraAmount, 100, 100000 ether);

        address liquidityPoolAddress = dex.createLiquidityPool(
            address(token1),
            address(token2),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );

        vm.startPrank(alice);
        token1.approve(address(dex), 2 * amount1);
        token2.approve(address(dex), 2 * amount2 + extraAmount);

        dex.addLiquidity(address(token1), address(token2), amount1, amount2, 0);

        uint256 token1BalanceBefore = token1.balanceOf(alice);
        uint256 token2BalanceBefore = token2.balanceOf(alice);
        uint256 liquidityPoolToken1BalanceBefore = token1.balanceOf(
            liquidityPoolAddress
        );
        uint256 liquidityPoolToken2BalanceBefore = token2.balanceOf(
            liquidityPoolAddress
        );

        dex.addLiquidity(
            address(token1),
            address(token2),
            amount1,
            amount2 + extraAmount,
            0
        );
        vm.stopPrank();

        uint256 token1BalanceAfter = token1.balanceOf(alice);
        uint256 token2BalanceAfter = token2.balanceOf(alice);
        uint256 liquidityPoolToken1BalanceAfter = token1.balanceOf(
            liquidityPoolAddress
        );
        uint256 liquidityPoolToken2BalanceAfter = token2.balanceOf(
            liquidityPoolAddress
        );

        assertEq(token1BalanceAfter, token1BalanceBefore - amount1);
        assertEq(token2BalanceAfter, token2BalanceBefore - amount2);
        assertEq(
            liquidityPoolToken1BalanceAfter,
            liquidityPoolToken1BalanceBefore + amount1
        );
        assertEq(
            liquidityPoolToken2BalanceAfter,
            liquidityPoolToken2BalanceBefore + amount2
        );
    }

    function testAddLiquidityRevertPoolDoesNotExist() public {
        vm.expectRevert(bytes("DEX: Liquidity pool does not exist"));
        dex.addLiquidity(address(token1), address(token2), 100, 100, 0);
    }

    function testRemoveLiquidity(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 100, 100000 ether);
        amount2 = bound(amount2, 100, 100000 ether);

        address liquidityPoolAddress = dex.createLiquidityPool(
            address(token1),
            address(token2),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );

        vm.startPrank(alice);
        token1.approve(address(dex), amount1);
        token2.approve(address(dex), amount2);

        dex.addLiquidity(address(token1), address(token2), amount1, amount2, 0);
        vm.stopPrank();

        uint256 liquidityPoolToken1BalanceBefore = token1.balanceOf(
            liquidityPoolAddress
        );
        uint256 liquidityPoolToken2BalanceBefore = token2.balanceOf(
            liquidityPoolAddress
        );
        uint256 liquidityPoolBalanceBefore = IERC20(liquidityPoolAddress)
            .balanceOf(alice);

        vm.startPrank(alice);
        IERC20(liquidityPoolAddress).approve(
            address(dex),
            liquidityPoolBalanceBefore
        );
        dex.removeLiquidity(
            address(token1),
            address(token2),
            liquidityPoolBalanceBefore,
            0,
            0
        );
        vm.stopPrank();

        uint256 liquidityPoolToken1BalanceAfter = token1.balanceOf(
            liquidityPoolAddress
        );
        uint256 liquidityPoolToken2BalanceAfter = token2.balanceOf(
            liquidityPoolAddress
        );
        uint256 liquidityPoolBalanceAfter = IERC20(liquidityPoolAddress)
            .balanceOf(alice);

        assertEq(
            liquidityPoolToken1BalanceAfter,
            liquidityPoolToken1BalanceBefore - amount1
        );
        assertEq(
            liquidityPoolToken2BalanceAfter,
            liquidityPoolToken2BalanceBefore - amount2
        );
        assertEq(liquidityPoolBalanceAfter, 0);
    }

    function testRemoveLiquidityRevertPoolDoesNotExist() public {
        vm.expectRevert(bytes("DEX: Liquidity pool does not exist"));
        dex.removeLiquidity(address(token1), address(token2), 100, 0, 0);
    }

    function testSwapExactInput(uint256 amountIn, uint256 swapAmount1) public {
        amountIn = bound(amountIn, 100, 100000 ether);
        swapAmount1 = bound(
            swapAmount1,
            (100 * MAX_SWAP_PERCENTAGE) / 100,
            (amountIn * MAX_SWAP_PERCENTAGE) / 100
        );

        dex.createLiquidityPool(
            address(token1),
            address(token2),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );

        vm.startPrank(alice);
        token1.approve(address(dex), amountIn);
        token2.approve(address(dex), amountIn);

        dex.addLiquidity(
            address(token1),
            address(token2),
            amountIn,
            amountIn,
            0
        );
        vm.stopPrank();

        uint256 token1BalanceBefore = token1.balanceOf(alice);
        uint256 token2BalanceBefore = token2.balanceOf(alice);

        vm.startPrank(alice);
        token1.approve(address(dex), swapAmount1);
        dex.swapExactInput(address(token1), address(token2), swapAmount1, 0);
        vm.stopPrank();

        uint256 token1BalanceAfter = token1.balanceOf(alice);
        uint256 token2BalanceAfter = token2.balanceOf(alice);

        assertEq(token1BalanceAfter, token1BalanceBefore - swapAmount1);
        assertTrue(token2BalanceAfter > token2BalanceBefore);
    }

    function testSwapExactInputRevertPoolDoesNotExist() public {
        vm.expectRevert(bytes("DEX: Liquidity pool does not exist"));
        dex.swapExactInput(address(token1), address(token2), 100, 0);
    }

    function testSwapExactOutput(
        uint256 amountIn,
        uint256 swapAmountOut1
    ) public {
        amountIn = bound(amountIn, 100, 100000 ether);
        swapAmountOut1 = bound(
            swapAmountOut1,
            (100 * MAX_SWAP_PERCENTAGE) / 100,
            (amountIn * MAX_SWAP_PERCENTAGE) / 100
        );

        dex.createLiquidityPool(
            address(token1),
            address(token2),
            FEE_PERCENTAGE,
            MAX_SWAP_PERCENTAGE,
            NAME,
            SYMBOL
        );

        vm.startPrank(alice);
        token1.approve(address(dex), amountIn);
        token2.approve(address(dex), amountIn);

        dex.addLiquidity(
            address(token1),
            address(token2),
            amountIn,
            amountIn,
            0
        );
        vm.stopPrank();

        uint256 token1BalanceBefore = token1.balanceOf(alice);
        uint256 token2BalanceBefore = token2.balanceOf(alice);

        vm.startPrank(alice);
        token1.approve(address(dex), token1.balanceOf(alice));
        dex.swapExactOutput(
            address(token1),
            address(token2),
            token1.balanceOf(alice),
            swapAmountOut1
        );
        vm.stopPrank();

        uint256 token1BalanceAfter = token1.balanceOf(alice);
        uint256 token2BalanceAfter = token2.balanceOf(alice);

        assertTrue(token1BalanceAfter < token1BalanceBefore);
        assertEq(token2BalanceAfter, token2BalanceBefore + swapAmountOut1);
    }

    function testSwapExactOutputRevertPoolDoesNotExist() public {
        vm.expectRevert(bytes("DEX: Liquidity pool does not exist"));
        dex.swapExactOutput(address(token1), address(token2), 100, 0);
    }
}

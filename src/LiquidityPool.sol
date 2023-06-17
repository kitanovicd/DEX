// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {console} from "forge-std/console.sol";

contract LiquidityPool is ERC20 {
    using SafeERC20 for IERC20;

    uint256 public feePercentage;
    uint256 public maxSwapPercentage;

    IERC20 public token1;
    IERC20 public token2;

    event AddLiquidity(
        address sender,
        uint256 amount1,
        uint256 amount2,
        uint256 mintAmount
    );
    event RemoveLiquidity(
        address sender,
        uint256 amount1,
        uint256 amount2,
        uint256 burnAmount
    );

    constructor(
        IERC20 _token1,
        IERC20 _token2,
        uint256 _feePercentage,
        uint256 _maxSwapPercentage,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        token1 = _token1;
        token2 = _token2;
        feePercentage = _feePercentage;
        maxSwapPercentage = _maxSwapPercentage;
    }

    function addLiquidity(
        uint256 amountIn1,
        uint256 amountIn2,
        uint256 minAmountToReceive
    ) external {
        uint256 amount1;
        uint256 amount2;
        uint256 mintAmount;

        if (totalSupply() == 0) {
            amount1 = amountIn1;
            amount2 = amountIn2;
            mintAmount = Math.sqrt(amount1 * amount2);
        } else {
            uint256 token1Balance = token1.balanceOf(address(this));
            uint256 token2Balance = token2.balanceOf(address(this));

            amount1 = amountIn1;
            amount2 = (amountIn1 * token2Balance) / token1Balance;

            if (amount2 > amountIn2) {
                amount2 = amountIn2;
                amount1 = (amount2 * token1Balance) / token2Balance;
            }

            mintAmount = (amount1 * totalSupply()) / token1Balance;
        }

        require(mintAmount >= minAmountToReceive, "Insufficient liquidity");

        token1.safeTransferFrom(msg.sender, address(this), amount1);
        token2.safeTransferFrom(msg.sender, address(this), amount2);

        _mint(msg.sender, mintAmount);

        emit AddLiquidity(msg.sender, amount1, amount2, mintAmount);
    }

    function removeLiquidity(
        uint256 burnAmount,
        uint256 minAmount1,
        uint256 minAmount2
    ) external {
        uint256 token1Balance = token1.balanceOf(address(this));
        uint256 token2Balance = token2.balanceOf(address(this));

        uint256 amount1 = (burnAmount * token1Balance) / totalSupply();
        uint256 amount2 = (burnAmount * token2Balance) / totalSupply();

        require(amount1 >= minAmount1, "Insufficient amount1");
        require(amount2 >= minAmount2, "Insufficient amount2");

        _burn(msg.sender, burnAmount);

        token1.safeTransfer(msg.sender, amount1);
        token2.safeTransfer(msg.sender, amount2);

        emit RemoveLiquidity(msg.sender, amount1, amount2, burnAmount);
    }

    function swapExactInput(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amountIn,
        uint256 minAmountOut
    ) external {
        uint256 token1PoolBalance = token1.balanceOf(address(this));
        uint256 token2PoolBalance = token2.balanceOf(address(this));

        require(
            amountIn <=
                ((fromToken == token1 ? token1PoolBalance : token2PoolBalance) *
                    maxSwapPercentage) /
                    100,
            "Exceeds max swap percentage"
        );

        uint256 amountInAfterFee = (amountIn * (100 - feePercentage)) / 100;
        uint256 amountOut;

        if (fromToken == token1) {
            amountOut =
                (amountInAfterFee * token2PoolBalance) /
                token1PoolBalance;
        } else {
            amountOut =
                (amountInAfterFee * token1PoolBalance) /
                token2PoolBalance;
        }

        require(amountOut >= minAmountOut, "Insufficient amountOut");

        fromToken.safeTransferFrom(msg.sender, address(this), amountIn);
        toToken.safeTransfer(msg.sender, amountOut);
    }

    function swapExactOutput(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 maxAmountIn,
        uint256 amountOut
    ) external {
        uint256 token1PoolBalance = token1.balanceOf(address(this));
        uint256 token2PoolBalance = token2.balanceOf(address(this));

        require(
            amountOut <=
                ((toToken == token1 ? token1PoolBalance : token2PoolBalance) *
                    maxSwapPercentage) /
                    100,
            "Exceeds max swap percentage"
        );

        uint256 amountIn;

        if (fromToken == token1) {
            amountIn =
                (amountOut * token1.balanceOf(address(this))) /
                token2.balanceOf(address(this));
        } else {
            amountIn =
                (amountOut * token2.balanceOf(address(this))) /
                token1.balanceOf(address(this));
        }

        amountIn = (amountIn * (100 + feePercentage)) / 100;

        require(amountIn <= maxAmountIn, "Insufficient amountIn");

        fromToken.safeTransferFrom(msg.sender, address(this), amountIn);
        toToken.safeTransfer(msg.sender, amountOut);
    }
}

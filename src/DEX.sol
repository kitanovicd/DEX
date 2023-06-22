// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {LiquidityPool} from "./LiquidityPool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract DEX {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => address)) public liquidityPools;

    event CreateLiquidityPool(
        address token1,
        address token2,
        address liquidityPool
    );
    event AddLiquidity(
        address sender,
        address token1,
        address token2,
        uint256 amount1,
        uint256 amount2,
        uint256 mintAmount
    );
    event RemoveLiquidity(
        address sender,
        address token1,
        address token2,
        uint256 amount1,
        uint256 amount2,
        uint256 burnAmount
    );
    event Swap(
        address sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    function createLiquidityPool(
        address token1,
        address token2,
        uint256 feePercentage,
        uint256 maxSwapPercentage,
        string memory name,
        string memory symbol
    ) external returns (address liquidityPool) {
        require(
            token1 != token2,
            "DEX: Cannot create liquidity pool with same tokens"
        );
        require(
            liquidityPools[token1][token2] == address(0x0),
            "DEX: Liquidity pool already exists"
        );

        liquidityPool = address(
            new LiquidityPool(
                IERC20(token1),
                IERC20(token2),
                feePercentage,
                maxSwapPercentage,
                name,
                symbol
            )
        );

        liquidityPools[token1][token2] = liquidityPool;
        liquidityPools[token2][token1] = liquidityPool;

        IERC20(token1).approve(liquidityPool, type(uint256).max);
        IERC20(token2).approve(liquidityPool, type(uint256).max);

        emit CreateLiquidityPool(token1, token2, liquidityPool);
    }

    function addLiquidity(
        address token1,
        address token2,
        uint256 maxAmountIn1,
        uint256 maxAmountIn2,
        uint256 minAmountToReceive
    ) external {
        address liquidityPool = liquidityPools[token1][token2];
        require(
            liquidityPool != address(0x0),
            "DEX: Liquidity pool does not exist"
        );

        IERC20(token1).safeTransferFrom(
            msg.sender,
            address(this),
            maxAmountIn1
        );
        IERC20(token2).safeTransferFrom(
            msg.sender,
            address(this),
            maxAmountIn2
        );

        (uint256 amount1, uint256 amount2, uint256 mintAmount) = LiquidityPool(
            liquidityPool
        ).addLiquidity(maxAmountIn1, maxAmountIn2, minAmountToReceive);

        IERC20(token1).safeTransfer(msg.sender, maxAmountIn1 - amount1);
        IERC20(token2).safeTransfer(msg.sender, maxAmountIn2 - amount2);
        IERC20(liquidityPool).safeTransfer(msg.sender, mintAmount);

        emit AddLiquidity(
            msg.sender,
            token1,
            token2,
            amount1,
            amount2,
            mintAmount
        );
    }

    function removeLiquidity(
        address token1,
        address token2,
        uint256 burnAmount,
        uint256 minAmountToReceive1,
        uint256 minAmountToReceive2
    ) external {
        address liquidityPool = liquidityPools[token1][token2];
        require(
            liquidityPool != address(0x0),
            "DEX: Liquidity pool does not exist"
        );

        IERC20(liquidityPool).safeTransferFrom(
            msg.sender,
            address(this),
            burnAmount
        );

        (uint256 amount1, uint256 amount2) = LiquidityPool(liquidityPool)
            .removeLiquidity(
                burnAmount,
                minAmountToReceive1,
                minAmountToReceive2
            );

        IERC20(token1).safeTransfer(msg.sender, amount1);
        IERC20(token2).safeTransfer(msg.sender, amount2);

        emit RemoveLiquidity(
            msg.sender,
            token1,
            token2,
            amount1,
            amount2,
            burnAmount
        );
    }

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external {
        address liquidityPool = liquidityPools[tokenIn][tokenOut];
        require(
            liquidityPool != address(0x0),
            "DEX: Liquidity pool does not exist"
        );

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 amountOut = LiquidityPool(liquidityPool).swapExactInput(
            IERC20(tokenIn),
            IERC20(tokenOut),
            amountIn,
            minAmountOut
        );

        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function swapExactOutput(
        address tokenIn,
        address tokenOut,
        uint256 maxAmountIn,
        uint256 amountOut
    ) external {
        address liquidityPool = liquidityPools[tokenIn][tokenOut];
        require(
            liquidityPool != address(0x0),
            "DEX: Liquidity pool does not exist"
        );

        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            maxAmountIn
        );

        uint256 amountIn = LiquidityPool(liquidityPool).swapExactOutput(
            IERC20(tokenIn),
            IERC20(tokenOut),
            maxAmountIn,
            amountOut
        );

        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        IERC20(tokenIn).safeTransfer(msg.sender, maxAmountIn - amountIn);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
}

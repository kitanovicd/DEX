// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract LiquidityPool is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public token1;
    IERC20 public token2;

    constructor(
        IERC20 _token1,
        IERC20 _token2,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        token1 = _token1;
        token2 = _token2;
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

                require(amount1 <= amountIn1, "Invalid amounts");
            }

            mintAmount = (amount1 * totalSupply()) / token1Balance;
        }

        require(mintAmount >= minAmountToReceive, "Insufficient liquidity");

        token1.safeTransferFrom(msg.sender, address(this), amount1);
        token2.safeTransferFrom(msg.sender, address(this), amount2);

        _mint(msg.sender, mintAmount);
    }
}

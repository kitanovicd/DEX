# DEX (Decentralized Exchange)

This repository contains a simple implementation of a decentralized exchange (DEX) in Solidity. The DEX allows users to create liquidity pools, add liquidity, remove liquidity, and perform token swaps.
<br>

The DEX consists of two main smart contracts:
<br>
* **DEX.sol**: This contract serves as the main DEX contract and manages the creation of liquidity pools, providing and removing liquidity and token swaps.
* **LiquidityPool.sol**: This contract represents a liquidity pool within the DEX. It handles providing and removing liquidity and token swaps.

To use the DEX, follow these steps:
<br>
1. Deploy the DEX contract (DEX.sol) on the Ethereum network. Deployment should be done by running deployment script (set env variables before)
```bash
./script/deploy.sh
```

2. Call the ***createLiquidityPool*** function to create a new liquidity pool. Provide the addresses of the two tokens that will be traded in the pool, along with other parameters such as fee percentage and maximum swap percentage. This function will deploy a new ***LiquidityPool*** contract for the specified token pair.

3. Users can add liquidity to the liquidity pool by calling the ***addLiquidity*** function. Specify the token pair, the amounts of each token to be added, and the minimum amount of LP tokens to receive. This function transfers the tokens from the user to the liquidity pool and mints LP tokens representing their share of the pool.

4. Liquidity can be removed from the pool by calling the ***removeLiquidity*** function. Specify the token pair, the LP token amount to burn, and the minimum amounts of each token to receive. This function transfers the specified LP tokens from the user to the liquidity pool and returns the corresponding amounts of each token.

5. Token swaps can be performed by calling the ***swapExactInput*** or ***swapExactOutput*** functions. ***swapExactInput*** allows users to swap a specific amount of input token for an unspecified amount of output token, while ***swapExactOutput*** allows users to specify the desired amount of output token and receive an unspecified amount of input token. These functions utilize the liquidity pool to execute the swaps.

*Note: This implementation serves as a basic example and should not be used in production environments without thorough security audits and additional functionality.*
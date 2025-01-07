// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct SwapArgs {
    address tokenIn;
    address swapTarget;
    bytes swapCallData;
}

struct ExchangeArgs {
    address exchange;
    bool allowed;
}

interface ISwapper {
    /**
     * @notice Swaps tokens according to the provided swap arguments.
     * @param swapArgs The swap arguments.
     * @param tokenOut The token to be received.
     * @return tokenOutAmount The amount of tokenOut received.
     */
    function swap(SwapArgs[] memory swapArgs, address tokenOut) external returns (uint256 tokenOutAmount);

    /**
     * @notice Updates the exchange allowlist.
     * @param exchangeArgs The exchange arguments.
     */
    function updateExchangeAllowlist(ExchangeArgs[] calldata exchangeArgs) external;
}

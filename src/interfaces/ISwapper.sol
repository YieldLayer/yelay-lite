// SPDX-License-Identifier: UNLICENSED
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
    function swap(SwapArgs[] memory swapArgs, address tokenOut) external returns (uint256 tokenOutAmount);
    function updateExchangeAllowlist(ExchangeArgs[] calldata exchangeArgs) external;
}

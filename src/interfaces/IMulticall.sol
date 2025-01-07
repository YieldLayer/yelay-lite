// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMulticall {
    // @inheritdoc Multicall
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

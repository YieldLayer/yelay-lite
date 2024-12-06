// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IMulticall {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

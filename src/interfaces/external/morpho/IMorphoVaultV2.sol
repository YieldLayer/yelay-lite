// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMorphoVaultV2 {
    function forceDeallocate(address adapter, bytes calldata data, uint256 assets, address onBehalf)
        external
        returns (uint256 penaltyShares);
}

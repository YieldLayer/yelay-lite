// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMerklDistributor {
    function claim(address[] memory users, address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs)
        external;
}

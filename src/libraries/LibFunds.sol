// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@solmate/utils/SafeTransferLib.sol";

library LibFunds {
    /// @custom:storage-location erc7201:yelay-lite-vault.storage.FundsFacet
    struct FundsStorage {
        ERC20 underlyingAsset;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-lite-vault.storage.FundsFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FundsStorageLocation = 0xacb92224aed5243c06a7d52fe2324dfee0ba4ce8a4d1e16700c861c6ab4bab00;

    function _getFundsStorage() internal pure returns (FundsStorage storage $) {
        assembly {
            $.slot := FundsStorageLocation
        }
    }
}

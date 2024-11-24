// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@solmate/utils/SafeTransferLib.sol";

library LibFunds {
    struct StrategyData {
        address adapter;
        // for instance Morpho requires bytes32 market id
        // aave3 aToken address
        bytes supplement;
    }

    /// @custom:storage-location erc7201:yelay-vault.storage.FundsFacet
    struct FundsStorage {
        uint256 lastTotalAssets;
        // balance of underlying asset in the vault
        uint256 underlyingBalance;
        ERC20 underlyingAsset;
        address yieldExtractor;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.FundsFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FundsStorageLocation = 0xe9f6622f42b3306a25789276a3506ebaae4fda2335fb5bfa8bfd419c0dde8100;

    function _getFundsStorage() internal pure returns (FundsStorage storage $) {
        assembly {
            $.slot := FundsStorageLocation
        }
    }
}

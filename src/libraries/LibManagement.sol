// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@solmate/utils/SafeTransferLib.sol";

library LibManagement {
    struct StrategyData {
        address adapter;
        // for instance Morpho requires bytes32 market id
        // aave3 aToken address
        bytes supplement;
    }

    /// @custom:storage-location erc7201:yelay-vault.storage.ManagementFacet
    struct ManagementStorage {
        StrategyData[] strategies;
        // indexes of strategies list - not obligatory containing all indexes
        uint256[] depositQueue;
        uint256[] withdrawQueue;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.ManagementFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ManagementStorageLocation =
        0xe63bd6ac2e2e77423b5d37c9b15c55e67bb68fc23e21066ec76e46b260bfb100;

    function _getManagementStorage() internal pure returns (ManagementStorage storage $) {
        assembly {
            $.slot := ManagementStorageLocation
        }
    }
}

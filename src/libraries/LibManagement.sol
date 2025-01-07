// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";

library LibManagement {
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

    /**
     * @dev Returns the asset balance of a strategy at the given index.
     * @param index The index of the strategy.
     * @return The asset balance of the strategy.
     */
    function _strategyAssets(uint256 index) internal view returns (uint256) {
        LibManagement.ManagementStorage storage sM = _getManagementStorage();
        return IStrategyBase(sM.strategies[index].adapter).assetBalance(address(this), sM.strategies[index].supplement);
    }
}

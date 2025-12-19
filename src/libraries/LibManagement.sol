// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";

library LibManagement {
    /**
     * @custom:storage-location erc7201:yelay-vault.storage.ManagementFacet
     * @custom:member strategies The list of strategies.
     * @custom:member depositQueue The indexes of strategies for deposit queue.
     * @custom:member withdrawQueue The indexes of strategies for withdraw queue.
     */
    struct ManagementStorage {
        // list of all strategies which can be used by the vault => defined by STRATEGY_AUTHORITY
        StrategyData[] strategies;
        mapping(bytes32 => bool) strategyRegistered;
        // list of strategies which currently used for investments => defined by QUEUES_OPERATOR
        StrategyData[] activeStrategies;
        mapping(bytes32 => bool) strategyIsActive;
        // indexes of strategies form activeStrategies list - not obligatory containing all indexes
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
        return IStrategyBase(sM.activeStrategies[index].adapter)
            .assetBalance(address(this), sM.activeStrategies[index].supplement);
    }
}

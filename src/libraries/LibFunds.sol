// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@solmate/utils/SafeTransferLib.sol";

library LibFunds {
    /**
     * @custom:storage-location erc7201:yelay-vault.storage.FundsFacet
     * @custom:member underlyingBalance The balance of the underlying asset held by the vault excluding assets in strategies.
     * @custom:member lastTotalAssetsUpdateInterval The interval for updating the last total assets on deposit.
     * @custom:member lastTotalAssets The last total assets value for yield calculation.
     * @custom:member lastTotalAssetsTimestamp The timestamp of the last total assets update.
     * @custom:member underlyingAsset The underlying asset.
     * @custom:member yieldExtractor The address of the yield extractor.
     */
    struct FundsStorage {
        uint192 underlyingBalance;
        uint64 lastTotalAssetsUpdateInterval;
        uint192 lastTotalAssets;
        uint64 lastTotalAssetsTimestamp;
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

    /// @custom:storage-location erc7201:openzeppelin.storage.ERC1155
    struct ERC1155Storage {
        mapping(uint256 id => mapping(address account => uint256)) _balances;
        mapping(address account => mapping(address operator => bool)) _operatorApprovals;
        // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
        string _uri;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC1155")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC1155StorageLocation = 0x88be536d5240c274a3b1d3a1be54482fd9caa294f08c62a7cde569f49a3c4500;

    function _getERC1155Storage() internal pure returns (ERC1155Storage storage $) {
        assembly {
            $.slot := ERC1155StorageLocation
        }
    }
}

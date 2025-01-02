// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {ISwapper} from "src/interfaces/ISwapper.sol";

library LibFunds {
    struct StrategyData {
        address adapter;
        // for instance Morpho requires bytes32 market id
        // aave3 aToken address
        bytes supplement;
    }

    /// @custom:storage-location erc7201:yelay-vault.storage.FundsFacet
    struct FundsStorage {
        uint192 lastTotalAssets;
        uint64 lastTotalAssetsTimestamp;
        // balance of underlying asset in the vault
        uint256 underlyingBalance;
        ERC20 underlyingAsset;
        ISwapper swapper;
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

    /// @custom:storage-location erc7201:openzeppelin.storage.ERC1155Supply
    struct ERC1155SupplyStorage {
        mapping(uint256 id => uint256) _totalSupply;
        uint256 _totalSupplyAll;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC1155Supply")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC1155SupplyStorageLocation =
        0x4a593662ee04d27b6a00ebb31be7fe0c102c2ade82a7c5d764f2df05dc4e2800;

    function _getERC1155SupplyStorage() private pure returns (ERC1155SupplyStorage storage $) {
        assembly {
            $.slot := ERC1155SupplyStorageLocation
        }
    }
}

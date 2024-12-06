// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/utils/Address.sol";

import {TokenFacet} from "src/facets/TokenFacet.sol";

library LibToken {
    using Address for address;

    function mint(address to, uint256 id, uint256 value) internal {
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.mint.selector, to, id, value));
    }

    function burn(address from, uint256 id, uint256 value) internal {
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.burn.selector, from, id, value));
    }

    function migrate(address account, uint256 fromId, uint256 toId, uint256 value) internal {
        address(this).functionDelegateCall(
            abi.encodeWithSelector(TokenFacet.migrate.selector, account, fromId, toId, value)
        );
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

    function totalSupply() internal view returns (uint256) {
        return _getERC1155SupplyStorage()._totalSupplyAll;
    }

    function totalSupply(uint256 id) internal view returns (uint256) {
        return _getERC1155SupplyStorage()._totalSupply[id];
    }
}

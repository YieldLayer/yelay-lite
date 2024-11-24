// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/utils/Address.sol";

import {TokenFacet} from "src/facets/TokenFacet.sol";

library LibToken {
    using Address for address;

    /// @custom:storage-location erc7201:yelay-vault.storage.TokenFacet
    struct TokenStorage {
        uint256 _totalSupply;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.TokenFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TokenStorageLocation = 0x96e9bc07e4bbede20d6289a6a6d64136db7633a27b2880fb17b26f032a839200;

    function _getTokenStorage() internal pure returns (TokenStorage storage $) {
        assembly {
            $.slot := TokenStorageLocation
        }
    }

    function totalSupply() internal view returns (uint256) {
        TokenStorage storage s = _getTokenStorage();
        return s._totalSupply;
    }

    function mint(address to, uint256 id, uint256 value) internal {
        TokenStorage storage sT = LibToken._getTokenStorage();
        sT._totalSupply += value;
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.mint.selector, to, id, value));
    }

    function burn(address from, uint256 id, uint256 value) internal {
        TokenStorage storage sT = LibToken._getTokenStorage();
        sT._totalSupply -= value;
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.burn.selector, from, id, value));
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

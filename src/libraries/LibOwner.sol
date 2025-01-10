// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibErrors} from "src/libraries/LibErrors.sol";

library LibOwner {
    /// @custom:storage-location erc7201:yelay-vault.storage.OwnerFacet
    /**
     * @custom:member owner The owner of the contract.
     * @custom:member pendingOwner The address pending to become the owner.
     * @custom:member selectorToFacet Mapping from selector to facet address.
     */
    struct OwnerStorage {
        address owner;
        address pendingOwner;
        mapping(bytes4 => address) selectorToFacet;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.OwnerFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OWNER_STORAGE_LOCATION = 0x52b130868e76fc87849159cef46eb9bb0156aa8877197d318e4437829044d000;

    function _getOwnerStorage() internal pure returns (OwnerStorage storage $) {
        assembly {
            $.slot := OWNER_STORAGE_LOCATION
        }
    }

    /**
     * @dev Reverts if the caller is not the owner.
     */
    function onlyOwner() internal view {
        OwnerStorage storage s = _getOwnerStorage();
        require(s.owner == msg.sender, LibErrors.OwnableUnauthorizedAccount(msg.sender));
    }
}

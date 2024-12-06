// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOwnerFacet, SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";

import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

contract OwnerFacet is IOwnerFacet {
    function owner() public view returns (address) {
        return LibOwner._getOwnerStorage().owner;
    }

    function pendingOwner() public view returns (address) {
        return LibOwner._getOwnerStorage().pendingOwner;
    }

    function setSelectorToFacets(SelectorsToFacet[] calldata arr) external {
        LibOwner.onlyOwner();
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();

        for (uint256 i = 0; i < arr.length; i++) {
            SelectorsToFacet memory selectorsToFacet = arr[i];
            for (uint256 j = 0; j < selectorsToFacet.selectors.length; j++) {
                s.selectorToFacet[selectorsToFacet.selectors[j]] = selectorsToFacet.facet;
                emit LibEvents.SelectorToFacetSet(selectorsToFacet.selectors[j], selectorsToFacet.facet);
            }
        }
    }

    function selectorToFacet(bytes4 selector) external view returns (address) {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        return s.selectorToFacet[selector];
    }

    function transferOwnership(address newOwner) external {
        LibOwner.onlyOwner();
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        s.pendingOwner = newOwner;
        emit LibEvents.OwnershipTransferStarted(s.owner, s.pendingOwner);
    }

    function acceptOwnership() external {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        address _pendingOwner = s.pendingOwner;
        require(_pendingOwner == msg.sender, LibErrors.OwnableUnauthorizedAccount(msg.sender));
        emit LibEvents.OwnershipTransferred(s.owner, _pendingOwner);
        s.owner = _pendingOwner;
        s.pendingOwner = address(0);
    }
}

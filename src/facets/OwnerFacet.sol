// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IOwnerFacet, SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";

import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

/**
 * @title OwnerFacet
 * @dev Contract that provides ownership management functionality.
 */
contract OwnerFacet is IOwnerFacet {
    address immutable self;

    constructor() {
        self = address(this);
    }

    /// @inheritdoc IOwnerFacet
    function owner() external view returns (address) {
        return LibOwner._getOwnerStorage().owner;
    }

    /// @inheritdoc IOwnerFacet
    function pendingOwner() external view returns (address) {
        return LibOwner._getOwnerStorage().pendingOwner;
    }

    function addSelectors(SelectorsToFacet[] calldata arr) external {
        LibOwner.onlyOwner();
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();

        for (uint256 i = 0; i < arr.length; i++) {
            SelectorsToFacet memory selectorsToFacet = arr[i];
            for (uint256 j = 0; j < selectorsToFacet.selectors.length; j++) {
                require(
                    s.selectorToFacet[selectorsToFacet.selectors[j]] == address(0),
                    LibErrors.SelectorCollision(selectorsToFacet.facet, selectorsToFacet.selectors[j])
                );
                s.selectorToFacet[selectorsToFacet.selectors[j]] = selectorsToFacet.facet;
                emit LibEvents.SelectorAdded(selectorsToFacet.selectors[j], selectorsToFacet.facet);
            }
        }
    }

    function updateSelectors(SelectorsToFacet[] calldata arr) external {
        LibOwner.onlyOwner();
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();

        for (uint256 i = 0; i < arr.length; i++) {
            SelectorsToFacet memory selectorsToFacet = arr[i];
            for (uint256 j = 0; j < selectorsToFacet.selectors.length; j++) {
                address currentFacet = s.selectorToFacet[selectorsToFacet.selectors[j]];
                require(currentFacet != address(0), LibErrors.SelectorNotSet(selectorsToFacet.selectors[j]));
                require(currentFacet != self, LibErrors.ForbiddenOwnerSelector(selectorsToFacet.selectors[j]));
                s.selectorToFacet[selectorsToFacet.selectors[j]] = selectorsToFacet.facet;
                emit LibEvents.SelectorUpdated(selectorsToFacet.selectors[j], selectorsToFacet.facet);
            }
        }
    }

    function removeSelectors(bytes4[] calldata selectors) external {
        LibOwner.onlyOwner();
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();

        for (uint256 i = 0; i < selectors.length; i++) {
            address currentFacet = s.selectorToFacet[selectors[i]];
            require(currentFacet != address(0), LibErrors.SelectorNotSet(selectors[i]));
            require(currentFacet != self, LibErrors.ForbiddenOwnerSelector(selectors[i]));
            delete s.selectorToFacet[selectors[i]];
            emit LibEvents.SelectorRemoved(selectors[i]);
        }
    }

    /// @inheritdoc IOwnerFacet
    function selectorToFacet(bytes4 selector) external view returns (address) {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        return s.selectorToFacet[selector];
    }

    /// @inheritdoc IOwnerFacet
    function transferOwnership(address newOwner) external {
        LibOwner.onlyOwner();
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        s.pendingOwner = newOwner;
        emit LibEvents.OwnershipTransferStarted(s.owner, s.pendingOwner);
    }

    /// @inheritdoc IOwnerFacet
    function acceptOwnership() external {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        address _pendingOwner = s.pendingOwner;
        require(_pendingOwner == msg.sender, LibErrors.OwnableUnauthorizedAccount(msg.sender));
        emit LibEvents.OwnershipTransferred(s.owner, _pendingOwner);
        s.owner = _pendingOwner;
        s.pendingOwner = address(0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Proxy} from "@openzeppelin/proxy/Proxy.sol";
import {Multicall} from "@openzeppelin/utils/Multicall.sol";

import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

import {IOwnerFacet} from "src/interfaces/IOwnerFacet.sol";

contract YelayLiteVault is Proxy, Multicall {
    constructor(address _owner, address _ownerFacet) {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        // set owner
        s.owner = _owner;

        // set OwnerFacet selectors
        s.selectorToFacet[IOwnerFacet.owner.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.pendingOwner.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.transferOwnership.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.acceptOwnership.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.setSelectorToFacets.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.selectorToFacet.selector] = _ownerFacet;

        // set Multicall selector
        s.selectorToFacet[Multicall.multicall.selector] = address(this);
    }

    function _implementation() internal view override returns (address) {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        address facet = s.selectorToFacet[msg.sig];
        require(facet != address(0), LibErrors.InvalidSelector(msg.sig));
        return facet;
    }

    receive() external payable {}
}

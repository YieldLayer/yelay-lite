// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibFunds, ERC20} from "src/libraries/LibFunds.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

import {IOwnerFacet} from "src/interfaces/IOwnerFacet.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

contract YelayLiteVault is Proxy, Multicall {
    constructor(
        address _owner,
        address _ownerFacet,
        address underlyingAsset,
        address yieldExtractor,
        string memory uri
    ) {
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

        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        sF.underlyingAsset = ERC20(underlyingAsset);
        sF.yieldExtractor = yieldExtractor;

        LibFunds.ERC1155Storage storage sT = LibFunds._getERC1155Storage();
        sT._uri = uri;
    }

    function _implementation() internal view override returns (address) {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        address facet = s.selectorToFacet[msg.sig];
        require(facet != address(0), LibErrors.InvalidSelector(msg.sig));
        return facet;
    }

    receive() external payable {}
}

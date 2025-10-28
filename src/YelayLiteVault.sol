// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibFunds, ERC20} from "src/libraries/LibFunds.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

import {IOwnerFacet} from "src/interfaces/IOwnerFacet.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

contract YelayLiteVault is Proxy, Multicall {
    function initialize(
        address _owner,
        address _ownerFacet,
        address underlyingAsset,
        address yieldExtractor,
        string memory uri,
        address[] memory facets,
        bytes[] memory payloads
    ) external {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        require(s.initialized == false, LibErrors.AlreadyInitialized());
        require(facets.length == payloads.length, LibErrors.MalformedInitData());
        // immediately prevent reentrancy
        s.initialized = true;

        // allow sender to execute admin functions for initial setup
        s.owner = msg.sender;

        // set OwnerFacet selectors
        s.selectorToFacet[IOwnerFacet.owner.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.pendingOwner.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.transferOwnership.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.acceptOwnership.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.addSelectors.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.updateSelectors.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.removeSelectors.selector] = _ownerFacet;
        s.selectorToFacet[IOwnerFacet.selectorToFacet.selector] = _ownerFacet;

        // set Multicall selector
        s.selectorToFacet[Multicall.multicall.selector] = address(this);

        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        sF.underlyingAsset = ERC20(underlyingAsset);
        sF.yieldExtractor = yieldExtractor;

        LibFunds.ERC1155Storage storage sT = LibFunds._getERC1155Storage();
        sT._uri = uri;

        for (uint256 i; i < facets.length; i++) {
            Address.functionDelegateCall(facets[i], payloads[i]);
        }

        // set actual owner
        s.owner = _owner;
    }

    function _implementation() internal view override returns (address) {
        LibOwner.OwnerStorage storage s = LibOwner._getOwnerStorage();
        address facet = s.selectorToFacet[msg.sig];
        require(facet != address(0), LibErrors.InvalidSelector(msg.sig));
        return facet;
    }

    receive() external payable {}
}

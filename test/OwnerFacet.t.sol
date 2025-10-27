// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {IOwnerFacet} from "src/interfaces/IOwnerFacet.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {ClientsFacet, ClientData} from "src/facets/ClientsFacet.sol";
import {OwnerFacet, SelectorsToFacet} from "src/facets/OwnerFacet.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

import {MockStrategy} from "./MockStrategy.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract OwnerFacetTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant yieldExtractor = address(0x02);
    address constant newOwner = address(0x03);
    address constant user = address(0x04);

    IYelayLiteVault yelayLiteVault;

    MockToken underlyingAsset;

    function setUp() external {
        vm.startPrank(owner);
        underlyingAsset = new MockToken("Y-Test", "Y-T", 18);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        vm.stopPrank();
    }

    function test_ownership() external {
        assertEq(yelayLiteVault.owner(), owner);
        assertEq(yelayLiteVault.pendingOwner(), address(0));

        vm.startPrank(newOwner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OwnableUnauthorizedAccount.selector, newOwner));
        yelayLiteVault.transferOwnership(newOwner);
        vm.stopPrank();

        vm.startPrank(owner);
        yelayLiteVault.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(yelayLiteVault.owner(), owner);
        assertEq(yelayLiteVault.pendingOwner(), newOwner);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OwnableUnauthorizedAccount.selector, owner));
        yelayLiteVault.acceptOwnership();
        vm.stopPrank();

        vm.startPrank(newOwner);
        yelayLiteVault.acceptOwnership();
        vm.stopPrank();

        assertEq(yelayLiteVault.owner(), newOwner);
        assertEq(yelayLiteVault.pendingOwner(), address(0));
    }

    function test_selectorToFacet() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = 0x00000001;
        selectors[1] = 0x00000002;
        address facet = address(0x33);
        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        selectorsToFacets[0] = SelectorsToFacet({facet: facet, selectors: selectors});

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), address(0));
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), address(0));

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OwnableUnauthorizedAccount.selector, user));
        yelayLiteVault.addSelectors(selectorsToFacets);
        vm.stopPrank();

        vm.startPrank(owner);
        yelayLiteVault.addSelectors(selectorsToFacets);
        vm.stopPrank();

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), facet);
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), facet);

        vm.startPrank(owner);
        yelayLiteVault.removeSelectors(selectors);
        vm.stopPrank();

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), address(0));
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), address(0));
    }

    function test_addSelectors_setsFacetAndEmitsEvents() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("foo()"));
        selectors[1] = bytes4(keccak256("bar()"));
        address facet = address(0x1234);

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        selectorsToFacets[0] = SelectorsToFacet({facet: facet, selectors: selectors});

        vm.startPrank(owner);
        for (uint256 i = 0; i < selectors.length; i++) {
            vm.expectEmit(true, true, true, true, address(yelayLiteVault));
            emit LibEvents.SelectorAdded(selectors[i], facet);
        }
        yelayLiteVault.addSelectors(selectorsToFacets);
        vm.stopPrank();

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), facet);
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), facet);
    }

    function test_addSelectors_revertsOnCollision() external {
        bytes4 selector = bytes4(keccak256("collision()"));
        address facet = address(0x1234);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        selectorsToFacets[0] = SelectorsToFacet({facet: facet, selectors: selectors});

        vm.prank(owner);
        yelayLiteVault.addSelectors(selectorsToFacets);

        address anotherFacet = address(0x4321);
        selectorsToFacets[0] = SelectorsToFacet({facet: anotherFacet, selectors: selectors});

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.SelectorCollision.selector, anotherFacet, selector));
        yelayLiteVault.addSelectors(selectorsToFacets);
        vm.stopPrank();
    }

    function test_updateSelectors_updatesFacetAndEmitsEvents() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("toUpdateOne()"));
        selectors[1] = bytes4(keccak256("toUpdateTwo()"));
        address initialFacet = address(0x1001);

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        selectorsToFacets[0] = SelectorsToFacet({facet: initialFacet, selectors: selectors});

        vm.prank(owner);
        yelayLiteVault.addSelectors(selectorsToFacets);

        address updatedFacet = address(0x2002);
        selectorsToFacets[0] = SelectorsToFacet({facet: updatedFacet, selectors: selectors});

        vm.startPrank(owner);
        for (uint256 i = 0; i < selectors.length; i++) {
            vm.expectEmit(true, true, true, true, address(yelayLiteVault));
            emit LibEvents.SelectorUpdated(selectors[i], updatedFacet);
        }
        yelayLiteVault.updateSelectors(selectorsToFacets);
        vm.stopPrank();

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), updatedFacet);
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), updatedFacet);
    }

    function test_updateSelectors_revertsWhenSelectorNotSet() external {
        bytes4 selector = bytes4(keccak256("missingSelector()"));
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;
        address facet = address(0x9999);

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        selectorsToFacets[0] = SelectorsToFacet({facet: facet, selectors: selectors});

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.SelectorNotSet.selector, selector));
        yelayLiteVault.updateSelectors(selectorsToFacets);
        vm.stopPrank();
    }

    function test_updateSelectors_revertsForOwnerSelectors() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IOwnerFacet.addSelectors.selector;
        selectors[1] = IOwnerFacet.removeSelectors.selector;
        address facet = address(0xBEEF);

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        selectorsToFacets[0] = SelectorsToFacet({facet: facet, selectors: selectors});

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ForbiddenOwnerSelector.selector, selectors[0]));
        yelayLiteVault.updateSelectors(selectorsToFacets);
        vm.stopPrank();
    }

    function test_removeSelectors_removesFacetAndEmitsEvents() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("toRemoveOne()"));
        selectors[1] = bytes4(keccak256("toRemoveTwo()"));
        address facet = address(0xAAAA);

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        selectorsToFacets[0] = SelectorsToFacet({facet: facet, selectors: selectors});

        vm.prank(owner);
        yelayLiteVault.addSelectors(selectorsToFacets);

        vm.startPrank(owner);
        for (uint256 i = 0; i < selectors.length; i++) {
            vm.expectEmit(true, true, false, true, address(yelayLiteVault));
            emit LibEvents.SelectorRemoved(selectors[i]);
        }
        yelayLiteVault.removeSelectors(selectors);
        vm.stopPrank();

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), address(0));
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), address(0));
    }

    function test_removeSelectors_revertsWhenSelectorNotSet() external {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("notSet()"));

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.SelectorNotSet.selector, selectors[0]));
        yelayLiteVault.removeSelectors(selectors);
        vm.stopPrank();
    }

    function test_removeSelectors_revertsForOwnerSelectors() external {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IOwnerFacet.addSelectors.selector;
        selectors[1] = IOwnerFacet.updateSelectors.selector;

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ForbiddenOwnerSelector.selector, selectors[0]));
        yelayLiteVault.removeSelectors(selectors);
        vm.stopPrank();
    }
}

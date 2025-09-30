// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {ClientsFacet, ClientData} from "src/facets/ClientsFacet.sol";
import {OwnerFacet, SelectorsToFacet} from "src/facets/OwnerFacet.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";

import {MockToken} from "test/mocks/MockToken.sol";
import {Utils} from "test/Utils.sol";

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
        selectors[0] = bytes4(bytes32(uint256(1)));
        selectors[1] = bytes4(bytes32(uint256(2)));
        address facet = address(0x33);
        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        selectorsToFacets[0] = SelectorsToFacet({facet: facet, selectors: selectors});

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), address(0));
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), address(0));

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OwnableUnauthorizedAccount.selector, user));
        yelayLiteVault.setSelectorToFacets(selectorsToFacets);
        vm.stopPrank();

        vm.startPrank(owner);
        yelayLiteVault.setSelectorToFacets(selectorsToFacets);
        vm.stopPrank();

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), facet);
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), facet);

        selectorsToFacets[0] = SelectorsToFacet({facet: address(0), selectors: selectors});

        vm.startPrank(owner);
        yelayLiteVault.setSelectorToFacets(selectorsToFacets);
        vm.stopPrank();

        assertEq(yelayLiteVault.selectorToFacet(selectors[0]), address(0));
        assertEq(yelayLiteVault.selectorToFacet(selectors[1]), address(0));
    }
}

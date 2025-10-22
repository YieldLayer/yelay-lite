// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {
    AccessControlUpgradeable,
    IAccessControl
} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {IFundsFacetBase} from "src/interfaces/IFundsFacetBase.sol";
import {IMulticall} from "src/interfaces/IMulticall.sol";

import {MockStrategy} from "./MockStrategy.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract AccessFacetTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant yieldExtractor = address(0x02);
    address constant user = address(0x03);

    IYelayLiteVault yelayLiteVault;

    MockToken underlyingAsset;

    function setUp() external {
        vm.startPrank(owner);
        underlyingAsset = new MockToken("Y-Test", "Y-T", 18);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        vm.stopPrank();
    }

    function test_roleManagement() external {
        bytes32 role = keccak256("some_role");

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OwnableUnauthorizedAccount.selector, user));
        yelayLiteVault.grantRole(role, user);
        vm.stopPrank();

        vm.startPrank(owner);
        yelayLiteVault.grantRole(role, user);
        vm.stopPrank();

        assertEq(yelayLiteVault.hasRole(role, user), true);

        vm.startPrank(user);
        yelayLiteVault.checkRole(role);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OwnableUnauthorizedAccount.selector, user));
        yelayLiteVault.revokeRole(role, user);
        vm.stopPrank();

        vm.startPrank(owner);
        yelayLiteVault.revokeRole(role, user);
        vm.stopPrank();

        assertEq(yelayLiteVault.hasRole(role, user), false);

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, role));
        yelayLiteVault.checkRole(role);
        vm.stopPrank();
    }

    function test_setPaused() external {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, LibRoles.PAUSER)
        );
        yelayLiteVault.setPaused(IFundsFacetBase.deposit.selector, true);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, LibRoles.UNPAUSER)
        );
        yelayLiteVault.setPaused(IFundsFacetBase.deposit.selector, false);
        vm.stopPrank();

        vm.startPrank(owner);
        yelayLiteVault.grantRole(LibRoles.PAUSER, user);
        yelayLiteVault.grantRole(LibRoles.UNPAUSER, user);
        vm.stopPrank();

        assertEq(yelayLiteVault.selectorToPaused(IFundsFacetBase.deposit.selector), false);

        vm.startPrank(user);
        yelayLiteVault.setPaused(IFundsFacetBase.deposit.selector, true);

        assertEq(yelayLiteVault.selectorToPaused(IFundsFacetBase.deposit.selector), true);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Paused.selector, IFundsFacetBase.deposit.selector));
        yelayLiteVault.deposit(1, 1, user);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(IFundsFacetBase.deposit.selector, 1, 1, user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Paused.selector, IFundsFacetBase.deposit.selector));
        yelayLiteVault.multicall(data);

        yelayLiteVault.setPaused(IFundsFacetBase.deposit.selector, false);
        assertEq(yelayLiteVault.selectorToPaused(IFundsFacetBase.deposit.selector), false);
        vm.stopPrank();
    }
}

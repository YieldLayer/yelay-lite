// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {ClientsFacet, ClientData} from "src/facets/ClientsFacet.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";

import {MockStrategy} from "./MockStrategy.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract ClientsFacetTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant yieldExtractor = address(0x02);
    address constant user = address(0x03);
    address constant client = address(0x04);
    address constant client2 = address(0x05);

    IYelayLiteVault yelayLiteVault;

    MockToken underlyingAsset;

    function setUp() external {
        vm.startPrank(owner);
        underlyingAsset = new MockToken("Y-Test", "Y-T", 18);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        vm.stopPrank();
        deal(address(underlyingAsset), user, 1000e18);
    }

    function test_createClient() external {
        vm.startPrank(client);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, client, LibRoles.CLIENT_MANAGER
            )
        );
        yelayLiteVault.createClient(client, 1000, "");
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ClientNameEmpty.selector));
        yelayLiteVault.createClient(client, 1000, "");
        yelayLiteVault.createClient(client, 1000, "client");
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ClientOwnerReserved.selector));
        yelayLiteVault.createClient(client, 2000, "client2");
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ClientNameTaken.selector));
        yelayLiteVault.createClient(address(0x123456), 2000, "client");
        vm.stopPrank();

        assertEq(yelayLiteVault.lastProjectId(), 1999);
        assertEq(yelayLiteVault.isClientNameTaken("client"), true);
        ClientData memory clientData = yelayLiteVault.ownerToClientData(client);
        assertEq(clientData.minProjectId, 1000);
        assertEq(clientData.maxProjectId, 1999);
        assertEq(clientData.clientName, "client");
    }

    function test_transferClientOwnership() external {
        vm.startPrank(owner);
        yelayLiteVault.createClient(client, 1000, "client");
        yelayLiteVault.createClient(client2, 1000, "client2");
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotClientOwner.selector));
        yelayLiteVault.transferClientOwnership(user);
        vm.stopPrank();

        vm.startPrank(client);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ClientOwnerReserved.selector));
        yelayLiteVault.transferClientOwnership(client2);

        yelayLiteVault.transferClientOwnership(user);
        vm.stopPrank();

        {
            ClientData memory clientData = yelayLiteVault.ownerToClientData(client);
            assertEq(clientData.minProjectId, 0);
            assertEq(clientData.maxProjectId, 0);
            assertEq(clientData.clientName, "");
        }

        {
            ClientData memory clientData = yelayLiteVault.ownerToClientData(user);
            assertEq(clientData.minProjectId, 1000);
            assertEq(clientData.maxProjectId, 1999);
            assertEq(clientData.clientName, "client");
        }
    }

    function test_activateProject() external {
        vm.startPrank(owner);
        yelayLiteVault.createClient(client, 1000, "client");
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotClientOwner.selector));
        yelayLiteVault.activateProject(1000);
        vm.stopPrank();

        assertEq(yelayLiteVault.projectIdActive(1000), false);
        assertEq(yelayLiteVault.projectIdToClientName(1000), "");

        vm.startPrank(client);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OutOfBoundProjectId.selector));
        yelayLiteVault.activateProject(123);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OutOfBoundProjectId.selector));
        yelayLiteVault.activateProject(2000);
        yelayLiteVault.activateProject(1000);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectActive.selector));
        yelayLiteVault.activateProject(1000);
        vm.stopPrank();

        assertEq(yelayLiteVault.projectIdActive(1000), true);
        assertEq(yelayLiteVault.projectIdToClientName(1000), "client");
    }

    function test_activateProjectByManager() external {
        vm.startPrank(owner);
        yelayLiteVault.createClient(client, 1000, "client");
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, LibRoles.CLIENT_MANAGER
            )
        );
        yelayLiteVault.activateProjectByManager(client, 1000);
        vm.stopPrank();

        assertEq(yelayLiteVault.projectIdActive(1000), false);
        assertEq(yelayLiteVault.projectIdToClientName(1000), "");

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OutOfBoundProjectId.selector));
        yelayLiteVault.activateProjectByManager(client, 123);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OutOfBoundProjectId.selector));
        yelayLiteVault.activateProjectByManager(client, 2000);
        yelayLiteVault.activateProjectByManager(client, 1000);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectActive.selector));
        yelayLiteVault.activateProjectByManager(client, 1000);
        vm.stopPrank();

        assertEq(yelayLiteVault.projectIdActive(1000), true);
        assertEq(yelayLiteVault.projectIdToClientName(1000), "client");
    }
}

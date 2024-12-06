// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {ClientsFacet, ClientData, ProjectInterceptor, LockConfig, UserLockData} from "src/facets/ClientsFacet.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";

import {MockStrategy} from "./MockStrategy.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract ClientsFacetTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant yieldExtractor = address(0x02);
    address constant user = address(0x03);
    address constant client = address(0x04);

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
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OwnableUnauthorizedAccount.selector, client));
        yelayLiteVault.createClient(client, 0, 1, "");
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.MinIsZero.selector));
        yelayLiteVault.createClient(client, 0, 1, "");
        vm.expectRevert(abi.encodeWithSelector(LibErrors.MaxLessThanMin.selector));
        yelayLiteVault.createClient(client, 1, 1, "");
        vm.expectRevert(abi.encodeWithSelector(LibErrors.MinLessThanLastProjectId.selector));
        yelayLiteVault.createClient(client, 1, 2, "");
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ClientNameEmpty.selector));
        yelayLiteVault.createClient(client, 1000, 1999, "");
        yelayLiteVault.createClient(client, 1000, 1999, "client");
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ClientNameTaken.selector));
        yelayLiteVault.createClient(client, 2000, 2999, "client");
        vm.stopPrank();

        assertEq(yelayLiteVault.lastProjectId(), 1999);
        assertEq(yelayLiteVault.clientNameTaken("client"), true);
        ClientData memory clientData = yelayLiteVault.ownerToClientData(client);
        assertEq(clientData.minProjectId, 1000);
        assertEq(clientData.maxProjectId, 1999);
        assertEq(clientData.clientName, "client");
    }

    function test_transferClientOwnership() external {
        vm.startPrank(owner);
        yelayLiteVault.createClient(client, 1000, 1999, "client");
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotClientOwner.selector));
        yelayLiteVault.transferClientOwnership(user);
        vm.stopPrank();

        vm.startPrank(client);
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
        yelayLiteVault.createClient(client, 1000, 1999, "client");
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

    function test_setProjectInterceptor() external {
        vm.startPrank(owner);
        yelayLiteVault.createClient(client, 1000, 1999, "client");
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotClientOwner.selector));
        yelayLiteVault.setProjectInterceptor(1000, ProjectInterceptor.Lock);
        vm.stopPrank();

        assertEq(uint256(yelayLiteVault.projectIdToProjectInterceptor(1000)), uint256(ProjectInterceptor.None));

        vm.startPrank(client);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OutOfBoundProjectId.selector));
        yelayLiteVault.setProjectInterceptor(123, ProjectInterceptor.Lock);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OutOfBoundProjectId.selector));
        yelayLiteVault.setProjectInterceptor(2000, ProjectInterceptor.Lock);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectInterceptorNone.selector));
        yelayLiteVault.setProjectInterceptor(1000, ProjectInterceptor.None);
        yelayLiteVault.setProjectInterceptor(1000, ProjectInterceptor.Lock);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectInterceptorSet.selector));
        yelayLiteVault.setProjectInterceptor(1000, ProjectInterceptor.Lock);
        vm.stopPrank();

        assertEq(uint256(yelayLiteVault.projectIdToProjectInterceptor(1000)), uint256(ProjectInterceptor.Lock));
    }

    function test_setLockConfig() external {
        vm.startPrank(owner);
        yelayLiteVault.createClient(client, 1000, 1999, "client");
        vm.stopPrank();

        LockConfig memory lockConfig = LockConfig({duration: 60});

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotClientOwner.selector));
        yelayLiteVault.setLockConfig(1000, lockConfig);
        vm.stopPrank();

        assertEq(yelayLiteVault.projectIdToLockConfig(1000).duration, 0);

        vm.startPrank(client);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OutOfBoundProjectId.selector));
        yelayLiteVault.setLockConfig(123, lockConfig);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OutOfBoundProjectId.selector));
        yelayLiteVault.setLockConfig(2000, lockConfig);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectInterceptorIsNotLock.selector));
        yelayLiteVault.setLockConfig(1000, lockConfig);
        yelayLiteVault.setProjectInterceptor(1000, ProjectInterceptor.Lock);
        yelayLiteVault.setLockConfig(1000, lockConfig);
        vm.stopPrank();

        assertEq(yelayLiteVault.projectIdToLockConfig(1000).duration, lockConfig.duration);
    }

    function test_deposit_locking() external {
        vm.startPrank(owner);
        yelayLiteVault.createClient(client, 1000, 1999, "client");
        vm.stopPrank();

        uint256 duration = 60;

        LockConfig memory lockConfig = LockConfig({duration: duration});

        vm.startPrank(user);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectInactive.selector));
        yelayLiteVault.deposit(1000e18, 1000, user);
        vm.stopPrank();

        vm.startPrank(client);
        yelayLiteVault.setProjectInterceptor(1000, ProjectInterceptor.Lock);
        yelayLiteVault.setLockConfig(1000, lockConfig);
        yelayLiteVault.activateProject(1000);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 firstDepositTimestamp = block.timestamp + duration;
        yelayLiteVault.deposit(100e18, 1000, user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.UserLocked.selector));
        yelayLiteVault.redeem(100e18, 1000, user);
        vm.stopPrank();

        {
            UserLockData memory userLock = yelayLiteVault.userToProjectIdToUserLock(user, 1000);
            assertEq(userLock.pointer, 0);
            assertEq(userLock.locks.length, 1);
            assertEq(userLock.locks[0].timestamp, firstDepositTimestamp);
            assertEq(userLock.locks[0].shares, 100e18);
        }

        vm.warp(block.timestamp + 10);

        vm.startPrank(user);
        uint256 secondDepositTimestamp = block.timestamp + duration;

        yelayLiteVault.deposit(200e18, 1000, user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.UserLocked.selector));
        yelayLiteVault.redeem(10e18, 1000, user);
        vm.stopPrank();

        {
            UserLockData memory userLock = yelayLiteVault.userToProjectIdToUserLock(user, 1000);
            assertEq(userLock.pointer, 0);
            assertEq(userLock.locks.length, 2);
            assertEq(userLock.locks[0].timestamp, firstDepositTimestamp);
            assertEq(userLock.locks[0].shares, 100e18);
            assertEq(userLock.locks[1].timestamp, secondDepositTimestamp);
            assertEq(userLock.locks[1].shares, 200e18);
        }

        vm.warp(block.timestamp + 51);

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.UserLocked.selector));
        yelayLiteVault.redeem(101e18, 1000, user);
        yelayLiteVault.redeem(10e18, 1000, user);
        vm.stopPrank();

        {
            UserLockData memory userLock = yelayLiteVault.userToProjectIdToUserLock(user, 1000);
            assertEq(userLock.pointer, 0);
            assertEq(userLock.locks.length, 2);
            assertEq(userLock.locks[0].timestamp, firstDepositTimestamp);
            assertEq(userLock.locks[0].shares, 90e18);
            assertEq(userLock.locks[1].timestamp, secondDepositTimestamp);
            assertEq(userLock.locks[1].shares, 200e18);
        }

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.UserLocked.selector));
        yelayLiteVault.redeem(91e18, 1000, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 60);

        vm.startPrank(user);
        vm.expectRevert();
        yelayLiteVault.redeem(291e18, 1000, user);
        yelayLiteVault.redeem(289e18, 1000, user);
        vm.stopPrank();

        {
            UserLockData memory userLock = yelayLiteVault.userToProjectIdToUserLock(user, 1000);
            assertEq(userLock.pointer, 1);
            assertEq(userLock.locks.length, 2);
            assertEq(userLock.locks[0].timestamp, firstDepositTimestamp);
            assertEq(userLock.locks[0].shares, 0);
            assertEq(userLock.locks[1].timestamp, secondDepositTimestamp);
            assertEq(userLock.locks[1].shares, 1e18);
        }

        vm.startPrank(user);
        yelayLiteVault.redeem(1e18, 1000, user);
        vm.stopPrank();

        {
            UserLockData memory userLock = yelayLiteVault.userToProjectIdToUserLock(user, 1000);
            assertEq(userLock.pointer, 2);
            assertEq(userLock.locks.length, 2);
            assertEq(userLock.locks[0].timestamp, firstDepositTimestamp);
            assertEq(userLock.locks[0].shares, 0);
            assertEq(userLock.locks[1].timestamp, secondDepositTimestamp);
            assertEq(userLock.locks[1].shares, 0);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {Test, console} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract FundsFacetTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant user = address(0x02);
    address constant yieldExtractor = address(0x04);
    uint256 constant projectId = 1;

    IYelayLiteVault yelayLiteVault;

    MockToken underlyingAsset;

    function setUp() external {
        vm.startPrank(owner);
        underlyingAsset = new MockToken("Y-Test", "Y-T", 18);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        yelayLiteVault.grantRole(LibRoles.QUEUES_OPERATOR, owner);
        yelayLiteVault.grantRole(LibRoles.STRATEGY_AUTHORITY, owner);
        yelayLiteVault.grantRole(LibRoles.FUNDS_OPERATOR, owner);
        vm.stopPrank();

        vm.startPrank(user);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.stopPrank();
    }

    function test_deposit_with_no_strategy() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        assertEq(underlyingAsset.balanceOf(user), userBalance);
        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), 0);
        assertEq(yelayLiteVault.totalAssets(), 0);
        assertEq(yelayLiteVault.totalSupply(), 0);
        assertEq(yelayLiteVault.balanceOf(user, projectId), 0);

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectInactive.selector));
        yelayLiteVault.deposit(toDeposit, 100500, user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance - toDeposit);
        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), toDeposit);
        assertEq(yelayLiteVault.totalAssets(), toDeposit);
        assertEq(yelayLiteVault.totalSupply(), toDeposit);
        assertEq(yelayLiteVault.balanceOf(user, projectId), toDeposit);
    }

    function test_withdraw_with_no_strategy() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);

        vm.expectRevert(LibErrors.MinRedeem.selector);
        yelayLiteVault.redeem(10, projectId, user);

        yelayLiteVault.redeem(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance);
        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), 0);
        assertEq(yelayLiteVault.totalSupply(), 0);
        assertEq(yelayLiteVault.balanceOf(user, projectId), 0);
    }

    function test_migrate_position() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        uint256 newProjectId = 2;

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        // only within the same client
        vm.expectRevert(abi.encodeWithSelector(LibErrors.PositionMigrationForbidden.selector));
        yelayLiteVault.migratePosition(projectId, 100500, toDeposit / 4);
        // to non activated project is forbidden
        vm.expectRevert(abi.encodeWithSelector(LibErrors.PositionMigrationForbidden.selector));
        yelayLiteVault.migratePosition(projectId, 51, toDeposit / 4);
        // same projectId
        vm.expectRevert(abi.encodeWithSelector(LibErrors.PositionMigrationForbidden.selector));
        yelayLiteVault.migratePosition(projectId, projectId, toDeposit / 4);
        yelayLiteVault.migratePosition(projectId, newProjectId, toDeposit / 4);
        vm.stopPrank();

        assertEq(yelayLiteVault.balanceOf(user, projectId), 3 * toDeposit / 4);
        assertEq(yelayLiteVault.balanceOf(user, newProjectId), toDeposit / 4);
    }

    function test_setLastTotalAssetsUpdateInterval() external {
        uint64 interval = 100;
        assertEq(yelayLiteVault.lastTotalAssetsUpdateInterval(), 0);
        vm.expectRevert();
        yelayLiteVault.setLastTotalAssetsUpdateInterval(interval);
        vm.startPrank(owner);
        yelayLiteVault.setLastTotalAssetsUpdateInterval(interval);
        vm.stopPrank();
        assertEq(yelayLiteVault.lastTotalAssetsUpdateInterval(), interval);
    }

    function test_compoundUnderlying() external {
        uint256 underlyingAssetBefore = yelayLiteVault.underlyingBalance();
        uint256 totalAssetsBefore = yelayLiteVault.totalAssets();
        vm.startPrank(owner);
        {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, owner, LibRoles.SWAP_REWARDS_OPERATOR
                )
            );
            yelayLiteVault.compoundUnderlyingReward();

            yelayLiteVault.grantRole(LibRoles.SWAP_REWARDS_OPERATOR, owner);
            vm.expectRevert(abi.encodeWithSelector(LibErrors.TotalAssetsLoss.selector));
            yelayLiteVault.compoundUnderlyingReward();
        }
        deal(address(underlyingAsset), address(yelayLiteVault), 1e18);
        uint256 compounded = yelayLiteVault.compoundUnderlyingReward();
        vm.stopPrank();

        assertEq(yelayLiteVault.underlyingBalance(), underlyingAssetBefore + compounded);
        assertEq(yelayLiteVault.totalAssets(), totalAssetsBefore + compounded);
        assertEq(compounded, 1e18);
    }
}

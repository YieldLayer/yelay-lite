// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {Test, console} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {StrategyArgs} from "src/interfaces/IFundsFacetBase.sol";

import {MockStrategy, MockProtocol} from "test/mocks/MockStrategy.sol";
import {MockYieldExtractor} from "test/mocks/MockYieldExtractor.sol";

import {MockToken} from "test/mocks/MockToken.sol";
import {Utils} from "test/Utils.sol";

contract FundsFacetTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant user = address(0x02);
    address constant user2 = address(0x03);

    uint256 constant projectId = 1;

    uint256 constant WITHDRAW_MARGIN = 10;

    IYelayLiteVault yelayLiteVault;

    MockToken underlyingAsset;
    MockYieldExtractor yieldExtractor;
    MockProtocol mockProtocol;
    MockStrategy mockStrategy;

    function setUp() external {
        vm.startPrank(owner);
        underlyingAsset = new MockToken("Y-Test", "Y-T", 18);
        mockProtocol = new MockProtocol(address(underlyingAsset));
        mockStrategy = new MockStrategy(address(mockProtocol));
        yieldExtractor = new MockYieldExtractor();
        yelayLiteVault = Utils.deployDiamond(
            owner, address(underlyingAsset), address(yieldExtractor), "https://yelay-lite-vault/{id}.json"
        );
        yelayLiteVault.grantRole(LibRoles.QUEUES_OPERATOR, owner);
        yelayLiteVault.grantRole(LibRoles.STRATEGY_AUTHORITY, owner);
        yelayLiteVault.grantRole(LibRoles.FUNDS_OPERATOR, owner);
        vm.stopPrank();

        vm.startPrank(user);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user2);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.stopPrank();
    }

    function _addStrategy() internal {
        vm.startPrank(owner);
        StrategyData memory strategy = StrategyData({adapter: address(mockStrategy), supplement: "", name: ""});
        yelayLiteVault.addStrategy(strategy);
        yelayLiteVault.approveStrategy(0, type(uint256).max);
        {
            uint256[] memory queue = new uint256[](1);
            queue[0] = 0;
            yelayLiteVault.activateStrategy(0, queue, queue);
        }
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

    // ========== Tests for transformYieldShares ==========

    function test_transformYieldShares_basic() external {
        // Setup: Add strategy and deposit funds to create some yield shares
        _addStrategy();
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.prank(user);
        uint256 userShares = yelayLiteVault.deposit(toDeposit, projectId, user);

        // Simulate 20% yield generation by setting strategy balance higher
        uint256 yieldAmount = toDeposit * 2 / 10; // 20% yield
        deal(address(underlyingAsset), address(mockProtocol), yieldAmount);
        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit + yieldAmount);

        // Accrue fees to generate yield shares for the yieldExtractor
        yelayLiteVault.accrueFee();

        uint256 yieldShares = yelayLiteVault.balanceOf(address(yieldExtractor), 0); // YIELD_PROJECT_ID = 0
        uint256 newProjectId = 2;
        address receiver = address(0x03);

        assertGt(yieldShares, 0);
        assertEq(yelayLiteVault.balanceOf(receiver, newProjectId), 0);
        assertEq(yelayLiteVault.totalSupply(), userShares + yieldShares);

        // Test transformYieldShares
        vm.prank(address(yieldExtractor));
        vm.expectEmit(true, true, true, true);
        emit LibEvents.YieldSharesTransformed(receiver, newProjectId, yieldShares);
        yelayLiteVault.transformYieldShares(newProjectId, yieldShares, receiver);

        // Verify yield shares were burned from project 0 and minted to new project
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), 0);
        assertEq(yelayLiteVault.balanceOf(receiver, newProjectId), yieldShares);
        assertEq(yelayLiteVault.totalSupply(), userShares + yieldShares);
    }

    function test_transformYieldShares_onlyYieldExtractor() external {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.OnlyYieldExtractor.selector));
        yelayLiteVault.transformYieldShares(projectId, 100, user);
    }

    function test_transformYieldShares_inactiveProject() external {
        vm.prank(address(yieldExtractor));
        vm.expectRevert(abi.encodeWithSelector(LibErrors.PositionMigrationForbidden.selector));
        yelayLiteVault.transformYieldShares(100500, 100, user);
    }

    // ========== Tests for convertToShares / convertToAssets ==========

    function test_convertFunctions_noYield() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        uint256 userShares = yelayLiteVault.deposit(toDeposit, projectId, user);

        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit);

        uint256 assetsToConvert = toDeposit / 2;
        uint256 sharesToConvert = userShares / 4;

        assertEq(userShares, toDeposit);

        assertEq(yelayLiteVault.convertToShares(assetsToConvert), assetsToConvert);
        assertEq(yelayLiteVault.convertToAssets(sharesToConvert), sharesToConvert);
    }

    function test_convertFunctions_withYield() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        uint256 userShares = yelayLiteVault.deposit(toDeposit, projectId, user);

        // Simulate yield by setting strategy balance higher than deposited
        uint256 newBalance = toDeposit * 15 / 10; // 1500e18 (50% yield)
        mockProtocol.setAssetBalance(address(yelayLiteVault), newBalance);

        uint256 assetsToConvert = toDeposit / 2;
        uint256 sharesToConvert = userShares / 4;

        assertEq(yelayLiteVault.totalAssets(), newBalance);
        assertEq(yelayLiteVault.totalSupply(), toDeposit);
        assertEq(yelayLiteVault.totalSupply(0), 0);
        assertEq(yelayLiteVault.convertToShares(assetsToConvert), assetsToConvert);
        assertEq(yelayLiteVault.convertToAssets(sharesToConvert), sharesToConvert);

        vm.prank(owner);
        yelayLiteVault.accrueFee();

        // accounting doesn't change after yield minting
        assertEq(yelayLiteVault.totalAssets(), newBalance);
        assertEq(yelayLiteVault.totalSupply(), newBalance);
        assertEq(yelayLiteVault.totalSupply(0), newBalance - toDeposit);
        assertEq(yelayLiteVault.convertToShares(assetsToConvert), assetsToConvert);
        assertEq(yelayLiteVault.convertToAssets(sharesToConvert), sharesToConvert);
    }

    function test_convertFunctions_withLoss() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        uint256 userShares = yelayLiteVault.deposit(toDeposit, projectId, user);

        // Simulate 50% loss by setting strategy balance lower
        uint256 newBalance = toDeposit / 2;
        mockProtocol.setAssetBalance(address(yelayLiteVault), newBalance);

        uint256 assetsToConvert = toDeposit / 2;
        uint256 sharesToConvert = userShares / 4;

        assertEq(yelayLiteVault.totalAssets(), newBalance);
        assertEq(yelayLiteVault.totalSupply(), toDeposit);
        assertEq(yelayLiteVault.totalSupply(0), 0);
        // With loss, assets should be worth more shares (shares are less valuable)
        assertEq(yelayLiteVault.convertToShares(assetsToConvert), 2 * assetsToConvert);
        assertEq(yelayLiteVault.convertToAssets(sharesToConvert), sharesToConvert / 2);

        vm.prank(owner);
        yelayLiteVault.accrueFee();

        // accounting doesn't change after yield minting
        assertEq(yelayLiteVault.totalAssets(), newBalance);
        assertEq(yelayLiteVault.totalSupply(), toDeposit);
        assertEq(yelayLiteVault.totalSupply(0), 0);
        // With loss, assets should be worth more shares (shares are less valuable)
        assertEq(yelayLiteVault.convertToShares(assetsToConvert), 2 * assetsToConvert);
        assertEq(yelayLiteVault.convertToAssets(sharesToConvert), sharesToConvert / 2);
    }

    // ========== Tests for previewRedeem / previewWithdraw ==========

    function test_preview_noYield() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        uint256 shares = yelayLiteVault.deposit(toDeposit, projectId, user);
        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit);

        uint256 assetsToWithdraw = shares / 2;
        uint256 sharesToRedeem = assetsToWithdraw;
        uint256 expectedAssets = assetsToWithdraw - WITHDRAW_MARGIN;

        assertEq(yelayLiteVault.previewRedeem(sharesToRedeem), expectedAssets);
        // for withdraw we might need more shares
        assertEq(yelayLiteVault.previewWithdraw(assetsToWithdraw), sharesToRedeem + WITHDRAW_MARGIN);
    }

    function test_preview_withYield() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        uint256 shares = yelayLiteVault.deposit(toDeposit, projectId, user);
        // 50% gain
        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit * 3 / 2);

        uint256 assetsToWithdraw = shares / 2;
        uint256 sharesToRedeem = assetsToWithdraw;
        uint256 expectedAssets = assetsToWithdraw - WITHDRAW_MARGIN;

        assertEq(yelayLiteVault.previewRedeem(sharesToRedeem), expectedAssets);
        assertEq(yelayLiteVault.previewWithdraw(assetsToWithdraw), sharesToRedeem + WITHDRAW_MARGIN);

        vm.prank(owner);
        yelayLiteVault.accrueFee();

        // accounting remains the same after fee accrual
        assertEq(yelayLiteVault.previewRedeem(sharesToRedeem), expectedAssets);
        assertEq(yelayLiteVault.previewWithdraw(assetsToWithdraw), sharesToRedeem + WITHDRAW_MARGIN);
    }

    function test_preview_withLoss() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);
        deal(address(underlyingAsset), user2, toDeposit);

        vm.prank(user);
        uint256 shares = yelayLiteVault.deposit(toDeposit, projectId, user);
        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit);
        vm.prank(user2);
        uint256 shares2 = yelayLiteVault.deposit(toDeposit, projectId, user2);

        assertEq(shares, shares2);
        // 50% loss
        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit);

        uint256 assetsToWithdraw = toDeposit / 2;
        uint256 sharesToRedeem = shares;

        assertEq(yelayLiteVault.previewRedeem(sharesToRedeem), toDeposit / 2 - WITHDRAW_MARGIN);
        // 2 * WITHDRAW_MARGIN since the loss is 50%. 10 wei assets corresponds to 20 wei shares in this case
        assertEq(yelayLiteVault.previewWithdraw(assetsToWithdraw), shares + 2 * WITHDRAW_MARGIN);

        vm.prank(owner);
        yelayLiteVault.accrueFee();

        // accounting remains the same after fee accrual
        assertEq(yelayLiteVault.previewRedeem(sharesToRedeem), toDeposit / 2 - WITHDRAW_MARGIN);
        assertEq(yelayLiteVault.previewWithdraw(assetsToWithdraw), shares + 2 * WITHDRAW_MARGIN);
    }
}

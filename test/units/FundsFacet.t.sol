// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {Test, console} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {StrategyArgs} from "src/interfaces/IFundsFacet.sol";
import {ClaimRequest} from "src/interfaces/IYieldExtractor.sol";

import {MockStrategy, MockProtocol, FailingMockStrategy} from "test/mocks/MockStrategy.sol";
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

    // ========== Tests for allowance management  ==========

    function test_deposit_clears_protocol_allowance_after_success() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, 10_000e18);

        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(mockProtocol)), 0);

        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);

        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(mockProtocol)), 0);
    }

    function test_deposit_resets_allowance_when_first_strategy_fails() external {
        vm.startPrank(owner);
        MockProtocol protocolA = new MockProtocol(address(underlyingAsset));
        MockProtocol protocolB = new MockProtocol(address(underlyingAsset));
        FailingMockStrategy stratA = new FailingMockStrategy(address(protocolA));
        MockStrategy stratB = new MockStrategy(address(protocolB));
        yelayLiteVault.addStrategy(StrategyData({adapter: address(stratA), supplement: "", name: ""}));
        yelayLiteVault.addStrategy(StrategyData({adapter: address(stratB), supplement: "", name: ""}));
        uint256[] memory queue = new uint256[](2);
        queue[0] = 0;
        queue[1] = 1;
        yelayLiteVault.activateStrategy(0, new uint256[](0), new uint256[](0));
        yelayLiteVault.activateStrategy(1, queue, queue);
        vm.stopPrank();

        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, 10_000e18);
        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(protocolA)), 0);
        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(protocolB)), 0);

        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);

        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(protocolA)), 0);
        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(protocolB)), 0);
        assertEq(yelayLiteVault.strategyAssets(1), toDeposit);
    }

    function test_deposit_to_strategy_fails_resets_allowance() external {
        vm.startPrank(owner);
        MockProtocol protocol = new MockProtocol(address(underlyingAsset));
        FailingMockStrategy failingStrategy = new FailingMockStrategy(address(protocol));
        yelayLiteVault.addStrategy(StrategyData({adapter: address(failingStrategy), supplement: "", name: ""}));
        uint256[] memory queue = new uint256[](1);
        queue[0] = 0;
        yelayLiteVault.activateStrategy(0, queue, queue);
        vm.stopPrank();

        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, 10_000e18);
        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(protocol)), 0);

        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);

        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(protocol)), 0);
        assertEq(yelayLiteVault.underlyingBalance(), toDeposit);
    }

    function test_managedDeposit_clears_protocol_allowance_after_success() external {
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, 10_000e18);
        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        assertEq(yelayLiteVault.underlyingBalance(), toDeposit);

        vm.startPrank(owner);
        StrategyData memory strategy = StrategyData({adapter: address(mockStrategy), supplement: "", name: ""});
        yelayLiteVault.addStrategy(strategy);
        uint256[] memory queue = new uint256[](1);
        queue[0] = 0;
        yelayLiteVault.activateStrategy(0, queue, queue);
        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(mockProtocol)), 0);

        yelayLiteVault.managedDeposit(StrategyArgs({index: 0, amount: toDeposit}));
        vm.stopPrank();

        assertEq(underlyingAsset.allowance(address(yelayLiteVault), address(mockProtocol)), 0);
        assertEq(yelayLiteVault.underlyingBalance(), 0);
        assertEq(yelayLiteVault.strategyAssets(0), toDeposit);
    }

    // ========== Tests for managedWithdraw role access ==========

    function test_managedWithdraw_onlyCallableBySetRoles() external {
        address stranger = makeAddr("stranger");
        address emergencyOperator = makeAddr("emergencyOperator");
        _addStrategy();

        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit * 2);
        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        assertEq(yelayLiteVault.strategyAssets(0), toDeposit);

        StrategyArgs memory args = StrategyArgs({index: 0, amount: toDeposit});

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.AccessControlUnauthorizedAnyRole.selector,
                stranger,
                LibRoles.FUNDS_OPERATOR,
                LibRoles.EMERGENCY_WITHDRAW_OPERATOR
            )
        );
        yelayLiteVault.managedWithdraw(args);

        vm.prank(owner);
        yelayLiteVault.managedWithdraw(args);
        assertEq(yelayLiteVault.strategyAssets(0), 0);

        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        assertEq(yelayLiteVault.strategyAssets(0), toDeposit);

        vm.startPrank(owner);
        yelayLiteVault.grantRole(LibRoles.EMERGENCY_WITHDRAW_OPERATOR, emergencyOperator);
        yelayLiteVault.revokeRole(LibRoles.FUNDS_OPERATOR, owner);
        vm.stopPrank();

        vm.prank(emergencyOperator);
        yelayLiteVault.managedWithdraw(args);
        assertEq(yelayLiteVault.strategyAssets(0), 0);
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

    // ========== Tests for claimAndRedeem ==========

    function _claimRedeemYieldSetup()
        internal
        returns (uint256 userShares_, uint256 yieldShares_, uint256 yieldAmount_, uint256 toDeposit_)
    {
        _addStrategy();
        toDeposit_ = 1000e18;
        deal(address(underlyingAsset), user, 10_000e18);
        vm.prank(user);
        userShares_ = yelayLiteVault.deposit(toDeposit_, projectId, user);
        yieldAmount_ = toDeposit_ * 2 / 10;
        deal(address(underlyingAsset), address(mockProtocol), yieldAmount_);
        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit_ + yieldAmount_);
        yelayLiteVault.accrueFee();
        yieldShares_ = yelayLiteVault.balanceOf(address(yieldExtractor), 0);
        assertGt(yieldShares_, 0);
    }

    function test_claimAndRedeem_success() external {
        (uint256 userShares, uint256 yieldShares, uint256 yieldAmount, uint256 toDeposit) = _claimRedeemYieldSetup();
        uint256 toClaim = yieldShares;
        yieldExtractor.setToClaim(toClaim);

        address receiver = user2;
        uint256 sharesToRedeem = yieldShares;
        ClaimRequest memory data = ClaimRequest({
            yelayLiteVault: address(yelayLiteVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldShares,
            proof: new bytes32[](0)
        });

        uint256 receiverBalanceBefore = underlyingAsset.balanceOf(receiver);
        uint256 totalSupplyBefore = yelayLiteVault.totalSupply();
        uint256 expectedRedeemAssets = yelayLiteVault.convertToAssets(sharesToRedeem);

        assertEq(yelayLiteVault.totalAssets(), toDeposit + yieldAmount);

        vm.prank(user);
        uint256 assets = yelayLiteVault.claimAndRedeem(data, sharesToRedeem, receiver);

        assertEq(assets, expectedRedeemAssets);

        // claimed: yield shares removed from extractor = toClaim (MockYieldExtractor.toClaim)
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), yieldShares - toClaim);
        // redeemed: burnt shares = shares passed into claimAndRedeem
        assertEq(yelayLiteVault.totalSupply(), totalSupplyBefore - sharesToRedeem);

        assertEq(underlyingAsset.balanceOf(receiver), receiverBalanceBefore + assets);
        assertEq(yelayLiteVault.balanceOf(user, projectId), userShares);
        assertEq(yelayLiteVault.balanceOf(user, 0), 0);
    }

    /// @dev Claim (transform) moves full yield shares to user; redeem burns only part — leftover stays on projectId.
    function test_claimAndRedeem_claimedGreaterThanRedeemed() external {
        (uint256 userShares, uint256 yieldShares, uint256 yieldAmount, uint256 toDeposit) = _claimRedeemYieldSetup();
        uint256 toClaim = yieldShares;
        yieldExtractor.setToClaim(toClaim);
        uint256 sharesToRedeem = yieldShares / 2;
        assertGt(sharesToRedeem, 0);

        ClaimRequest memory data = ClaimRequest({
            yelayLiteVault: address(yelayLiteVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldShares,
            proof: new bytes32[](0)
        });

        uint256 totalSupplyBefore = yelayLiteVault.totalSupply();
        uint256 expectedRedeemAssets = yelayLiteVault.convertToAssets(sharesToRedeem);
        assertEq(yelayLiteVault.totalAssets(), toDeposit + yieldAmount);

        vm.prank(user);
        uint256 assets = yelayLiteVault.claimAndRedeem(data, sharesToRedeem, user);

        assertEq(assets, expectedRedeemAssets);
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), yieldShares - toClaim);
        assertEq(yelayLiteVault.totalSupply(), totalSupplyBefore - sharesToRedeem);
        assertEq(yelayLiteVault.balanceOf(user, projectId), userShares + toClaim - sharesToRedeem);
        assertEq(yelayLiteVault.balanceOf(user, 0), 0);
    }

    /// @dev Redeem burns more shares than transform minted — difference is taken from the user's prior deposit.
    function test_claimAndRedeem_redeemedGreaterThanClaimed() external {
        (uint256 userShares, uint256 yieldShares, uint256 yieldAmount, uint256 toDeposit) = _claimRedeemYieldSetup();
        uint256 toClaim = yieldShares / 2;
        yieldExtractor.setToClaim(toClaim);
        uint256 sharesToRedeem = yieldShares;
        assertGt(toClaim, 0);
        assertGt(sharesToRedeem, toClaim);
        assertGe(userShares + toClaim, sharesToRedeem);

        ClaimRequest memory data = ClaimRequest({
            yelayLiteVault: address(yelayLiteVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldShares,
            proof: new bytes32[](0)
        });

        uint256 totalSupplyBefore = yelayLiteVault.totalSupply();
        uint256 expectedRedeemAssets = yelayLiteVault.convertToAssets(sharesToRedeem);
        assertEq(yelayLiteVault.totalAssets(), toDeposit + yieldAmount);

        vm.prank(user);
        uint256 assets = yelayLiteVault.claimAndRedeem(data, sharesToRedeem, user);

        assertEq(assets, expectedRedeemAssets);
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), yieldShares - toClaim);
        assertEq(yelayLiteVault.totalSupply(), totalSupplyBefore - sharesToRedeem);
        assertEq(yelayLiteVault.balanceOf(user, projectId), userShares + toClaim - sharesToRedeem);
        assertEq(yelayLiteVault.balanceOf(user, 0), 0);
    }

    /// @dev Cannot redeem more shares on projectId than deposit + claimed amount.
    function test_claimAndRedeem_revertsWhenRedeemExceedsDepositPlusClaimed() external {
        (uint256 userShares, uint256 yieldShares,,) = _claimRedeemYieldSetup();
        uint256 toClaim = yieldShares;
        yieldExtractor.setToClaim(toClaim);
        uint256 sharesToRedeem = userShares + toClaim + 1;

        ClaimRequest memory data = ClaimRequest({
            yelayLiteVault: address(yelayLiteVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldShares,
            proof: new bytes32[](0)
        });

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughInternalFunds.selector));
        yelayLiteVault.claimAndRedeem(data, sharesToRedeem, user);
    }

    function test_claimAndRedeem_invalidVault() external {
        _addStrategy();
        uint256 userBalance = 10_000e18;
        deal(address(underlyingAsset), user, userBalance);
        vm.prank(user);
        yelayLiteVault.deposit(1000e18, projectId, user);

        ClaimRequest memory data = ClaimRequest({
            yelayLiteVault: address(0xdead),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: 100,
            proof: new bytes32[](0)
        });

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidClaimVault.selector));
        yelayLiteVault.claimAndRedeem(data, 100, user);
    }

    // ========== Tests for convertToShares / convertToAssets ==========

    function test_convertFunctions_emptyVault() external view {
        uint256 amount = 1000e18;

        assertEq(yelayLiteVault.totalSupply(), 0);
        assertEq(yelayLiteVault.totalAssets(), 0);
        assertEq(yelayLiteVault.convertToShares(amount), amount);
        assertEq(yelayLiteVault.convertToAssets(amount), amount);
        assertEq(yelayLiteVault.convertToShares(0), 0);
        assertEq(yelayLiteVault.convertToAssets(0), 0);
    }

    function test_convertFunctions_insolventVault() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);

        mockProtocol.setAssetBalance(address(yelayLiteVault), 0);

        assertEq(yelayLiteVault.totalAssets(), 0);
        assertGt(yelayLiteVault.totalSupply(), 0);
        assertEq(yelayLiteVault.convertToAssets(0), 0);
        assertEq(yelayLiteVault.convertToAssets(toDeposit / 2), 0);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.VaultInsolvent.selector));
        yelayLiteVault.convertToShares(0);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.VaultInsolvent.selector));
        yelayLiteVault.convertToShares(toDeposit / 2);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.VaultInsolvent.selector));
        yelayLiteVault.previewWithdraw(toDeposit / 2);

        vm.expectRevert(LibErrors.MinRedeem.selector);
        yelayLiteVault.previewRedeem(toDeposit / 2);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.VaultInsolvent.selector));
        yelayLiteVault.deposit(toDeposit / 2, projectId, user);
    }

    /// @dev Same insolvent state as above, but after `accrueFee` has synced `lastTotalAssets` to zero.
    /// View helpers must not spuriously revert; user actions still fail with meaningful errors.
    function test_convertFunctions_insolventVault_afterAccrueFee() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);
        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);

        mockProtocol.setAssetBalance(address(yelayLiteVault), 0);
        yelayLiteVault.accrueFee();
        assertEq(yelayLiteVault.totalAssets(), 0);
        assertGt(yelayLiteVault.totalSupply(), 0);
        assertEq(yelayLiteVault.lastTotalAssets(), 0);

        assertEq(yelayLiteVault.convertToAssets(0), 0);
        assertEq(yelayLiteVault.convertToAssets(toDeposit / 2), 0);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.VaultInsolvent.selector));
        yelayLiteVault.convertToShares(toDeposit / 2);

        vm.expectRevert(LibErrors.MinRedeem.selector);
        yelayLiteVault.previewRedeem(toDeposit / 2);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.VaultInsolvent.selector));
        yelayLiteVault.previewWithdraw(toDeposit / 2);

        vm.prank(user);
        vm.expectRevert(LibErrors.MinRedeem.selector);
        yelayLiteVault.redeem(toDeposit / 2, projectId, user);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.VaultInsolvent.selector));
        yelayLiteVault.deposit(100, projectId, user);

        yelayLiteVault.accrueFee();
        assertEq(yelayLiteVault.lastTotalAssets(), 0);
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), 0);
    }

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

    function test_preview_emptyVault() external view {
        uint256 assets = 1000e18;
        uint256 shares = 1000e18;

        assertEq(yelayLiteVault.previewWithdraw(assets), assets + WITHDRAW_MARGIN);
        assertEq(yelayLiteVault.previewRedeem(shares), shares - WITHDRAW_MARGIN);
    }

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

    function test_previewRedeem_revertsWhenBelowWithdrawMargin() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit);

        // 0 shares -> 0 assets, which is not > WITHDRAW_MARGIN
        vm.expectRevert(LibErrors.MinRedeem.selector);
        yelayLiteVault.previewRedeem(0);

        // Exactly WITHDRAW_MARGIN shares -> WITHDRAW_MARGIN assets (1:1 with no yield),
        // not strictly greater than WITHDRAW_MARGIN, so it must revert
        vm.expectRevert(LibErrors.MinRedeem.selector);
        yelayLiteVault.previewRedeem(WITHDRAW_MARGIN);

        // One wei above the margin succeeds and returns the smallest possible asset amount.
        assertEq(yelayLiteVault.previewRedeem(WITHDRAW_MARGIN + 1), 1);
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

    // ========== Tests for negative yield / share-to-asset ratio decrease ==========

    /// @dev Negative yield (e.g. an underlying-strategy management fee that exceeds APY) must NOT mint fee shares.
    /// The lastTotalAssets baseline should track down to the new (lower) value so subsequent yield can be measured.
    function test_accrueFee_withNegativeYield_doesNotMintFee() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);

        assertEq(yelayLiteVault.lastTotalAssets(), toDeposit);
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), 0);

        // 30% negative yield.
        uint256 newBalance = toDeposit * 7 / 10;
        mockProtocol.setAssetBalance(address(yelayLiteVault), newBalance);

        yelayLiteVault.accrueFee();

        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), 0);
        assertEq(yelayLiteVault.lastTotalAssets(), newBalance);
        assertEq(yelayLiteVault.totalAssets(), newBalance);
        assertEq(yelayLiteVault.totalSupply(), toDeposit);
    }

    /// @dev A new deposit made after a loss must mint more shares per asset to reflect the lower price-per-share.
    function test_deposit_afterNegativeYield_mintsMoreShares() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);
        deal(address(underlyingAsset), user2, toDeposit);

        vm.prank(user);
        uint256 userShares = yelayLiteVault.deposit(toDeposit, projectId, user);
        assertEq(userShares, toDeposit);

        // 50% loss => share price halves.
        mockProtocol.setAssetBalance(address(yelayLiteVault), toDeposit / 2);

        vm.prank(user2);
        uint256 user2Shares = yelayLiteVault.deposit(toDeposit, projectId, user2);

        // Same assets in but 2x shares because price-per-share halved.
        assertEq(user2Shares, toDeposit * 2);
        assertEq(yelayLiteVault.totalSupply(), 3 * toDeposit);
        assertEq(yelayLiteVault.totalAssets(), toDeposit + toDeposit / 2);

        // user1 ate the loss; user2 keeps full purchasing power.
        assertEq(yelayLiteVault.convertToAssets(userShares), toDeposit / 2);
        assertEq(yelayLiteVault.convertToAssets(user2Shares), toDeposit);
    }

    /// @dev Redemption after a loss should give proportionally fewer assets than originally deposited.
    function test_redeem_afterNegativeYield_receivesLessAssets() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        uint256 userShares = yelayLiteVault.deposit(toDeposit, projectId, user);

        // 40% loss reflected by the mock protocol (tokens are still there; the strategy reports less).
        uint256 newBalance = toDeposit * 6 / 10;
        mockProtocol.setAssetBalance(address(yelayLiteVault), newBalance);

        uint256 userBalanceBefore = underlyingAsset.balanceOf(user);
        vm.prank(user);
        uint256 assets = yelayLiteVault.redeem(userShares, projectId, user);

        assertApproxEqAbs(assets, newBalance, WITHDRAW_MARGIN);
        assertEq(underlyingAsset.balanceOf(user), userBalanceBefore + assets);
        assertEq(yelayLiteVault.totalSupply(), 0);
        assertEq(yelayLiteVault.balanceOf(user, projectId), 0);
    }

    /// @dev When yield recovers above the post-loss baseline, the formula must mint fee shares correctly
    /// (this verifies the share-ratio decrease followed by an increase still works end-to-end).
    function test_yieldRecoveryAboveLastTotalAssets_mintsFee() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);
        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);

        // Partial loss to 800 then accrue (resets lastTotalAssets to the lower baseline).
        mockProtocol.setAssetBalance(address(yelayLiteVault), 800e18);
        yelayLiteVault.accrueFee();
        assertEq(yelayLiteVault.lastTotalAssets(), 800e18);
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), 0);

        // Positive yield: 800 -> 1200 (relative to the post-loss baseline, +50%).
        mockProtocol.setAssetBalance(address(yelayLiteVault), 1200e18);
        yelayLiteVault.accrueFee();

        // feeShares = 400e18 * 1000e18 / 800e18 = 500e18.
        uint256 feeShares = yelayLiteVault.balanceOf(address(yieldExtractor), 0);
        assertEq(feeShares, 500e18);
        assertEq(yelayLiteVault.lastTotalAssets(), 1200e18);
        assertEq(yelayLiteVault.totalSupply(), toDeposit + feeShares);
    }

    // ========== Tests for forceDeactivateStrategy & ratio decrease ==========

    /// @dev forceDeactivateStrategy with stranded assets while other strategies still hold funds:
    /// the user takes the loss on redeem proportional to the stranded amount.
    function test_forceDeactivate_partialAssets_redeemReceivesReducedAssets() external {
        vm.startPrank(owner);
        MockProtocol protocolA = new MockProtocol(address(underlyingAsset));
        MockProtocol protocolB = new MockProtocol(address(underlyingAsset));
        MockStrategy stratA = new MockStrategy(address(protocolA));
        MockStrategy stratB = new MockStrategy(address(protocolB));
        yelayLiteVault.addStrategy(StrategyData({adapter: address(stratA), supplement: "", name: ""}));
        yelayLiteVault.addStrategy(StrategyData({adapter: address(stratB), supplement: "", name: ""}));
        uint256[] memory queueA = new uint256[](1);
        queueA[0] = 0;
        yelayLiteVault.activateStrategy(0, queueA, queueA);
        uint256[] memory queueAB = new uint256[](2);
        queueAB[0] = 0;
        queueAB[1] = 1;
        yelayLiteVault.activateStrategy(1, queueAB, queueAB);
        vm.stopPrank();

        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);
        vm.prank(user);
        uint256 userShares = yelayLiteVault.deposit(toDeposit, projectId, user);
        // All deposit funds go to strategy A (first in queue).
        assertEq(yelayLiteVault.strategyAssets(0), toDeposit);

        // Move 600 into strategy B so that 400 remains in strategy A.
        StrategyArgs[] memory withdrawals = new StrategyArgs[](1);
        withdrawals[0] = StrategyArgs({index: 0, amount: 600e18});
        StrategyArgs[] memory deposits = new StrategyArgs[](1);
        deposits[0] = StrategyArgs({index: 1, amount: 600e18});
        vm.prank(owner);
        yelayLiteVault.reallocate(withdrawals, deposits);
        assertEq(yelayLiteVault.strategyAssets(0), 400e18);
        assertEq(yelayLiteVault.strategyAssets(1), 600e18);
        assertEq(yelayLiteVault.totalAssets(), toDeposit);

        // Force-deactivate strategy A. 400e18 are stranded inside protocolA.
        uint256[] memory newQueue = new uint256[](1);
        newQueue[0] = 0; // After deactivation, strategy B is at index 0.
        vm.prank(owner);
        yelayLiteVault.forceDeactivateStrategy(0, newQueue, newQueue);

        assertEq(yelayLiteVault.totalAssets(), 600e18);
        assertEq(yelayLiteVault.totalSupply(), userShares);
        // Stranded assets still exist in protocolA but are no longer counted.
        assertEq(protocolA.assetBalance(address(yelayLiteVault)), 400e18);

        vm.prank(user);
        uint256 assets = yelayLiteVault.redeem(userShares, projectId, user);

        // User receives only the 600e18 that remained in strategy B.
        assertEq(assets, 600e18);
        assertEq(yelayLiteVault.totalSupply(), 0);
    }

    /// @dev After total loss + accrueFee, lastTotalAssets is zero with shares outstanding. Recovery via
    /// compoundUnderlyingReward must not brick the vault (this is the key edge case fixed in _mintFee).
    function test_forceDeactivate_totalLoss_thenAccrueFee_thenRecoverViaCompound() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        uint256 userShares = yelayLiteVault.deposit(toDeposit, projectId, user);
        assertEq(userShares, toDeposit);
        assertEq(yelayLiteVault.lastTotalAssets(), toDeposit);

        // Force-deactivate the only strategy: every cent is stranded outside the vault accounting.
        uint256[] memory queue = new uint256[](0);
        vm.prank(owner);
        yelayLiteVault.forceDeactivateStrategy(0, queue, queue);

        assertEq(yelayLiteVault.totalAssets(), 0);
        assertGt(yelayLiteVault.totalSupply(), 0);

        // Driving lastTotalAssets to zero is what triggers the previously-bricking path.
        yelayLiteVault.accrueFee();
        assertEq(yelayLiteVault.lastTotalAssets(), 0);
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), 0);

        // Simulate a rescue (tokens sent directly to the vault, e.g. governance bailout).
        uint256 rescued = 500e18;
        deal(address(underlyingAsset), address(yelayLiteVault), rescued);

        vm.startPrank(owner);
        yelayLiteVault.grantRole(LibRoles.SWAP_REWARDS_OPERATOR, owner);
        // Pre-fix: this would revert with VaultInsolvent inside _accrueFee -> _mintFee.
        uint256 compounded = yelayLiteVault.compoundUnderlyingReward();
        vm.stopPrank();

        assertEq(compounded, rescued);
        assertEq(yelayLiteVault.totalAssets(), rescued);
        assertEq(yelayLiteVault.lastTotalAssets(), rescued);
        // Recovery is absorbed by existing shareholders rather than minted to the extractor
        // (the share-based fee formula has no baseline to anchor the proportion).
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), 0);

        // Half the original deposit was rescued; existing shares are worth proportionally less.
        assertEq(yelayLiteVault.balanceOf(user, projectId), userShares);
        assertEq(yelayLiteVault.convertToAssets(userShares), rescued);

        // The vault is functional again: a fresh deposit succeeds.
        deal(address(underlyingAsset), user2, 100e18);
        vm.prank(user2);
        uint256 user2Shares = yelayLiteVault.deposit(100e18, projectId, user2);
        assertEq(yelayLiteVault.totalAssets(), rescued + 100e18);
        // Original holder still owns half the rescued pool; new depositor gets full value for their assets.
        assertEq(yelayLiteVault.convertToAssets(userShares), rescued);
        assertEq(yelayLiteVault.convertToAssets(user2Shares), 100e18);
    }

    /// @dev Same recovery edge case, but assets reappear by re-activating the strategy that still holds them.
    function test_forceDeactivate_totalLoss_thenAccrueFee_thenRecoverViaReactivation() external {
        _addStrategy();
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);

        vm.prank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        // Deposit pushes funds into the strategy; protocol carries the assets even after deactivation.
        assertEq(mockProtocol.assetBalance(address(yelayLiteVault)), toDeposit);

        uint256[] memory emptyQueue = new uint256[](0);
        vm.prank(owner);
        yelayLiteVault.forceDeactivateStrategy(0, emptyQueue, emptyQueue);

        assertEq(yelayLiteVault.totalAssets(), 0);
        assertEq(mockProtocol.assetBalance(address(yelayLiteVault)), toDeposit);

        yelayLiteVault.accrueFee();
        assertEq(yelayLiteVault.lastTotalAssets(), 0);

        // Re-activate: the registered strategy is still present and its protocol still reports the balance.
        uint256[] memory newQueue = new uint256[](1);
        newQueue[0] = 0;
        vm.prank(owner);
        yelayLiteVault.activateStrategy(0, newQueue, newQueue);

        assertEq(yelayLiteVault.totalAssets(), toDeposit);

        // Pre-fix this accrue call would revert (lastTotalAssets == 0 with positive totalInterest).
        yelayLiteVault.accrueFee();
        assertEq(yelayLiteVault.lastTotalAssets(), toDeposit);
        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), 0);

        // Original holder can now redeem and recover their full deposit (modulo WITHDRAW_MARGIN).
        vm.prank(user);
        uint256 assets = yelayLiteVault.redeem(toDeposit, projectId, user);
        assertApproxEqAbs(assets, toDeposit, WITHDRAW_MARGIN);
    }
}

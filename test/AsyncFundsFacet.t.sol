// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {IYelayLiteVaultAsync} from "src/interfaces/IYelayLiteVaultAsync.sol";
import {LibAsyncFunds} from "src/libraries/LibAsyncFunds.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract AsyncFundsFacetTest is Test {
    using Utils for address;

    address constant OWNER = address(0x01);
    address constant USER = address(0x02);
    address constant USER2 = address(0x03);
    address constant YIELD_EXTRACTOR = address(0x04);
    address constant FUNDS_OPERATOR = address(0x05);
    uint256 constant PROJECT_ID = 1;

    IYelayLiteVaultAsync yelayLiteVault;
    MockToken underlyingAsset;

    function setUp() external {
        vm.startPrank(OWNER);
        underlyingAsset = new MockToken("Y-Test", "Y-T", 18);
        IYelayLiteVault vault =
            Utils.deployDiamond(OWNER, address(underlyingAsset), YIELD_EXTRACTOR, "https://yelay-lite-vault/{id}.json");
        Utils.upgradeToAsyncFundsFacet(vault);

        yelayLiteVault = IYelayLiteVaultAsync(address(vault));

        // Grant necessary roles
        yelayLiteVault.grantRole(LibRoles.QUEUES_OPERATOR, OWNER);
        yelayLiteVault.grantRole(LibRoles.STRATEGY_AUTHORITY, OWNER);
        yelayLiteVault.grantRole(LibRoles.FUNDS_OPERATOR, OWNER);
        yelayLiteVault.grantRole(LibRoles.FUNDS_OPERATOR, FUNDS_OPERATOR);
        vm.stopPrank();

        // Setup user approvals
        vm.startPrank(USER);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(USER2);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.stopPrank();
    }

    function _depositAndGetShares(address user, uint256 amount) internal returns (uint256 shares) {
        deal(address(underlyingAsset), user, amount);
        vm.startPrank(user);
        shares = yelayLiteVault.deposit(amount, PROJECT_ID, user);
        vm.stopPrank();
    }

    // ========================================
    // requestAsyncFunds Tests
    // ========================================

    function test_requestAsyncFunds_success() external {
        uint256 depositAmount = 1000e18;
        uint256 shares = _depositAndGetShares(USER, depositAmount);
        uint256 sharesToRedeem = shares / 2;

        vm.expectEmit(true, true, true, true);
        emit LibEvents.AsyncFundsRequest(USER, PROJECT_ID, USER, 1, sharesToRedeem);

        vm.startPrank(USER);
        yelayLiteVault.requestAsyncFunds(sharesToRedeem, PROJECT_ID, USER);
        vm.stopPrank();

        // Verify user's shares were transferred to vault
        assertEq(yelayLiteVault.balanceOf(USER, PROJECT_ID), shares - sharesToRedeem);
        assertEq(yelayLiteVault.balanceOf(address(yelayLiteVault), PROJECT_ID), sharesToRedeem);
    }

    function test_requestAsyncFunds_revert_zeroShares() external {
        _depositAndGetShares(USER, 1000e18);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroAmount.selector));
        vm.startPrank(USER);
        yelayLiteVault.requestAsyncFunds(0, PROJECT_ID, USER);
        vm.stopPrank();
    }

    function test_requestAsyncFunds_revert_zeroReceiver() external {
        uint256 shares = _depositAndGetShares(USER, 1000e18);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroAddress.selector));
        vm.startPrank(USER);
        yelayLiteVault.requestAsyncFunds(shares, PROJECT_ID, address(0));
        vm.stopPrank();
    }

    function test_requestAsyncFunds_revert_insufficientBalance() external {
        uint256 shares = _depositAndGetShares(USER, 1000e18);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.InsufficientBalance.selector));
        vm.startPrank(USER);
        yelayLiteVault.requestAsyncFunds(shares + 1, PROJECT_ID, USER);
        vm.stopPrank();
    }

    function test_requestAsyncFunds_revert_whenPaused() external {
        uint256 shares = _depositAndGetShares(USER, 1000e18);

        // Pause the requestAsyncFunds function specifically
        vm.startPrank(OWNER);
        yelayLiteVault.grantRole(LibRoles.PAUSER, OWNER);
        bytes4 selector = bytes4(keccak256("requestAsyncFunds(uint256,uint256,address)"));
        yelayLiteVault.setPaused(selector, true);
        vm.stopPrank();

        vm.startPrank(USER);
        vm.expectRevert(); // Will revert with paused error
        yelayLiteVault.requestAsyncFunds(shares, PROJECT_ID, USER);
        vm.stopPrank();
    }

    // ========================================
    // fullfilAsyncRequest Tests
    // ========================================

    function test_fullfilAsyncRequest_success() external {
        uint256 depositAmount = 1000e18;
        uint256 shares = _depositAndGetShares(USER, depositAmount);

        // Create async request
        vm.startPrank(USER);
        yelayLiteVault.requestAsyncFunds(shares, PROJECT_ID, USER2);
        vm.stopPrank();

        // Add some underlying balance to vault for fulfillment
        deal(address(underlyingAsset), address(yelayLiteVault), depositAmount);

        uint256 receiverBalanceBefore = underlyingAsset.balanceOf(USER2);

        vm.expectEmit(true, true, true, true);
        emit LibEvents.AsyncFundsRequestFullfiled(USER, PROJECT_ID, USER2, 1, shares);

        vm.startPrank(FUNDS_OPERATOR);
        yelayLiteVault.fullfilAsyncRequest(1);
        vm.stopPrank();

        // Verify shares were burned and assets transferred
        assertEq(yelayLiteVault.balanceOf(address(yelayLiteVault), PROJECT_ID), 0);
        assertEq(underlyingAsset.balanceOf(USER2), receiverBalanceBefore + shares);
    }

    function test_fullfilAsyncRequest_revert_invalidRequestId() external {
        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidRequest.selector));
        vm.startPrank(FUNDS_OPERATOR);
        yelayLiteVault.fullfilAsyncRequest(999);
        vm.stopPrank();
    }

    function test_fullfilAsyncRequest_revert_alreadyFulfilled() external {
        uint256 shares = _depositAndGetShares(USER, 1000e18);

        vm.startPrank(USER);
        yelayLiteVault.requestAsyncFunds(shares, PROJECT_ID, USER);
        vm.stopPrank();

        deal(address(underlyingAsset), address(yelayLiteVault), 1000e18);

        // Fulfill once
        vm.startPrank(FUNDS_OPERATOR);
        yelayLiteVault.fullfilAsyncRequest(1);
        vm.stopPrank();

        // Try to fulfill again
        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidRequest.selector));
        vm.startPrank(FUNDS_OPERATOR);
        yelayLiteVault.fullfilAsyncRequest(1);
        vm.stopPrank();
    }

    function test_fullfilAsyncRequest_revert_unauthorizedCaller() external {
        uint256 shares = _depositAndGetShares(USER, 1000e18);

        vm.startPrank(USER);
        yelayLiteVault.requestAsyncFunds(shares, PROJECT_ID, USER);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, USER, LibRoles.FUNDS_OPERATOR
            )
        );
        vm.startPrank(USER);
        yelayLiteVault.fullfilAsyncRequest(1);
        vm.stopPrank();
    }

    function test_fullfilAsyncRequest_revert_insufficientAssets() external {
        uint256 shares = _depositAndGetShares(USER, 1000e18);

        vm.startPrank(USER);
        yelayLiteVault.requestAsyncFunds(shares, PROJECT_ID, USER);
        vm.stopPrank();

        // Remove the underlying assets from vault to simulate insufficient balance
        deal(address(underlyingAsset), address(yelayLiteVault), 0);

        vm.startPrank(FUNDS_OPERATOR);
        vm.expectRevert(); // Will revert on safeTransfer due to insufficient balance
        yelayLiteVault.fullfilAsyncRequest(1);
        vm.stopPrank();
    }

    // ========================================
    // onERC1155BatchReceived Tests
    // ========================================

    function test_onERC1155BatchReceived_revert_notSupported() external {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotSupported.selector));
        yelayLiteVault.onERC1155BatchReceived(address(0), address(0), ids, amounts, "");
    }

    // ========================================
    // totalSupply Override Tests
    // ========================================

    function test_totalSupply_override_returnsCorrectValue() external {
        // Initially no supply
        assertEq(yelayLiteVault.totalSupply(), 0);

        // After deposit, should return total supply
        uint256 depositAmount = 1000e18;
        uint256 shares1 = _depositAndGetShares(USER, depositAmount);
        uint256 shares2 = _depositAndGetShares(USER2, depositAmount);

        uint256 expectedTotalSupply = shares1 + shares2;
        assertEq(yelayLiteVault.totalSupply(), expectedTotalSupply);
    }

    function test_totalSupply_id_override_returnsCorrectValue() external {
        // Initially no supply for any ID
        assertEq(yelayLiteVault.totalSupply(PROJECT_ID), 0);
        assertEq(yelayLiteVault.totalSupply(999), 0);

        // After deposit to PROJECT_ID, should return supply for that ID only
        uint256 depositAmount = 1000e18;
        uint256 shares = _depositAndGetShares(USER, depositAmount);

        assertEq(yelayLiteVault.totalSupply(PROJECT_ID), shares);
        assertEq(yelayLiteVault.totalSupply(999), 0); // Other IDs should still be zero

        // After another deposit to same project
        uint256 shares2 = _depositAndGetShares(USER2, depositAmount);
        assertEq(yelayLiteVault.totalSupply(PROJECT_ID), shares + shares2);
    }
}

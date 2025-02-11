// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DepositLockPlugin} from "src/plugins/deposit-lock/DepositLockPlugin.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";
import {LibErrors} from "src/plugins/deposit-lock/libraries/LibErrors.sol";
import {LibEvents} from "src/plugins/deposit-lock/libraries/LibEvents.sol";

contract DepositLockPluginTest is Test {
    DepositLockPlugin public depositLock;
    IYelayLiteVault public mockVault;
    MockToken public underlying;
    address public projectOwner = address(0x1111);
    address public user = address(0x2222);
    uint256 public projectId = 123;
    // This is the yieldExtractor address used when deploying the vault via Utils.
    address public constant yieldExtractor = address(0x02);
    string public constant uri = "https://yelay-lite-vault/{id}.json";

    function setUp() public {
        // Deploy a mock underlying ERC20 and fund the user.
        underlying = new MockToken("Underlying", "UND", 18);
        deal(address(underlying), user, 10000 ether);

        // Deploy the vault (diamond) with projectOwner as the client owner.
        vm.startPrank(projectOwner);
        mockVault = Utils.deployDiamond(projectOwner, address(underlying), yieldExtractor, uri);
        mockVault.activateProject(projectId);
        vm.stopPrank();

        // Deploy DepositLockPlugin as an upgradeable proxy.
        DepositLockPlugin impl = new DepositLockPlugin();
        depositLock = DepositLockPlugin(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeWithSelector(DepositLockPlugin.initialize.selector, projectOwner)
                )
            )
        );
    }

    // ------------------------------
    // Existing tests
    // ------------------------------

    function test_updateLockPeriod_nonOwnerReverts() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotProjectOwner.selector, projectId, user));
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
    }

    function test_updateLockPeriod_exceedsMaximum() public {
        uint256 excessiveLock = depositLock.MAX_LOCK_PERIOD() + 1;
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.LockPeriodExceedsMaximum.selector, excessiveLock));
        depositLock.updateLockPeriod(address(mockVault), projectId, excessiveLock);
    }

    function test_updateLockPeriod_success() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
        uint256 storedLock = depositLock.projectLockPeriods(address(mockVault), projectId);
        assertEq(storedLock, newLockPeriod);
    }

    function test_depositLocked_revertsIfLockNotSet() public {
        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.DepositLockNotSetForProject.selector, projectId));
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();
    }

    function test_depositLocked_success() public {
        uint256 newLockPeriod = 2 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        uint256 shares = depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        // The shares returned from depositLocked should equal the deposited amount.
        assertEq(shares, depositAmount);

        // Since the deposit has just been recorded, available matured shares should be zero.
        uint256 matured = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(matured, 0);
    }

    function test_getMaturedShares_afterMaturity() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 500 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        // Fast-forward time past the lock period.
        vm.warp(block.timestamp + 1 days + 1);

        uint256 matured = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(matured, depositAmount);
    }

    function test_redeemLocked_success_partialAndFull() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 1000 ether;
        // The user makes two deposits into the same project.
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount * 2);
        // First deposit.
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.warp(block.timestamp + 10); // Advance a bit to differentiate timestamps.
        // Second deposit.
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        // Warp time so that both deposits are matured.
        vm.warp(block.timestamp + 1 days);

        uint256 available = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(available, 2 * depositAmount);

        // Redeem a partial amount (1500 out of 2000 shares).
        vm.startPrank(user);
        uint256 redeemedAssets = depositLock.redeemLocked(address(mockVault), 1500 ether, projectId);
        vm.stopPrank();
        assertEq(redeemedAssets, 1500 ether);

        // There should be 500 matured shares remaining.
        uint256 remaining = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(remaining, 500 ether);

        // Redeem the remaining shares.
        vm.startPrank(user);
        redeemedAssets = depositLock.redeemLocked(address(mockVault), 500 ether, projectId);
        vm.stopPrank();
        assertEq(redeemedAssets, 500 ether);

        // Now, no redeemable shares should remain.
        remaining = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(remaining, 0);
    }

    function test_redeemLocked_insufficientMatured() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        // Without time warp the deposit is not matured and redeem should revert.
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughShares.selector, 1000 ether, 0));
        depositLock.redeemLocked(address(mockVault), 1000 ether, projectId);
        vm.stopPrank();
    }

    function test_checkLocks() public {
        // Use a short lock period for clarity.
        uint256 newLockPeriod = 120; // seconds
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        // Deposit a record.
        vm.startPrank(user);
        underlying.approve(address(depositLock), 1000 ether);
        depositLock.depositLocked(address(mockVault), 1000 ether, projectId);
        vm.stopPrank();

        // Warp time so that the first deposit is matured.
        vm.warp(block.timestamp + 130);

        // Make a second deposit that is still locked.
        vm.startPrank(user);
        underlying.approve(address(depositLock), 500 ether);
        depositLock.depositLocked(address(mockVault), 500 ether, projectId);
        vm.stopPrank();

        // Check maturity status for deposit indices 0 and 1.
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        bool[] memory statuses = depositLock.checkLocks(address(mockVault), projectId, user, indices);
        // The first deposit should be matured; the second should not.
        assertTrue(statuses[0]);
        assertFalse(statuses[1]);
    }

    // ------------------------------
    // New tests for migrateLocked
    // ------------------------------

    function test_migrateLocked_success() public {
        uint256 newLockPeriod = 1 days;
        uint256 toProjectId = 456;
        // Set lock periods for both source and destination projects.
        vm.startPrank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
        depositLock.updateLockPeriod(address(mockVault), toProjectId, newLockPeriod);
        vm.stopPrank();

        uint256 depositAmount = 1000 ether;
        uint256 migrateAmount = 400 ether;

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        uint256 shares = depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        assertEq(shares, depositAmount);

        // Expect the MigrateLocked event to be emitted.
        vm.expectEmit(false, false, false, true);
        emit LibEvents.MigrateLocked(user, projectId, toProjectId, migrateAmount);
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);
        vm.stopPrank();

        // Check that the deposit in the source project has been reduced.
        (uint192 remainingShares,) = depositLock.lockedDeposits(address(mockVault), projectId, user, 0);
        assertEq(remainingShares, depositAmount - migrateAmount);

        // And a new deposit for the destination project should have been created.
        (uint192 migratedShares, uint64 lockTime) = depositLock.lockedDeposits(address(mockVault), toProjectId, user, 0);
        assertEq(migratedShares, migrateAmount);
        // Verify that lockTime is set to the current block timestamp.
        assertEq(lockTime, block.timestamp);
    }

    function test_migrateLocked_insufficientShares() public {
        uint256 newLockPeriod = 1 days;
        uint256 toProjectId = 456;
        vm.startPrank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
        depositLock.updateLockPeriod(address(mockVault), toProjectId, newLockPeriod);
        vm.stopPrank();

        uint256 depositAmount = 500 ether;
        uint256 migrateAmount = 600 ether; // Requesting more than available.

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughShares.selector, migrateAmount, depositAmount));
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);
    }

    function test_migrateLocked_destinationLockNotSet() public {
        uint256 newLockPeriod = 1 days;
        uint256 toProjectId = 456;
        // Only set the lock period for the source project.
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
        // Destination (toProjectId) is not set.

        uint256 depositAmount = 1000 ether;
        uint256 migrateAmount = 400 ether;

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.DepositLockNotSetForProject.selector, toProjectId));
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);
    }
}

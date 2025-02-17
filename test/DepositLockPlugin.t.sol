// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DepositLockPlugin} from "src/plugins/DepositLockPlugin.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

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
    // Existing tests (with fixed parameter order)
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
        vm.expectRevert(
            abi.encodeWithSelector(LibErrors.DepositLockNotSetForProject.selector, address(mockVault), projectId)
        );
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();
    }

    function test_depositLocked_success() public {
        uint256 newLockPeriod = 2 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        uint256 shares = depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // The shares returned should equal the deposit amount.
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
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Warp time past the lock period (add one extra second for strict '>' check).
        vm.warp(block.timestamp + newLockPeriod + 1);

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
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.warp(block.timestamp + 10); // Differentiate timestamps.
        // Second deposit.
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Warp time so that both deposits are matured.
        vm.warp(block.timestamp + newLockPeriod + 1);

        uint256 available = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(available, 2 * depositAmount);

        // Redeem a partial amount (1500 out of 2000 shares).
        vm.startPrank(user);
        uint256 redeemedAssets = depositLock.redeemLocked(address(mockVault), projectId, 1500 ether);
        vm.stopPrank();
        assertEq(redeemedAssets, 1500 ether);

        // There should be 500 matured shares remaining.
        uint256 remaining = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(remaining, 500 ether);

        // Redeem the remaining shares.
        vm.startPrank(user);
        redeemedAssets = depositLock.redeemLocked(address(mockVault), projectId, 500 ether);
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
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Without time warp the deposit is not matured and redeem should revert.
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughShares.selector, 1000 ether, 0));
        depositLock.redeemLocked(address(mockVault), projectId, 1000 ether);
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
        depositLock.depositLocked(address(mockVault), projectId, 1000 ether);
        vm.stopPrank();

        // Warp time so that the first deposit is matured.
        vm.warp(block.timestamp + 130);

        // Make a second deposit that is still locked.
        vm.startPrank(user);
        underlying.approve(address(depositLock), 500 ether);
        depositLock.depositLocked(address(mockVault), projectId, 500 ether);
        vm.stopPrank();

        // Check maturity status for deposit indices 0 and 1.
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        bool[] memory statuses = depositLock.checkLocks(address(mockVault), projectId, user, indices);
        // The first deposit should be mature; the second should not.
        assertTrue(statuses[0]);
        assertFalse(statuses[1]);
    }

    // ------------------------------
    // New tests for migrateLocked
    // ------------------------------

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
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Warp time so that the deposit is matured.
        vm.warp(block.timestamp + newLockPeriod + 1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(LibErrors.DepositLockNotSetForProject.selector, address(mockVault), toProjectId)
        );
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);
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
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Warp time so that the deposit becomes matured.
        vm.warp(block.timestamp + newLockPeriod + 1);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughShares.selector, migrateAmount, depositAmount));
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);
    }

    function test_migrateLocked_success() public {
        uint256 newLockPeriod = 1 days;
        uint256 toProjectId = 2;
        // Set lock periods for both source and destination projects.
        vm.startPrank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
        depositLock.updateLockPeriod(address(mockVault), toProjectId, newLockPeriod);
        vm.stopPrank();

        uint256 depositAmount = 1000 ether;
        uint256 migrateAmount = 400 ether;

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        uint256 shares = depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        assertEq(shares, depositAmount);
        vm.stopPrank();

        // Warp time so that the deposit is matured.
        uint256 migratedTime = block.timestamp + newLockPeriod + 1;
        vm.warp(migratedTime);

        // Expect the MigrateLocked event to be emitted.
        vm.expectEmit(true, true, false, true);
        emit LibEvents.MigrateLocked(user, address(mockVault), projectId, toProjectId, migrateAmount);
        vm.prank(user);
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);

        // Check that the deposit in the source project has been reduced.
        (uint192 remainingShares,) = depositLock.lockedDeposits(address(mockVault), projectId, user, 0);
        assertEq(remainingShares, depositAmount - migrateAmount);

        // And a new deposit for the destination project should have been created.
        (uint192 migratedShares, uint64 lockTime) = depositLock.lockedDeposits(address(mockVault), toProjectId, user, 0);
        assertEq(migratedShares, migrateAmount);
        // Verify that lockTime is set to the current block timestamp (i.e. migratedTime).
        assertEq(lockTime, migratedTime);
    }

    // ------------------------------
    // Additional tests for events
    // ------------------------------

    function test_DepositLocked_event_emitted() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 500 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.DepositLocked(user, address(mockVault), projectId, depositAmount, depositAmount);
        uint256 shares = depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        assertEq(shares, depositAmount);
        vm.stopPrank();
    }

    function test_RedeemLocked_event_emitted() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 500 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        // Warp time so the deposit matures.
        vm.warp(block.timestamp + newLockPeriod + 1);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.RedeemLocked(user, address(mockVault), projectId, depositAmount, depositAmount);
        uint256 redeemed = depositLock.redeemLocked(address(mockVault), projectId, depositAmount);
        assertEq(redeemed, depositAmount);
        vm.stopPrank();
    }

    // Test with multiple deposits having mixed maturity times.
    function test_getMaturedShares_mixed_deposits() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount1 = 400 ether;
        uint256 depositAmount2 = 600 ether;

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount1 + depositAmount2);
        // First deposit.
        depositLock.depositLocked(address(mockVault), projectId, depositAmount1);
        // Warp so the first deposit matures.
        vm.warp(block.timestamp + newLockPeriod + 1);
        // Second deposit (timestamp is now later so it will not be matured yet).
        depositLock.depositLocked(address(mockVault), projectId, depositAmount2);
        vm.stopPrank();

        // Only the first deposit should be counted as matured.
        uint256 matured = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(matured, depositAmount1);
    }

    // New tests for projectGlobalUnlockTime feature in DepositLockPlugin

    function test_updateGlobalUnlockTime_nonOwnerReverts() public {
        // Attempt to update the global unlock time from a non-project owner
        uint256 newGlobalUnlockTime = block.timestamp + 1 days;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotProjectOwner.selector, projectId, user));
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, newGlobalUnlockTime);
    }

    function test_getMaturedShares_withGlobalUnlock() public {
        // Set up a normal lock period and then override using global unlock time.
        uint256 lockPeriod = 1 days;
        uint256 globalUnlockTime = block.timestamp + 1 days;
        uint256 depositAmount = 1000 ether;

        // Set the lock period (required for depositLocked to work)
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, lockPeriod);

        // Set the global unlock time as project owner.
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        // User makes a deposit.
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Before the global unlock time is reached, no shares should be mature.
        uint256 maturedBefore = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(maturedBefore, 0);

        // Warp time past the global unlock time.
        vm.warp(globalUnlockTime + 1);

        // Now all deposited shares should be mature.
        uint256 maturedAfter = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(maturedAfter, depositAmount);
    }

    function test_redeemLocked_withGlobalUnlock() public {
        // Set a lock period and a global unlock time.
        uint256 lockPeriod = 1 days;
        uint256 globalUnlockTime = block.timestamp + 1 days;
        uint256 depositAmount = 1000 ether;

        // Set the lock period and then the global unlock time.
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, lockPeriod);
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        // User makes a deposit.
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Attempt to redeem the shares before the global unlock time should revert.
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.GlobalUnlockTimeNotReached.selector, globalUnlockTime));
        depositLock.redeemLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Warp time past the global unlock time.
        vm.warp(globalUnlockTime + 1);

        // Now, redemption should succeed.
        vm.startPrank(user);
        uint256 redeemedAssets = depositLock.redeemLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Check that the redeemed assets match the deposited amount.
        assertEq(redeemedAssets, depositAmount);
    }
}

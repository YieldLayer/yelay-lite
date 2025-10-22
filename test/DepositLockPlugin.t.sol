// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {DepositLockPlugin} from "src/plugins/DepositLockPlugin.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

// -----------------------------------------------------------------------------
// A new implementation contract for upgrade testing.
// This contract inherits from DepositLockPlugin and adds an extra function.
// -----------------------------------------------------------------------------
contract DepositLockPluginV2 is DepositLockPlugin {
    function version() external pure returns (uint256) {
        return 2;
    }
}

// -----------------------------------------------------------------------------
// Test contract for DepositLockPlugin
// This includes all tests from both the variable and global lock modes,
// plus tests for upgrading the proxy (triggering _authorizeUpgrade).
// -----------------------------------------------------------------------------
contract DepositLockPluginTest is Test {
    DepositLockPlugin public depositLock;
    IYelayLiteVault public mockVault;
    MockToken public underlying;
    address public projectOwner = address(0x1111);
    address public user = address(0x2222);
    uint256 public projectId = 123;
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

    // -------------------------------------------------------------------------
    // Upgrade tests
    // -------------------------------------------------------------------------
    function test_upgrade_success() public {
        // Deploy a new implementation contract (V2).
        DepositLockPluginV2 newImpl = new DepositLockPluginV2();
        vm.prank(projectOwner);
        UUPSUpgradeable(depositLock).upgradeToAndCall(address(newImpl), new bytes(0));

        // After upgrade, call the new "version" function (added in V2) to verify.
        uint256 ver = DepositLockPluginV2(address(depositLock)).version();
        assertEq(ver, 2);
    }

    function test_upgrade_fail() public {
        DepositLockPluginV2 newImpl = new DepositLockPluginV2();
        vm.prank(user); // Not the owner
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        UUPSUpgradeable(depositLock).upgradeToAndCall(address(newImpl), new bytes(0));
    }

    // -------------------------------------------------------------------------
    // Variable mode tests
    // -------------------------------------------------------------------------
    function test_updateLockPeriod_nonOwnerReverts() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotProjectOwner.selector, address(mockVault), projectId, user));
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
    }

    function test_updateLockPeriod_exceedsMaximum() public {
        uint256 excessiveLock = depositLock.MAX_LOCK_PERIOD() + 1;
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.LockPeriodExceedsMaximum.selector, excessiveLock));
        depositLock.updateLockPeriod(address(mockVault), projectId, excessiveLock);
    }

    function test_updateLockPeriod_ProjectInactive() public {
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectInactive.selector));
        depositLock.updateLockPeriod(address(mockVault), projectId + 100, 1 days);
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
            abi.encodeWithSelector(LibErrors.LockModeNotSetForProject.selector, address(mockVault), projectId)
        );
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();
    }

    function test_depositLocked_revertsIfGlobalUnlockTimeReached() public {
        uint256 globalUnlockTime = block.timestamp + 1 days;
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        vm.warp(globalUnlockTime);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.GlobalUnlockTimeReached.selector, globalUnlockTime));
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();
    }

    function test_depositLocked_success() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        uint256 shares = depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        // Shares received should equal the deposit amount.
        assertEq(shares, depositAmount);
        // Immediately after deposit, matured shares remain zero.
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

        vm.warp(block.timestamp + newLockPeriod + 1);

        uint256 matured = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(matured, depositAmount);
    }

    function test_redeemLocked_success_partialAndFull() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount * 2);
        // Two deposits.
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.warp(block.timestamp + 10);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + newLockPeriod + 1);
        uint256 available = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(available, 2 * depositAmount);

        vm.startPrank(user);
        uint256 redeemedAssets = depositLock.redeemLocked(address(mockVault), projectId, 1500 ether);
        vm.stopPrank();
        assertEq(redeemedAssets, 1500 ether);

        uint256 remaining = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(remaining, 500 ether);

        vm.startPrank(user);
        redeemedAssets = depositLock.redeemLocked(address(mockVault), projectId, 500 ether);
        vm.stopPrank();
        assertEq(redeemedAssets, 500 ether);

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

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughShares.selector, 1000 ether, 0));
        depositLock.redeemLocked(address(mockVault), projectId, 1000 ether);
        vm.stopPrank();
    }

    function test_checkLocks() public {
        uint256 newLockPeriod = 120; // seconds
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        vm.startPrank(user);
        underlying.approve(address(depositLock), 1000 ether);
        depositLock.depositLocked(address(mockVault), projectId, 1000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 130);

        vm.startPrank(user);
        underlying.approve(address(depositLock), 500 ether);
        depositLock.depositLocked(address(mockVault), projectId, 500 ether);
        vm.stopPrank();

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        bool[] memory statuses = depositLock.checkLocks(address(mockVault), projectId, user, indices);
        assertTrue(statuses[0]);
        assertFalse(statuses[1]);
    }

    function test_getLockedDeposits() public {
        uint256 newLockPeriod = 120; // seconds
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 firstLockTime = block.timestamp;
        vm.startPrank(user);
        underlying.approve(address(depositLock), 1000 ether);
        depositLock.depositLocked(address(mockVault), projectId, 1000 ether);
        vm.stopPrank();

        {
            DepositLockPlugin.Deposit[] memory deposits =
                depositLock.getLockedDeposits(address(mockVault), projectId, user);
            assertEq(deposits.length, 1);
            assertEq(deposits[0].shares, 1000 ether);
            assertEq(deposits[0].lockTime, firstLockTime);
        }

        vm.warp(block.timestamp + 130);

        uint256 secondLockTime = block.timestamp;
        vm.startPrank(user);
        underlying.approve(address(depositLock), 500 ether);
        depositLock.depositLocked(address(mockVault), projectId, 500 ether);
        vm.stopPrank();

        {
            DepositLockPlugin.Deposit[] memory deposits =
                depositLock.getLockedDeposits(address(mockVault), projectId, user);
            assertEq(deposits.length, 2);
            assertEq(deposits[0].shares, 1000 ether);
            assertEq(deposits[0].lockTime, firstLockTime);
            assertEq(deposits[1].shares, 500 ether);
            assertEq(deposits[1].lockTime, secondLockTime);
        }

        vm.startPrank(user);
        depositLock.redeemLocked(address(mockVault), projectId, 500 ether);
        vm.stopPrank();

        {
            DepositLockPlugin.Deposit[] memory deposits =
                depositLock.getLockedDeposits(address(mockVault), projectId, user);
            assertEq(deposits.length, 2);
            assertEq(deposits[0].shares, 500 ether);
            assertEq(deposits[0].lockTime, firstLockTime);
            assertEq(deposits[1].shares, 500 ether);
            assertEq(deposits[1].lockTime, secondLockTime);
        }

        vm.startPrank(user);
        depositLock.redeemLocked(address(mockVault), projectId, 500 ether);
        vm.stopPrank();

        {
            DepositLockPlugin.Deposit[] memory deposits =
                depositLock.getLockedDeposits(address(mockVault), projectId, user);
            assertEq(deposits.length, 1);
            assertEq(deposits[0].shares, 500 ether);
            assertEq(deposits[0].lockTime, secondLockTime);
        }

        vm.warp(block.timestamp + 130);

        vm.startPrank(user);
        depositLock.redeemLocked(address(mockVault), projectId, 500 ether);
        vm.stopPrank();

        {
            DepositLockPlugin.Deposit[] memory deposits =
                depositLock.getLockedDeposits(address(mockVault), projectId, user);
            assertEq(deposits.length, 0);
        }

        uint256 newProjectId = projectId + 7;
        vm.startPrank(projectOwner);
        mockVault.activateProject(newProjectId);
        vm.stopPrank();
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.LockModeMismatch.selector,
                address(mockVault),
                newProjectId,
                uint256(DepositLockPlugin.LockMode.Unset)
            )
        );
        depositLock.getLockedDeposits(address(mockVault), newProjectId, user);

        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), newProjectId, 123);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibErrors.LockModeMismatch.selector,
                address(mockVault),
                newProjectId,
                uint256(DepositLockPlugin.LockMode.Global)
            )
        );
        depositLock.getLockedDeposits(address(mockVault), newProjectId, user);
    }

    function test_migrateLocked_destinationLockNotSet() public {
        uint256 newLockPeriod = 1 days;
        uint256 toProjectId = 456;
        // Only set the lock period for the source project.
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
        uint256 depositAmount = 1000 ether;
        uint256 migrateAmount = 400 ether;

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + newLockPeriod + 1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(LibErrors.LockModeNotSetForProject.selector, address(mockVault), toProjectId)
        );
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);
    }

    function test_migrateLocked_insufficientShares() public {
        uint256 newLockPeriod = 1 days;
        uint256 toProjectId = 456;
        vm.startPrank(projectOwner);
        mockVault.activateProject(toProjectId);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
        depositLock.updateLockPeriod(address(mockVault), toProjectId, newLockPeriod);
        vm.stopPrank();

        uint256 depositAmount = 500 ether;
        uint256 migrateAmount = 600 ether; // Trying to migrate more than available.

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + newLockPeriod + 1);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughShares.selector, migrateAmount, depositAmount));
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);
    }

    function test_migrateLocked_revertsIfGlobalUnlockTimeReached() public {
        uint256 newLockPeriod = 1 days;
        uint256 globalLockPeriod = block.timestamp + newLockPeriod;
        uint256 toProjectId = 456;
        vm.startPrank(projectOwner);
        mockVault.activateProject(toProjectId);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
        depositLock.updateGlobalUnlockTime(address(mockVault), toProjectId, globalLockPeriod);
        vm.stopPrank();

        uint256 depositAmount = 500 ether;

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        vm.warp(globalLockPeriod);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.GlobalUnlockTimeReached.selector, globalLockPeriod));
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, depositAmount);
    }

    function test_migrateLocked_success() public {
        uint256 newLockPeriod = 1 days;
        uint256 toProjectId = 2;
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

        uint256 migratedTime = block.timestamp + newLockPeriod + 1;
        vm.warp(migratedTime);

        vm.expectEmit(true, true, false, true);
        emit LibEvents.MigrateLocked(user, address(mockVault), projectId, toProjectId, migrateAmount);
        vm.prank(user);
        depositLock.migrateLocked(address(mockVault), projectId, toProjectId, migrateAmount);

        (uint192 remainingShares,) = depositLock.lockedDeposits(address(mockVault), projectId, user, 0);
        assertEq(remainingShares, depositAmount - migrateAmount);

        (uint192 migratedShares, uint64 lockTime) = depositLock.lockedDeposits(address(mockVault), toProjectId, user, 0);
        assertEq(migratedShares, migrateAmount);
        assertEq(lockTime, migratedTime);
    }

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
        vm.warp(block.timestamp + newLockPeriod + 1);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.RedeemLocked(user, address(mockVault), projectId, depositAmount, depositAmount);
        uint256 redeemed = depositLock.redeemLocked(address(mockVault), projectId, depositAmount);
        assertEq(redeemed, depositAmount);
        vm.stopPrank();
    }

    function test_getMaturedShares_mixed_deposits() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        uint256 depositAmount1 = 400 ether;
        uint256 depositAmount2 = 600 ether;

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount1 + depositAmount2);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount1);
        vm.warp(block.timestamp + newLockPeriod + 1);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount2);
        vm.stopPrank();

        uint256 matured = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(matured, depositAmount1);
    }

    // -------------------------------------------------------------------------
    // Global mode tests
    // -------------------------------------------------------------------------

    function test_updateGlobalUnlockTime_ProjectInactive() public {
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProjectInactive.selector));
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId + 100, 1 days);
    }

    function test_updateGlobalUnlockTime_success() public {
        uint256 newGlobalUnlockTime = block.timestamp + 1 days;
        vm.prank(projectOwner);
        vm.expectEmit(true, true, false, true);
        emit LibEvents.GlobalUnlockTimeUpdated(address(mockVault), projectId, newGlobalUnlockTime);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, newGlobalUnlockTime);
        uint256 storedUnlockTime = depositLock.projectGlobalUnlockTime(address(mockVault), projectId);
        assertEq(storedUnlockTime, newGlobalUnlockTime);
    }

    function test_getMaturedShares_global_mode() public {
        uint256 globalUnlockTime = block.timestamp + 1 days;
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(LibErrors.LockModeNotSetForProject.selector, address(mockVault), projectId + 1)
        );
        depositLock.getMaturedShares(address(mockVault), projectId + 1, user);

        uint256 maturedBefore = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(maturedBefore, 0);

        vm.warp(globalUnlockTime + 1);
        uint256 maturedAfter = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(maturedAfter, depositAmount);
    }

    function test_redeemLocked_global_mode_success() public {
        uint256 globalUnlockTime = block.timestamp + 1 days;
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount * 2);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.warp(block.timestamp + 10);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        vm.warp(globalUnlockTime + 1);
        uint256 available = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(available, 2 * depositAmount);

        vm.startPrank(user);
        uint256 redeemedAssets = depositLock.redeemLocked(address(mockVault), projectId, 1500 ether);
        vm.stopPrank();
        assertEq(redeemedAssets, 1500 ether);

        uint256 remaining = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(remaining, 500 ether);

        vm.startPrank(user);
        redeemedAssets = depositLock.redeemLocked(address(mockVault), projectId, 500 ether);
        vm.stopPrank();
        assertEq(redeemedAssets, 500 ether);

        remaining = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(remaining, 0);
    }

    function test_redeemLocked_global_mode_revert_when_not_matured() public {
        uint256 globalUnlockTime = block.timestamp + 1 days;
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.GlobalUnlockTimeNotReached.selector, globalUnlockTime));
        depositLock.redeemLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();
    }

    function test_redeemLocked_global_mode_insufficientShares() public {
        uint256 globalUnlockTime = block.timestamp + 1 days;
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        uint256 depositAmount = 500 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), projectId, depositAmount);
        vm.stopPrank();

        vm.warp(globalUnlockTime + 1);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughShares.selector, 600 ether, 500 ether));
        depositLock.redeemLocked(address(mockVault), projectId, 600 ether);
        vm.stopPrank();
    }

    function test_removeShares_revert_across_deposits() public {
        uint256 globalUnlockTime = block.timestamp + 1 days;
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        uint256 deposit1 = 400 ether;
        uint256 deposit2 = 600 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), deposit1 + deposit2);
        depositLock.depositLocked(address(mockVault), projectId, deposit1);
        depositLock.depositLocked(address(mockVault), projectId, deposit2);
        vm.stopPrank();

        vm.warp(globalUnlockTime + 1);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(LibErrors.LockModeNotSetForProject.selector, address(mockVault), projectId + 1)
        );
        depositLock.redeemLocked(address(mockVault), projectId + 1, 1100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughShares.selector, 1100 ether, 1000 ether));
        depositLock.redeemLocked(address(mockVault), projectId, 1100 ether);
        vm.stopPrank();
    }

    function test_updateLockPeriod_failure_after_global() public {
        uint256 globalUnlockTime = block.timestamp + 1 days;
        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime);

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.LockModeAlreadySet.selector, address(mockVault), projectId, 1));
        depositLock.updateLockPeriod(address(mockVault), projectId, 1 days);

        vm.prank(projectOwner);
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, globalUnlockTime + 1);
    }

    function test_setOrValidateLockMode_failure() public {
        uint256 lockPeriod = 1 days;
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, lockPeriod);

        uint256 newGlobalUnlockTime = block.timestamp + 2 days;
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.LockModeAlreadySet.selector, address(mockVault), projectId, 2));
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, newGlobalUnlockTime);
    }

    function test_updateGlobalUnlockTime_nonOwnerReverts() public {
        uint256 newGlobalUnlockTime = block.timestamp + 1 days;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotProjectOwner.selector, address(mockVault), projectId, user));
        depositLock.updateGlobalUnlockTime(address(mockVault), projectId, newGlobalUnlockTime);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "src/plugins/DepositLockPlugin.sol";
import "src/interfaces/IYelayLiteVault.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract DepositLockPluginTest is Test {
    DepositLockPlugin depositLock;
    IYelayLiteVault mockVault;
    MockToken underlying;
    // Use arbitrary addresses for the project owner and user.
    address projectOwner = address(0x1111);
    address user = address(0x2222);
    // Use an arbitrary project ID.
    uint256 projectId = 123;

    address constant yieldExtractor = address(0x02);
    string constant uri = "https://yelay-lite-vault/{id}.json";

    function setUp() public {
        // Deploy the underlying asset (a mock ERC20) and fund the user.
        underlying = new MockToken("Underlying", "UND", 18);
        deal(address(underlying), user, 10000 ether);

        // Deploy the vault (diamond) with projectOwner as the project/client owner.
        vm.startPrank(projectOwner);
        mockVault = Utils.deployDiamond(projectOwner, address(underlying), yieldExtractor, uri);
        mockVault.activateProject(projectId);
        vm.stopPrank();

        // Deploy the DepositLockPlugin.
        depositLock = new DepositLockPlugin();
    }

    function test_updateLockPeriod_nonOwnerReverts() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotProjectOwner.selector, projectId, user));
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);
    }

    function test_updateLockPeriod_exceedsMaximum() public {
        uint256 excessiveLock = depositLock.MAX_LOCK_PERIOD() + 1;
        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSelector(LockPeriodExceedsMaximum.selector, excessiveLock));
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
        vm.expectRevert(abi.encodeWithSelector(DepositLockNotSetForProject.selector, projectId));
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

        // The shares returned from depositLocked equal the depositAmount.
        assertEq(shares, depositAmount);

        // Since the deposit was recorded with the current block timestamp and the lock period has not elapsed,
        // the available (matured) shares should be 0.
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
        // Make two deposits from the same user.
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount * 2);
        // First deposit.
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        // Advance a little to differentiate timestamps.
        vm.warp(block.timestamp + 10);
        // Second deposit.
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        // Warp time such that both deposits are matured.
        vm.warp(block.timestamp + 1 days);

        uint256 available = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(available, 2 * depositAmount);

        // Redeem a partial amount (1500 shares out of 2000).
        vm.startPrank(user);
        uint256 redeemedAssets = depositLock.redeemLocked(address(mockVault), 1500 ether, projectId);
        vm.stopPrank();
        assertEq(redeemedAssets, 1500 ether);

        // There should now be 500 matured shares remaining.
        uint256 remaining = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(remaining, 500 ether);

        // Redeem the remaining 500 shares.
        vm.startPrank(user);
        redeemedAssets = depositLock.redeemLocked(address(mockVault), 500 ether, projectId);
        vm.stopPrank();
        assertEq(redeemedAssets, 500 ether);

        // Now, there should be no redeemable shares left.
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

        // Without advancing time, the deposit is not matured.
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(NotEnoughMaturedShares.selector, 1000 ether, 0));
        depositLock.redeemLocked(address(mockVault), 1000 ether, projectId);
        vm.stopPrank();
    }

    function test_checkLocks() public {
        // Use a short lock period for clarity.
        uint256 newLockPeriod = 120; // 120 seconds
        vm.prank(projectOwner);
        depositLock.updateLockPeriod(address(mockVault), projectId, newLockPeriod);

        // Deposit a record.
        vm.startPrank(user);
        underlying.approve(address(depositLock), 1000 ether);
        depositLock.depositLocked(address(mockVault), 1000 ether, projectId);
        vm.stopPrank();

        // Warp time so that the first deposit is matured.
        vm.warp(block.timestamp + 130);

        // Make a second deposit that is not matured.
        vm.startPrank(user);
        underlying.approve(address(depositLock), 500 ether);
        depositLock.depositLocked(address(mockVault), 500 ether, projectId);
        vm.stopPrank();

        // Check the maturity status for deposit indices 0 and 1.
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        bool[] memory statuses = depositLock.checkLocks(address(mockVault), projectId, user, indices);
        // The first deposit should be matured; the second should not.
        assertTrue(statuses[0]);
        assertFalse(statuses[1]);
    }
}

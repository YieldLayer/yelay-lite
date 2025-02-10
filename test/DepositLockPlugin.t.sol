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
    // Use arbitrary addresses for vault owner and user.
    address vaultOwner = address(0x1111);
    address user = address(0x2222);
    // Use an arbitrary project ID.
    uint256 projectId = 123;

    address constant yieldExtractor = address(0x02);
    string constant uri = "https://yelay-lite-vault/{id}.json";

    function setUp() public {
        // Deploy the underlying asset (a mock ERC20) and fund the user.
        underlying = new MockToken("Underlying", "UND", 18);
        // Use forge-std's deal to set the underlying token balance;
        // (forge-std supports ERC20 balance manipulation for testing).
        deal(address(underlying), user, 10000 ether);

        // Deploy our IYelayLiteVault with vaultOwner as the owner and the mock underlying asset.
        vm.startPrank(vaultOwner);
        mockVault = Utils.deployDiamond(vaultOwner, address(underlying), yieldExtractor, uri);
        mockVault.activateProject(123);
        vm.stopPrank();

        // Deploy the DepositLockPlugin.
        depositLock = new DepositLockPlugin();
    }

    function test_updateLockPeriod_nonOwnerReverts() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotVaultOwner.selector, address(mockVault), user));
        depositLock.updateLockPeriod(address(mockVault), newLockPeriod);
    }

    function test_updateLockPeriod_exceedsMaximum() public {
        uint256 excessiveLock = depositLock.MAX_LOCK_PERIOD() + 1;
        vm.prank(vaultOwner);
        vm.expectRevert(abi.encodeWithSelector(LockPeriodExceedsMaximum.selector, excessiveLock));
        depositLock.updateLockPeriod(address(mockVault), excessiveLock);
    }

    function test_updateLockPeriod_success() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(vaultOwner);
        depositLock.updateLockPeriod(address(mockVault), newLockPeriod);
        uint256 storedLock = depositLock.vaultLockPeriods(address(mockVault));
        assertEq(storedLock, newLockPeriod);
    }

    function test_depositLocked_revertsIfLockNotSet() public {
        uint256 depositAmount = 1000 ether;

        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        vm.expectRevert(abi.encodeWithSelector(DepositLockNotSetForVault.selector, address(mockVault)));
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();
    }

    function test_depositLocked_success() public {
        uint256 newLockPeriod = 2 days;
        vm.prank(vaultOwner);
        depositLock.updateLockPeriod(address(mockVault), newLockPeriod);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        uint256 shares = depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        // The shares returned from depositLocked equal the depositAmount (IYelayLiteVault returns assets as shares).
        assertEq(shares, depositAmount);

        // Since the deposit was recorded with the current block timestamp and the lock period has not elapsed,
        // the available redeemable (matured) shares should be 0.
        uint256 matured = depositLock.getMaturedShares(address(mockVault), projectId, user);
        assertEq(matured, 0);
    }

    function test_getMaturedShares_afterMaturity() public {
        uint256 newLockPeriod = 1 days;
        vm.prank(vaultOwner);
        depositLock.updateLockPeriod(address(mockVault), newLockPeriod);

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
        vm.prank(vaultOwner);
        depositLock.updateLockPeriod(address(mockVault), newLockPeriod);

        uint256 depositAmount = 1000 ether;
        // Make two deposits from the same user.
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount * 2);
        // First deposit.
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        // Advance a little bit so that the second deposit has a slightly later timestamp.
        vm.warp(block.timestamp + 10);
        // Second deposit.
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        // Warp time far enough so that both deposits are matured.
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
        vm.prank(vaultOwner);
        depositLock.updateLockPeriod(address(mockVault), newLockPeriod);

        uint256 depositAmount = 1000 ether;
        vm.startPrank(user);
        underlying.approve(address(depositLock), depositAmount);
        depositLock.depositLocked(address(mockVault), depositAmount, projectId);
        vm.stopPrank();

        // Without warping forward, the deposit is not matured.
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(NotEnoughMaturedShares.selector, 1000 ether, 0));
        depositLock.redeemLocked(address(mockVault), 1000 ether, projectId);
        vm.stopPrank();
    }

    function test_checkLocks() public {
        // Use a small lock period for clarity.
        uint256 newLockPeriod = 120; // 120 seconds
        vm.prank(vaultOwner);
        depositLock.updateLockPeriod(address(mockVault), newLockPeriod);

        // Deposit a first record.
        vm.startPrank(user);
        underlying.approve(address(depositLock), 1000 ether);
        depositLock.depositLocked(address(mockVault), 1000 ether, projectId);
        vm.stopPrank();

        // Warp time such that the first deposit is matured.
        vm.warp(block.timestamp + 130);

        // Now make a second deposit which should not be matured.
        vm.startPrank(user);
        underlying.approve(address(depositLock), 500 ether);
        depositLock.depositLocked(address(mockVault), 500 ether, projectId);
        vm.stopPrank();

        // Check the lock statuses of deposit indices 0 and 1.
        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 1;
        bool[] memory statuses = depositLock.checkLocks(address(mockVault), projectId, user, indices);
        // The first deposit should be matured; the second should not.
        assertTrue(statuses[0]);
        assertFalse(statuses[1]);
    }
}

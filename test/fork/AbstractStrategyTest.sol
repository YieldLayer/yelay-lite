// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

import {LibRoles} from "src/libraries/LibRoles.sol";

import {Utils} from "../Utils.sol";
import {DAI_ADDRESS, MAINNET_BLOCK_NUMBER} from "../Constants.sol";

abstract contract AbstractStrategyTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant user = address(0x02);
    address constant user2 = address(0x03);
    address constant yieldExtractor = address(0x04);
    uint256 constant yieldProjectId = 0;
    uint256 constant projectId = 1;

    IYelayLiteVault yelayLiteVault;

    IERC20 underlyingAsset = IERC20(DAI_ADDRESS);

    // Override this to test particular strategy
    function _setupStrategy() internal virtual {}

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_URL"), MAINNET_BLOCK_NUMBER);

        vm.startPrank(owner);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        yelayLiteVault.grantRole(LibRoles.QUEUES_OPERATOR, owner);
        yelayLiteVault.grantRole(LibRoles.STRATEGY_AUTHORITY, owner);
        yelayLiteVault.grantRole(LibRoles.STRATEGY_OPERATOR, owner);
        yelayLiteVault.grantRole(LibRoles.FUNDS_OPERATOR, owner);
        vm.stopPrank();

        vm.startPrank(user);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user2);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.stopPrank();

        _setupStrategy();
    }

    function test_deposit_with_strategy() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        assertEq(underlyingAsset.balanceOf(user), userBalance);
        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), 0);
        assertEq(yelayLiteVault.totalAssets(), 0);
        assertEq(yelayLiteVault.totalSupply(), 0);
        assertEq(yelayLiteVault.balanceOf(user, projectId), 0);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance - toDeposit);
        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), 0);
        assertApproxEqAbs(yelayLiteVault.totalAssets(), toDeposit, 1);
        assertEq(yelayLiteVault.totalSupply(), toDeposit);
        assertEq(yelayLiteVault.balanceOf(user, projectId), toDeposit);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(0), toDeposit, 1);
    }

    function test_withdraw_with_strategy() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        yelayLiteVault.redeem(toDeposit, projectId, user);
        vm.stopPrank();

        assertApproxEqAbs(underlyingAsset.balanceOf(user), userBalance, 1);
        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), 0);
        assertEq(yelayLiteVault.totalSupply(), 0);
        assertEq(yelayLiteVault.balanceOf(user, projectId), 0);
    }

    function test_yield_extraction() external {
        uint256 toDeposit = 1_000e18;
        // uint256 yieldExtractorShareBalance;

        for (uint256 i = 1; i < 20; i++) {
            address user3 = address(bytes20(bytes32(111111111111111111111111111111111111111111 * i)));
            deal(address(underlyingAsset), user3, toDeposit);
            vm.startPrank(user3);
            underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
            yelayLiteVault.deposit(toDeposit, i, user3);
            vm.stopPrank();
            assertEq(underlyingAsset.balanceOf(user3), 0);
            if (i + 1 < 20) {
                vm.warp(block.timestamp + 6 hours);
            }
            // uint256 newYieldExtractorShareBalance = yelayLiteVault.balanceOf(yieldExtractor, yieldProjectId);
            // if (newYieldExtractorShareBalance > 0) {
            //     assertGt(newYieldExtractorShareBalance, yieldExtractorShareBalance);
            // }
            // yieldExtractorShareBalance = newYieldExtractorShareBalance;
        }

        vm.startPrank(owner);
        yelayLiteVault.accrueFee();
        vm.stopPrank();

        uint256 yieldExtractorShareBalance = yelayLiteVault.balanceOf(yieldExtractor, yieldProjectId);

        assertEq(underlyingAsset.balanceOf(yieldExtractor), 0);

        vm.startPrank(yieldExtractor);
        yelayLiteVault.redeem(yieldExtractorShareBalance, yieldProjectId, yieldExtractor);
        vm.stopPrank();

        assertGt(underlyingAsset.balanceOf(yieldExtractor), 0);
        assertApproxEqAbs(underlyingAsset.balanceOf(yieldExtractor), yieldExtractorShareBalance, 1);

        assertApproxEqAbs(yelayLiteVault.totalSupply(), yelayLiteVault.totalAssets(), 1);

        assertEq(yelayLiteVault.balanceOf(yieldExtractor, yieldProjectId), 0);

        for (uint256 i = 1; i < 20; i++) {
            address user3 = address(bytes20(bytes32(111111111111111111111111111111111111111111 * i)));
            vm.startPrank(user3);
            yelayLiteVault.redeem(yelayLiteVault.balanceOf(user3, i), i, user3);
            vm.stopPrank();
            assertApproxEqAbs(underlyingAsset.balanceOf(user3), toDeposit, 1);
            if (i + 1 < 20) {
                vm.warp(block.timestamp + 1 weeks);
            }
        }

        assertGt(yelayLiteVault.totalSupply(), 0);
        assertGt(yelayLiteVault.totalAssets(), 0);
        assertGt(yelayLiteVault.balanceOf(yieldExtractor, yieldProjectId), 0);

        {
            uint256 sharesBefore = yelayLiteVault.balanceOf(yieldExtractor, yieldProjectId);
            uint256 assetsBefore = underlyingAsset.balanceOf(yieldExtractor);
            vm.startPrank(yieldExtractor);
            yelayLiteVault.redeem(sharesBefore, yieldProjectId, yieldExtractor);
            vm.stopPrank();

            uint256 assetsAfter = underlyingAsset.balanceOf(yieldExtractor);

            assertApproxEqAbs(assetsAfter - assetsBefore, sharesBefore, 10);
        }

        assertApproxEqAbs(yelayLiteVault.totalSupply(), 0, 1);
        assertEq(yelayLiteVault.totalAssets(), 0);
        assertApproxEqAbs(yelayLiteVault.balanceOf(yieldExtractor, yieldProjectId), 0, 1);
    }

    function test_deposit_optional_totalAssetsUpdate() external {
        uint256 start = block.timestamp;
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        assertEq(yelayLiteVault.lastTotalAssetsTimestamp(), 0);

        vm.startPrank(owner);
        yelayLiteVault.setLastTotalAssetsUpdateInterval(100);
        vm.stopPrank();

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(yelayLiteVault.lastTotalAssetsTimestamp(), start);
        assertEq(yelayLiteVault.lastTotalAssets(), toDeposit);

        vm.warp(start + 50);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(yelayLiteVault.lastTotalAssetsTimestamp(), start);
        assertEq(yelayLiteVault.lastTotalAssets(), toDeposit * 2);

        vm.warp(start + 103);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertGt(yelayLiteVault.lastTotalAssets(), toDeposit * 3);
        assertEq(yelayLiteVault.lastTotalAssetsTimestamp(), start + 103);
    }
}

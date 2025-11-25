// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {StrategyArgs} from "src/interfaces/IFundsFacet.sol";

import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

import {Utils} from "../Utils.sol";

import {MorphoBlueStrategy} from "src/strategies/MorphoBlueStrategy.sol";
import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {DAI_ADDRESS, MAINNET_BLOCK_NUMBER, MORPHO_BLUE, MORPHO_BLUE_DAI_ID, AAVE_V3_POOL} from "../Constants.sol";

contract TwoStrategiesTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant user = address(0x02);
    address constant user2 = address(0x03);
    address constant yieldExtractor = address(0x04);
    uint256 constant yieldProjectId = 0;
    uint256 constant projectId = 1;

    IYelayLiteVault yelayLiteVault;

    IERC20 underlyingAsset = IERC20(DAI_ADDRESS);

    function _setupStrategy() internal {
        vm.startPrank(owner);
        {
            StrategyData memory strategy = StrategyData({
                adapter: address(new AaveV3Strategy(AAVE_V3_POOL)),
                supplement: abi.encode(
                    address(underlyingAsset), IPool(AAVE_V3_POOL).getReserveData(address(underlyingAsset)).aTokenAddress
                ),
                name: "aave"
            });
            yelayLiteVault.addStrategy(strategy);
            yelayLiteVault.approveStrategy(0, type(uint256).max);
        }
        {
            StrategyData memory strategy = StrategyData({
                adapter: address(new MorphoBlueStrategy(MORPHO_BLUE)),
                supplement: abi.encode(MORPHO_BLUE_DAI_ID),
                name: "morpho"
            });

            yelayLiteVault.addStrategy(strategy);
            yelayLiteVault.approveStrategy(1, type(uint256).max);
        }
        {
            uint256[] memory queue = new uint256[](2);
            queue[0] = 0;
            queue[1] = 1;
            yelayLiteVault.activateStrategy(0, queue, queue);
            yelayLiteVault.activateStrategy(1, queue, queue);
        }
        vm.stopPrank();
    }

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_URL"), MAINNET_BLOCK_NUMBER);

        vm.startPrank(owner);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
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

    function test_managed_deposit() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        _setupStrategy();

        {
            vm.startPrank(owner);
            StrategyArgs memory strategyArgs = StrategyArgs({index: 0, amount: toDeposit / 2});
            yelayLiteVault.managedDeposit(strategyArgs);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), toDeposit / 2);
        assertApproxEqAbs(yelayLiteVault.totalAssets(), toDeposit, 1);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(1), 0, 2);

        {
            vm.startPrank(owner);
            StrategyArgs memory strategyArgs = StrategyArgs({index: 1, amount: toDeposit / 4});
            yelayLiteVault.managedDeposit(strategyArgs);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), toDeposit / 4);
        assertApproxEqAbs(yelayLiteVault.totalAssets(), toDeposit, 1);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(1), toDeposit / 4, 2);
    }

    function test_managed_withdraw() external {
        _setupStrategy();

        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        {
            // swap deposit queue
            vm.startPrank(owner);
            uint256[] memory queue = new uint256[](2);
            queue[0] = 1;
            queue[1] = 0;
            yelayLiteVault.updateDepositQueue(queue);
            yelayLiteVault.updateWithdrawQueue(queue);
            vm.stopPrank();
        }

        // deposit second time in another strategy
        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertApproxEqAbs(yelayLiteVault.strategyAssets(0), toDeposit, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(1), toDeposit, 2);

        {
            vm.startPrank(owner);
            StrategyArgs memory strategyArgs = StrategyArgs({index: 0, amount: toDeposit / 2});
            yelayLiteVault.managedWithdraw(strategyArgs);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), toDeposit / 2);
        assertApproxEqAbs(yelayLiteVault.totalAssets(), toDeposit * 2, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(1), toDeposit, 2);

        {
            vm.startPrank(owner);
            StrategyArgs memory strategyArgs = StrategyArgs({index: 1, amount: toDeposit / 4});
            yelayLiteVault.managedWithdraw(strategyArgs);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), 3 * toDeposit / 4);
        assertApproxEqAbs(yelayLiteVault.totalAssets(), 2 * toDeposit, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(1), 3 * toDeposit / 4, 2);
    }

    function test_reallocation() external {
        _setupStrategy();

        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), 0);
        assertApproxEqAbs(yelayLiteVault.totalAssets(), toDeposit, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(0), toDeposit, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(1), 0, 2);

        {
            vm.startPrank(owner);
            StrategyArgs[] memory withdrawals = new StrategyArgs[](1);
            StrategyArgs[] memory deposits = new StrategyArgs[](1);
            withdrawals[0] = StrategyArgs({index: 0, amount: toDeposit / 2});
            deposits[0] = StrategyArgs({index: 1, amount: toDeposit / 2});
            yelayLiteVault.reallocate(withdrawals, deposits);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(address(yelayLiteVault)), 0);
        assertApproxEqAbs(yelayLiteVault.totalAssets(), toDeposit, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(yelayLiteVault.strategyAssets(1), toDeposit / 2, 2);
    }

    function test_accrue_fee() external {
        _setupStrategy();

        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        assertEq(yelayLiteVault.balanceOf(yieldExtractor, yieldProjectId), 0);

        vm.startPrank(owner);
        yelayLiteVault.accrueFee();
        vm.stopPrank();

        assertGt(yelayLiteVault.balanceOf(yieldExtractor, yieldProjectId), 0);
    }

    function test_partial_withdrawal_success() external {
        _setupStrategy();

        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);
        deal(address(underlyingAsset), user2, toDeposit);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();
        vm.startPrank(user2);
        yelayLiteVault.deposit(toDeposit, projectId, user2);
        vm.stopPrank();

        {
            vm.startPrank(owner);
            StrategyArgs[] memory withdrawals = new StrategyArgs[](1);
            StrategyArgs[] memory deposits = new StrategyArgs[](1);
            withdrawals[0] = StrategyArgs({index: 0, amount: toDeposit * 6 / 4});
            deposits[0] = StrategyArgs({index: 1, amount: toDeposit / 4});
            yelayLiteVault.reallocate(withdrawals, deposits);
            uint256[] memory queue = new uint256[](1);
            queue[0] = 1;
            yelayLiteVault.updateWithdrawQueue(queue);
            vm.stopPrank();
        }

        vm.startPrank(user);
        yelayLiteVault.redeem(toDeposit, projectId, user);
        vm.stopPrank();

        assertApproxEqAbs(underlyingAsset.balanceOf(user), toDeposit, 2);
    }

    function test_partial_withdrawal_failure() external {
        _setupStrategy();

        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, toDeposit);
        deal(address(underlyingAsset), user2, toDeposit);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();
        vm.startPrank(user2);
        yelayLiteVault.deposit(toDeposit, projectId, user2);
        vm.stopPrank();

        {
            vm.startPrank(owner);
            StrategyArgs[] memory withdrawals = new StrategyArgs[](1);
            StrategyArgs[] memory deposits = new StrategyArgs[](1);
            withdrawals[0] = StrategyArgs({index: 0, amount: toDeposit * 6 / 4});
            deposits[0] = StrategyArgs({index: 1, amount: toDeposit * 6 / 4});
            yelayLiteVault.reallocate(withdrawals, deposits);
            uint256[] memory queue = new uint256[](1);
            queue[0] = 0;
            yelayLiteVault.updateWithdrawQueue(queue);
            vm.stopPrank();
        }

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.NotEnoughInternalFunds.selector));
        yelayLiteVault.redeem(toDeposit, projectId, user);
        vm.stopPrank();
    }
}

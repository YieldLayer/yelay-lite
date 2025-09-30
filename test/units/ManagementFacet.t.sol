// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

import {MockStrategy} from "test/mocks/MockStrategy.sol";
import {MockToken} from "test/mocks/MockToken.sol";
import {Utils} from "test/Utils.sol";

contract ManagementFacetTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant mockProtocol1 = address(0x02);
    address constant mockProtocol2 = address(0x03);
    address constant mockProtocol3 = address(0x04);
    address constant yieldExtractor = address(0x05);

    IYelayLiteVault yelayLiteVault;

    MockToken underlyingAsset;

    MockStrategy mockStrategy1;
    MockStrategy mockStrategy2;
    MockStrategy mockStrategy3;

    function setUp() external {
        mockStrategy1 = new MockStrategy(mockProtocol1);
        mockStrategy2 = new MockStrategy(mockProtocol2);
        mockStrategy3 = new MockStrategy(mockProtocol3);

        vm.startPrank(owner);
        underlyingAsset = new MockToken("Y-Test", "Y-T", 18);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        yelayLiteVault.grantRole(LibRoles.QUEUES_OPERATOR, owner);
        yelayLiteVault.grantRole(LibRoles.STRATEGY_AUTHORITY, owner);
        vm.stopPrank();
    }

    function test_managing_strategies() external {
        assertEq(yelayLiteVault.getStrategies().length, 0);
        vm.startPrank(owner);
        StrategyData memory strategy1 =
            StrategyData({adapter: address(mockStrategy1), name: "mockStrategy1", supplement: ""});
        StrategyData memory strategy2 =
            StrategyData({adapter: address(mockStrategy2), name: "mockStrategy2", supplement: hex"1234"});
        StrategyData memory strategy3 =
            StrategyData({adapter: address(mockStrategy3), name: "mockStrategy3", supplement: hex"5678"});
        assertEq(underlyingAsset.allowance(address(yelayLiteVault), mockStrategy1.protocol(strategy1.supplement)), 0);
        assertEq(underlyingAsset.allowance(address(yelayLiteVault), mockStrategy2.protocol(strategy2.supplement)), 0);
        assertEq(underlyingAsset.allowance(address(yelayLiteVault), mockStrategy3.protocol(strategy3.supplement)), 0);
        {
            yelayLiteVault.addStrategy(strategy1);
            StrategyData[] memory strategies = yelayLiteVault.getStrategies();
            assertEq(strategies.length, 1);
            assertEq(strategies[0].adapter, strategy1.adapter);
            assertEq(strategies[0].supplement, strategy1.supplement);

            vm.expectRevert(abi.encodeWithSelector(LibErrors.StrategyRegistered.selector));
            yelayLiteVault.addStrategy(strategy1);
        }
        {
            yelayLiteVault.addStrategy(strategy2);
            StrategyData[] memory strategies = yelayLiteVault.getStrategies();
            assertEq(strategies.length, 2);
            assertEq(strategies[0].adapter, strategy1.adapter);
            assertEq(strategies[0].supplement, strategy1.supplement);
            assertEq(strategies[1].adapter, strategy2.adapter);
            assertEq(strategies[1].supplement, strategy2.supplement);
        }
        {
            yelayLiteVault.addStrategy(strategy3);
            StrategyData[] memory strategies = yelayLiteVault.getStrategies();
            assertEq(strategies.length, 3);
            assertEq(strategies[0].adapter, strategy1.adapter);
            assertEq(strategies[0].supplement, strategy1.supplement);
            assertEq(strategies[1].adapter, strategy2.adapter);
            assertEq(strategies[1].supplement, strategy2.supplement);
            assertEq(strategies[2].adapter, strategy3.adapter);
            assertEq(strategies[2].supplement, strategy3.supplement);
        }
        {
            yelayLiteVault.removeStrategy(1);
            StrategyData[] memory strategies = yelayLiteVault.getStrategies();
            assertEq(strategies.length, 2);
            assertEq(strategies[0].adapter, strategy1.adapter);
            assertEq(strategies[0].supplement, strategy1.supplement);
            assertEq(strategies[1].adapter, strategy3.adapter);
            assertEq(strategies[1].supplement, strategy3.supplement);
        }
        {
            yelayLiteVault.removeStrategy(1);
            yelayLiteVault.removeStrategy(0);
            StrategyData[] memory strategies = yelayLiteVault.getStrategies();
            assertEq(strategies.length, 0);
        }
        vm.stopPrank();
    }

    function test_activating_strategies() external {
        uint256[] memory queue = new uint256[](0);

        vm.startPrank(owner);

        StrategyData memory strategy1 =
            StrategyData({adapter: address(mockStrategy1), name: "mockStrategy1", supplement: ""});
        StrategyData memory strategy2 =
            StrategyData({adapter: address(mockStrategy2), name: "mockStrategy2", supplement: hex"1234"});
        StrategyData memory strategy3 =
            StrategyData({adapter: address(mockStrategy3), name: "mockStrategy3", supplement: hex"5678"});
        yelayLiteVault.addStrategy(strategy1);
        yelayLiteVault.addStrategy(strategy2);
        yelayLiteVault.addStrategy(strategy3);

        assertEq(yelayLiteVault.getActiveStrategies().length, 0);

        yelayLiteVault.activateStrategy(0, queue, queue);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.StrategyActive.selector));
        yelayLiteVault.activateStrategy(0, queue, queue);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.StrategyActive.selector));
        yelayLiteVault.removeStrategy(0);

        vm.expectRevert();
        yelayLiteVault.deactivateStrategy(1, queue, queue);

        assertEq(yelayLiteVault.getActiveStrategies().length, 1);

        yelayLiteVault.deactivateStrategy(0, queue, queue);

        assertEq(yelayLiteVault.getActiveStrategies().length, 0);

        vm.stopPrank();
    }

    function test_managing_deposit_queue() external {
        assertEq(yelayLiteVault.getDepositQueue(), new uint256[](0));
        vm.startPrank(owner);
        {
            uint256[] memory queue = new uint256[](1);
            queue[0] = 1;
            yelayLiteVault.updateDepositQueue(queue);
            assertEq(yelayLiteVault.getDepositQueue(), queue);
        }
        {
            uint256[] memory queue = new uint256[](3);
            queue[0] = 2;
            queue[1] = 1;
            queue[2] = 3;
            yelayLiteVault.updateDepositQueue(queue);
            assertEq(yelayLiteVault.getDepositQueue(), queue);
        }
        {
            uint256[] memory queue = new uint256[](0);
            yelayLiteVault.updateDepositQueue(queue);
            assertEq(yelayLiteVault.getDepositQueue(), queue);
        }
        vm.stopPrank();
    }

    function test_managing_withdraw_queue() external {
        assertEq(yelayLiteVault.getWithdrawQueue(), new uint256[](0));
        vm.startPrank(owner);
        {
            uint256[] memory queue = new uint256[](1);
            queue[0] = 1;
            yelayLiteVault.updateWithdrawQueue(queue);
            assertEq(yelayLiteVault.getWithdrawQueue(), queue);
        }
        {
            uint256[] memory queue = new uint256[](3);
            queue[0] = 2;
            queue[1] = 1;
            queue[2] = 3;
            yelayLiteVault.updateWithdrawQueue(queue);
            assertEq(yelayLiteVault.getWithdrawQueue(), queue);
        }
        {
            uint256[] memory queue = new uint256[](0);
            yelayLiteVault.updateWithdrawQueue(queue);
            assertEq(yelayLiteVault.getWithdrawQueue(), queue);
        }
        vm.stopPrank();
    }
}

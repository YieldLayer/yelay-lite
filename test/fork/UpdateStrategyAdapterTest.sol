// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";

import {Utils} from "../Utils.sol";
import {AAVE_V3_POOL, USDC_ADDRESS} from "../Constants.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";
import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";
import {AccessFacet} from "src/facets/AccessFacet.sol";
import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";
import {StrategyArgs} from "src/interfaces/IFundsFacet.sol";

contract MigrateStrategyAdapterTest is Test {
    using Utils for address;

    uint256 constant FORK_BLOCK_NUMBER = 22260000;
    address constant owner = address(0x9909eE4947Be39C208607D8d2473d68C05CeF8F9);
    address constant fundsOperator = address(0x76dBc2c72E5c8eF6816Af0F904621d091857fF80);
    IYelayLiteVault constant yelayLiteVault = IYelayLiteVault(0x39DAc87bE293DC855b60feDd89667364865378cc);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_URL"), FORK_BLOCK_NUMBER);
        vm.deal(owner, 1 ether);
    }

    function test_update_strategy_adapter() external {
        vm.startPrank(owner);
        uint256 totalAssetsBefore = yelayLiteVault.totalAssets();

        //#1 Deploy and update management facet
        //No need to remove old facets, all are being replaced, there were no changes to function signatures
        SelectorsToFacet[] memory facets = new SelectorsToFacet[](1);
        facets[0] =
            SelectorsToFacet({facet: address(new ManagementFacet()), selectors: Utils.managementFacetSelectors()});
        yelayLiteVault.setSelectorToFacets(facets);

        //#2 Add updated strategy
        StrategyData memory strategy = StrategyData({
            adapter: address(new AaveV3Strategy(AAVE_V3_POOL)),
            supplement: abi.encode(
                address(USDC_ADDRESS), IPool(AAVE_V3_POOL).getReserveData(address(USDC_ADDRESS)).aTokenAddress
            ),
            name: "aave"
        });
        yelayLiteVault.addStrategy(strategy);

        //#3 Get strategy indexes
        StrategyData[] memory strategies = yelayLiteVault.getStrategies();
        uint256 newAaveStrategyIndex = strategies.length - 1;
        uint256 oldAaveStrategyIndex;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].name == "aave-v3") {
                oldAaveStrategyIndex = i;
                break;
            }
        }

        //#4 Approve strategy
        yelayLiteVault.approveStrategy(newAaveStrategyIndex, type(uint256).max);

        //#5 Activate strategy
        uint256[] memory depositQueue = yelayLiteVault.getDepositQueue();
        uint256[] memory withdrawQueue = yelayLiteVault.getWithdrawQueue();
        for (uint256 i = 0; i < depositQueue.length; i++) {
            if (depositQueue[i] == oldAaveStrategyIndex) {
                depositQueue[i] = newAaveStrategyIndex;
            }
        }
        for (uint256 i = 0; i < withdrawQueue.length; i++) {
            if (withdrawQueue[i] == oldAaveStrategyIndex) {
                withdrawQueue[i] = newAaveStrategyIndex;
            }
        }
        yelayLiteVault.activateStrategy(newAaveStrategyIndex, depositQueue, withdrawQueue);

        //#6 Get active strategy indexes
        StrategyData[] memory activeStrategies = yelayLiteVault.getActiveStrategies();
        uint256 newAaveActiveIndex = activeStrategies.length - 1;
        uint256 oldAaveActiveIndex;
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            if (activeStrategies[i].name == "aave-v3") {
                oldAaveActiveIndex = i;
                break;
            }
        }

        //#7 Accrue fee and reallocate
        {
            vm.stopPrank();
            vm.startPrank(fundsOperator);
            yelayLiteVault.accrueFee();
            uint256 assets = yelayLiteVault.strategyAssets(oldAaveActiveIndex);
            StrategyArgs[] memory withdrawals = new StrategyArgs[](1);
            StrategyArgs[] memory deposits = new StrategyArgs[](1);
            withdrawals[0] = StrategyArgs({index: oldAaveActiveIndex, amount: assets});
            deposits[0] = StrategyArgs({index: newAaveActiveIndex, amount: assets});
            yelayLiteVault.reallocate(withdrawals, deposits);
            vm.stopPrank();
            vm.startPrank(owner);
            assertGe(yelayLiteVault.strategyAssets(newAaveActiveIndex), assets);
        }

        //#8 Deactivate and remove strategy
        yelayLiteVault.deactivateStrategy(oldAaveActiveIndex, depositQueue, withdrawQueue);
        yelayLiteVault.removeStrategy(oldAaveStrategyIndex);

        vm.stopPrank();

        // Check active strategies
        {
            StrategyData[] memory finalActiveStrategies = yelayLiteVault.getActiveStrategies();
            bool foundNewStrategy = false;
            bool foundOldStrategy = false;
            for (uint256 i = 0; i < finalActiveStrategies.length; i++) {
                if (finalActiveStrategies[i].name == "aave") {
                    foundNewStrategy = true;
                }
                if (finalActiveStrategies[i].name == "aave-v3") {
                    foundOldStrategy = true;
                }
            }
            assertTrue(foundNewStrategy);
            assertFalse(foundOldStrategy);
        }

        // Check strategies
        {
            StrategyData[] memory finalStrategies = yelayLiteVault.getStrategies();
            bool foundNewStrategy = false;
            bool foundOldStrategy = false;
            for (uint256 i = 0; i < finalStrategies.length; i++) {
                if (finalStrategies[i].name == "aave") {
                    foundNewStrategy = true;
                }
                if (finalStrategies[i].name == "aave-v3") {
                    foundOldStrategy = true;
                }
            }
            assertTrue(foundNewStrategy);
            assertFalse(foundOldStrategy);
        }

        // Check total assets remained stable through migration
        assertGe(yelayLiteVault.totalAssets(), totalAssetsBefore);
    }
}

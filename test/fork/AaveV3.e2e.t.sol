// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";
import {AAVE_V3_POOL} from "../Constants.sol";

contract AaveV3Test is AbstractStrategyTest {
    function _setupStrategy() internal override {
        vm.startPrank(owner);
        strategyShare = IPool(AAVE_V3_POOL).getReserveData(address(underlyingAsset)).aTokenAddress;
        strategyAdapter = address(new AaveV3Strategy(AAVE_V3_POOL));
        LibManagement.StrategyData memory strategy = LibManagement.StrategyData({
            adapter: strategyAdapter,
            supplement: abi.encode(address(underlyingAsset), strategyShare)
        });
        ManagementFacet(yelayLiteVault).addStrategy(strategy);
        uint256[] memory queue = new uint256[](1);
        queue[0] = 0;
        ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
        ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
        vm.stopPrank();
    }
}

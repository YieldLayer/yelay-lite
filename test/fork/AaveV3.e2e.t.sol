// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";
import {AAVE_V3_POOL} from "../Constants.sol";

contract AaveV3Test is AbstractStrategyTest {
    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new AaveV3Strategy(AAVE_V3_POOL));
        StrategyData memory strategy = StrategyData({
            name: "aave",
            adapter: strategyAdapter,
            supplement: abi.encode(
                address(underlyingAsset), IPool(AAVE_V3_POOL).getReserveData(address(underlyingAsset)).aTokenAddress
            )
        });
        uint256[] memory queue = new uint256[](1);
        queue[0] = 0;
        yelayLiteVault.addStrategy(strategy, queue, queue);
        yelayLiteVault.approveStrategy(0, type(uint256).max);
        vm.stopPrank();
    }
}

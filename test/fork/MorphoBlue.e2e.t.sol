// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {MorphoBlueStrategy} from "src/strategies/MorphoBlueStrategy.sol";
import {MORPHO_BLUE, MORPHO_BLUE_DAI_ID} from "../Constants.sol";

contract MorphoBlueTest is AbstractStrategyTest {
    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new MorphoBlueStrategy(MORPHO_BLUE));
        StrategyData memory strategy =
            StrategyData({adapter: strategyAdapter, supplement: abi.encode(MORPHO_BLUE_DAI_ID), name: "morpho"});
        yelayLiteVault.addStrategy(strategy);
        yelayLiteVault.approveStrategy(0, type(uint256).max);
        {
            uint256[] memory queue = new uint256[](1);
            queue[0] = 0;
            yelayLiteVault.activateStrategy(0, queue, queue);
        }
        vm.stopPrank();
    }
}

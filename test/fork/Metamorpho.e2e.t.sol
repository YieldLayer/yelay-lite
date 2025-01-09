// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";
import {METAMORPHO_GAUNTLET_DAI_CORE} from "../Constants.sol";

contract MetamorphoTest is AbstractStrategyTest {
    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new ERC4626Strategy(METAMORPHO_GAUNTLET_DAI_CORE));
        StrategyData memory strategy = StrategyData({adapter: strategyAdapter, supplement: "", name: "metamorpho"});
        uint256[] memory queue = new uint256[](1);
        queue[0] = 0;
        yelayLiteVault.addStrategy(strategy, queue, queue);
        yelayLiteVault.approveStrategy(0, type(uint256).max);
        vm.stopPrank();
    }
}

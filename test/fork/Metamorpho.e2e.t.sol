// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";
import {METAMORPHO_GAUNTLET_DAI_CORE} from "../Constants.sol";

contract MetamorphoTest is AbstractStrategyTest {
    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new ERC4626Strategy());
        StrategyData memory strategy = StrategyData({
            adapter: strategyAdapter,
            supplement: abi.encode(METAMORPHO_GAUNTLET_DAI_CORE),
            name: "metamorpho"
        });
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

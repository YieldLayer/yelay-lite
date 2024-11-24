// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {GearboxV3Strategy} from "src/strategies/GearboxV3Strategy.sol";
import {GEARBOX_DAI_POOL, GEARBOX_DAI_STAKING, GEARBOX_TOKEN} from "../Constants.sol";

contract GearboxV3Test is AbstractStrategyTest {
    function _setupStrategy() internal override {
        vm.startPrank(owner);
        strategyAdapter = address(new GearboxV3Strategy(GEARBOX_DAI_POOL));
        StrategyData memory strategy =
            StrategyData({adapter: strategyAdapter, supplement: abi.encode(GEARBOX_DAI_STAKING, GEARBOX_TOKEN)});
        yelayLiteVault.addStrategy(strategy);
        uint256[] memory queue = new uint256[](1);
        queue[0] = 0;
        yelayLiteVault.updateDepositQueue(queue);
        yelayLiteVault.updateWithdrawQueue(queue);
        vm.stopPrank();
    }
}

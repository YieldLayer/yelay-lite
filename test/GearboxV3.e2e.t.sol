// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {GearboxV3Strategy} from "src/strategies/GearboxV3Strategy.sol";
import {GEARBOX_DAI_POOL, GEARBOX_DAI_STAKING, GEARBOX_TOKEN} from "./Constants.sol";

contract GearboxV3Test is AbstractStrategyTest {
    function _setupStrategy() internal override {
        vm.startPrank(owner);
        strategyShare = GEARBOX_DAI_STAKING;
        strategyAdapter = address(new GearboxV3Strategy(GEARBOX_DAI_POOL));
        LibManagement.StrategyData memory strategy =
            LibManagement.StrategyData({adapter: strategyAdapter, supplement: abi.encode(strategyShare, GEARBOX_TOKEN)});
        ManagementFacet(yelayLiteVault).addStrategy(strategy);
        uint256[] memory queue = new uint256[](1);
        queue[0] = 0;
        ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
        ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
        vm.stopPrank();
    }
}

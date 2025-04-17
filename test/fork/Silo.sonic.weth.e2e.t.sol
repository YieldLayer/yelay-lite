// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";

contract SiloSonicWethTest is AbstractStrategyTest {
    function _setupFork() internal override {
        underlyingAsset = IERC20(0x50c42dEAcD8Fc9773493ED674b675bE577f2634b);
        userBalance = 1000e18;
        toDeposit = 100e18;
        vm.createSelectFork(vm.envString("SONIC_URL"), 17643934);
    }

    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new ERC4626Strategy());
        StrategyData memory strategy = StrategyData({
            adapter: strategyAdapter,
            supplement: abi.encode(0x219656F33c58488D09d518BaDF50AA8CdCAcA2Aa),
            name: "Silo WETH. Id: 26"
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";

contract EulerSonicWethTest is AbstractStrategyTest {
    function _setupFork() internal override {
        underlyingAsset = IERC20(0x50c42dEAcD8Fc9773493ED674b675bE577f2634b);
        userBalance = 100e18;
        toDeposit = 10e18;
        vm.createSelectFork(vm.envString("SONIC_URL"), 17643934);
    }

    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new ERC4626Strategy());
        StrategyData memory strategy = StrategyData({
            adapter: strategyAdapter,
            supplement: abi.encode(0xa5cd24d9792F4F131f5976Af935A505D19c8Db2b),
            name: "EVK Vault eWETH-1"
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

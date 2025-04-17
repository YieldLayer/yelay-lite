// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";

contract EulerSonicUsdcTest is AbstractStrategyTest {
    function _setupFork() internal override {
        underlyingAsset = IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
        userBalance = 10_000e6;
        toDeposit = 1000e6;
        vm.createSelectFork(vm.envString("SONIC_URL"), 17643934);
    }

    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new ERC4626Strategy());
        StrategyData memory strategy = StrategyData({
            adapter: strategyAdapter,
            supplement: abi.encode(0x196F3C7443E940911EE2Bb88e019Fd71400349D9),
            name: "EVK Vault eUSDC.e-3"
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

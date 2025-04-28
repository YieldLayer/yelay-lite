// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";

contract EulerSonicWsTest is AbstractStrategyTest {
    function _setupFork() internal override {
        underlyingAsset = IERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);
        userBalance = 100_000e18;
        toDeposit = 10_000e18;
        vm.createSelectFork(vm.envString("SONIC_URL"), 17643934);
    }

    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new ERC4626Strategy());
        StrategyData memory strategy = StrategyData({
            adapter: strategyAdapter,
            supplement: abi.encode(0x9144C0F0614dD0acE859C61CC37e5386d2Ada43A),
            name: "EVK Vault ewS-2"
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";

contract SiloVaultSonicWsTest is AbstractStrategyTest {
    function _setupFork() internal override {
        underlyingAsset = IERC20(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);
        userBalance = 10_000e6;
        toDeposit = 1000e6;
        vm.createSelectFork(vm.envString("SONIC_URL"), 28070000);
    }

    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new ERC4626Strategy());
        StrategyData memory strategy = StrategyData({
            adapter: strategyAdapter,
            supplement: abi.encode(0xDED4aC8645619334186f28B8798e07ca354CFa0e),
            name: "SV-Varlamore-S"
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

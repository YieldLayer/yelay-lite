// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

import {ArcadiaStrategy} from "src/strategies/ArcadiaStrategy.sol";

contract ArcadiaBaseWethTest is AbstractStrategyTest {
    function _setupFork() internal override {
        underlyingAsset = IERC20(0x4200000000000000000000000000000000000006);
        userBalance = 10e18;
        toDeposit = 1e18;
        vm.createSelectFork(vm.envString("BASE_URL"), 30000000);
    }

    function _setupStrategy() internal override {
        vm.startPrank(owner);
        address strategyAdapter = address(new ArcadiaStrategy());
        StrategyData memory strategy = StrategyData({
            adapter: strategyAdapter,
            supplement: abi.encode(0x393893caeB06B5C16728bb1E354b6c36942b1382),
            name: "ArcadiaV2 Wrapped Ether"
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

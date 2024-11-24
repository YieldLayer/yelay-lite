// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import {ManagementFacet} from "src/facets/ManagementFacet.sol";
// import {LibManagement} from "src/libraries/LibManagement.sol";

// import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

// import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";
// import {METAMORPHO_GAUNTLET_DAI_CORE} from "../Constants.sol";

// contract MetamorphoTest is AbstractStrategyTest {
//     function _setupStrategy() internal override {
//         vm.startPrank(owner);
//         strategyShare = METAMORPHO_GAUNTLET_DAI_CORE;
//         strategyAdapter = address(new ERC4626Strategy(METAMORPHO_GAUNTLET_DAI_CORE));
//         LibManagement.StrategyData memory strategy =
//             LibManagement.StrategyData({adapter: strategyAdapter, supplement: ""});
//         ManagementFacet(yelayLiteVault).addStrategy(strategy);
//         uint256[] memory queue = new uint256[](1);
//         queue[0] = 0;
//         ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
//         ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
//         vm.stopPrank();
//     }
// }

// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import {ManagementFacet} from "src/facets/ManagementFacet.sol";
// import {LibManagement} from "src/libraries/LibManagement.sol";

// import {AbstractStrategyTest} from "./AbstractStrategyTest.sol";

// import {MorphoBlueStrategy} from "src/strategies/MorphoBlueStrategy.sol";
// import {MORPHO_BLUE, MORPHO_BLUE_DAI_ID} from "../Constants.sol";

// contract MorphoBlueTest is AbstractStrategyTest {
//     function _setupStrategy() internal override {
//         vm.startPrank(owner);
//         strategyShare = MORPHO_BLUE;
//         strategyAdapter = address(new MorphoBlueStrategy(MORPHO_BLUE));
//         LibManagement.StrategyData memory strategy = LibManagement.StrategyData({
//             adapter: strategyAdapter,
//             supplement: abi.encode(address(underlyingAsset), MORPHO_BLUE_DAI_ID)
//         });
//         ManagementFacet(yelayLiteVault).addStrategy(strategy);
//         uint256[] memory queue = new uint256[](1);
//         queue[0] = 0;
//         ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
//         ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
//         vm.stopPrank();
//     }
// }

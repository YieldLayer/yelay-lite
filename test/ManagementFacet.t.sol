// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import {Test, console} from "forge-std/Test.sol";

// import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

// import {YelayLiteVault} from "src/YelayLiteVault.sol";
// import {YelayLiteVaultInit} from "src/YelayLiteVaultInit.sol";

// import {ManagementFacet} from "src/facets/ManagementFacet.sol";
// import {FundsFacet} from "src/facets/FundsFacet.sol";

// import {LibManagement} from "src/libraries/LibManagement.sol";

// import {MockStrategy} from "./MockStrategy.sol";
// import {MockToken} from "./MockToken.sol";
// import {Utils} from "./Utils.sol";

// contract ManagementFacetTest is Test {
//     using Utils for address;

//     address owner = address(0x01);
//     address mockProtocol1 = address(0x02);
//     address mockProtocol2 = address(0x03);
//     address mockProtocol3 = address(0x04);
//     address yieldExtractor = address(0x05);

//     MockToken underlyingAsset;

//     address yelayLiteVault;
//     YelayLiteVaultInit init;

//     DiamondCutFacet diamondCutFacet;
//     ManagementFacet managementFacet;
//     FundsFacet fundsFacet;

//     MockStrategy mockStrategy1;
//     MockStrategy mockStrategy2;
//     MockStrategy mockStrategy3;

//     function setUp() external {
//         vm.startPrank(owner);
//         underlyingAsset = new MockToken("DAI", "DAI", 18);
//         mockStrategy1 = new MockStrategy(mockProtocol1);
//         mockStrategy2 = new MockStrategy(mockProtocol2);
//         mockStrategy3 = new MockStrategy(mockProtocol3);
//         diamondCutFacet = new DiamondCutFacet();
//         yelayLiteVault = address(new YelayLiteVault(owner, address(diamondCutFacet)));
//         managementFacet = new ManagementFacet();
//         fundsFacet = new FundsFacet();
//         init = new YelayLiteVaultInit();
//         yelayLiteVault.addFundsFacet(init, fundsFacet, address(underlyingAsset), address(0x02));
//         yelayLiteVault.addManagementFacet(managementFacet);
//         vm.stopPrank();
//     }

//     function test_managing_strategies() external {
//         assertEq(ManagementFacet(yelayLiteVault).getStrategies().length, 0);
//         vm.startPrank(owner);
//         LibManagement.StrategyData memory strategy1 =
//             LibManagement.StrategyData({adapter: address(mockStrategy1), supplement: ""});
//         LibManagement.StrategyData memory strategy2 =
//             LibManagement.StrategyData({adapter: address(mockStrategy2), supplement: hex"1234"});
//         LibManagement.StrategyData memory strategy3 =
//             LibManagement.StrategyData({adapter: address(mockStrategy3), supplement: hex"5678"});
//         assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy1.protocol()), 0);
//         assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy2.protocol()), 0);
//         assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy3.protocol()), 0);
//         {
//             ManagementFacet(yelayLiteVault).addStrategy(strategy1);
//             LibManagement.StrategyData[] memory strategies = ManagementFacet(yelayLiteVault).getStrategies();
//             assertEq(strategies.length, 1);
//             assertEq(strategies[0].adapter, strategy1.adapter);
//             assertEq(strategies[0].supplement, strategy1.supplement);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy1.protocol()), type(uint256).max);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy2.protocol()), 0);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy3.protocol()), 0);
//         }
//         {
//             ManagementFacet(yelayLiteVault).addStrategy(strategy2);
//             LibManagement.StrategyData[] memory strategies = ManagementFacet(yelayLiteVault).getStrategies();
//             assertEq(strategies.length, 2);
//             assertEq(strategies[0].adapter, strategy1.adapter);
//             assertEq(strategies[0].supplement, strategy1.supplement);
//             assertEq(strategies[1].adapter, strategy2.adapter);
//             assertEq(strategies[1].supplement, strategy2.supplement);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy1.protocol()), type(uint256).max);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy2.protocol()), type(uint256).max);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy3.protocol()), 0);
//         }
//         {
//             ManagementFacet(yelayLiteVault).addStrategy(strategy3);
//             LibManagement.StrategyData[] memory strategies = ManagementFacet(yelayLiteVault).getStrategies();
//             assertEq(strategies.length, 3);
//             assertEq(strategies[0].adapter, strategy1.adapter);
//             assertEq(strategies[0].supplement, strategy1.supplement);
//             assertEq(strategies[1].adapter, strategy2.adapter);
//             assertEq(strategies[1].supplement, strategy2.supplement);
//             assertEq(strategies[2].adapter, strategy3.adapter);
//             assertEq(strategies[2].supplement, strategy3.supplement);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy1.protocol()), type(uint256).max);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy2.protocol()), type(uint256).max);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy3.protocol()), type(uint256).max);
//         }
//         {
//             ManagementFacet(yelayLiteVault).removeStrategy(1);
//             LibManagement.StrategyData[] memory strategies = ManagementFacet(yelayLiteVault).getStrategies();
//             assertEq(strategies.length, 2);
//             assertEq(strategies[0].adapter, strategy1.adapter);
//             assertEq(strategies[0].supplement, strategy1.supplement);
//             assertEq(strategies[1].adapter, strategy3.adapter);
//             assertEq(strategies[1].supplement, strategy3.supplement);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy1.protocol()), type(uint256).max);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy2.protocol()), 0);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy3.protocol()), type(uint256).max);
//         }
//         {
//             ManagementFacet(yelayLiteVault).removeStrategy(1);
//             ManagementFacet(yelayLiteVault).removeStrategy(0);
//             LibManagement.StrategyData[] memory strategies = ManagementFacet(yelayLiteVault).getStrategies();
//             assertEq(strategies.length, 0);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy1.protocol()), 0);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy2.protocol()), 0);
//             assertEq(underlyingAsset.allowance(yelayLiteVault, mockStrategy3.protocol()), 0);
//         }
//         vm.stopPrank();
//     }

//     function test_managing_deposit_queue() external {
//         assertEq(ManagementFacet(yelayLiteVault).getDepositQueue(), new uint256[](0));
//         vm.startPrank(owner);
//         {
//             uint256[] memory queue = new uint256[](1);
//             queue[0] = 1;
//             ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
//             assertEq(ManagementFacet(yelayLiteVault).getDepositQueue(), queue);
//         }
//         {
//             uint256[] memory queue = new uint256[](3);
//             queue[0] = 2;
//             queue[1] = 1;
//             queue[2] = 3;
//             ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
//             assertEq(ManagementFacet(yelayLiteVault).getDepositQueue(), queue);
//         }
//         {
//             uint256[] memory queue = new uint256[](0);
//             ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
//             assertEq(ManagementFacet(yelayLiteVault).getDepositQueue(), queue);
//         }
//         vm.stopPrank();
//     }

//     function test_managing_withdraw_queue() external {
//         assertEq(ManagementFacet(yelayLiteVault).getWithdrawQueue(), new uint256[](0));
//         vm.startPrank(owner);
//         {
//             uint256[] memory queue = new uint256[](1);
//             queue[0] = 1;
//             ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
//             assertEq(ManagementFacet(yelayLiteVault).getWithdrawQueue(), queue);
//         }
//         {
//             uint256[] memory queue = new uint256[](3);
//             queue[0] = 2;
//             queue[1] = 1;
//             queue[2] = 3;
//             ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
//             assertEq(ManagementFacet(yelayLiteVault).getWithdrawQueue(), queue);
//         }
//         {
//             uint256[] memory queue = new uint256[](0);
//             ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
//             assertEq(ManagementFacet(yelayLiteVault).getWithdrawQueue(), queue);
//         }
//         vm.stopPrank();
//     }
// }

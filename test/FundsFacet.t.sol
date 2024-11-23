// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import {Test, console} from "forge-std/Test.sol";

// import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

// import {IPool} from "src/interfaces/external/aave/v3/IPool.sol";

// import {YelayLiteVault} from "src/YelayLiteVault.sol";
// import {TokenFacet, ERC1155Upgradeable} from "src/facets/TokenFacet.sol";
// import {FundsFacet, ERC20} from "src/facets/FundsFacet.sol";
// import {ManagementFacet} from "src/facets/ManagementFacet.sol";
// import {YelayLiteVaultInit} from "src/YelayLiteVaultInit.sol";
// import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";

// import {Utils} from "./Utils.sol";
// import {DAI_ADDRESS, MAINNET_BLOCK_NUMBER, AAVE_V3_POOL} from "./Constants.sol";

// contract FundsFacetTest is Test {
//     using Utils for address;

//     address owner = address(0x01);
//     address user = address(0x02);
//     address user2 = address(0x03);
//     address yieldExtractor = address(0x04);

//     address yelayLiteVault;
//     DiamondCutFacet diamondCutFacet;
//     TokenFacet tokenFacet;
//     FundsFacet fundsFacet;
//     ManagementFacet managementFacet;

//     ERC20 underlyingAsset = ERC20(DAI_ADDRESS);
//     YelayLiteVaultInit init;

//     AaveV3Strategy aaveAdapter;
//     address aTokenAddress;
//     uint256 yieldProjectId = 0;
//     uint256 projectId = 1;

//     function setUp() external {
//         vm.createSelectFork(vm.envString("MAINNET_URL"), MAINNET_BLOCK_NUMBER);

//         vm.startPrank(owner);
//         diamondCutFacet = new DiamondCutFacet();
//         yelayLiteVault = address(new YelayLiteVault(owner, address(diamondCutFacet)));
//         tokenFacet = new TokenFacet();
//         fundsFacet = new FundsFacet();
//         managementFacet = new ManagementFacet();
//         init = new YelayLiteVaultInit();

//         yelayLiteVault.addTokenFacet(init, tokenFacet, "https://yelay-lite-vault/{id}.json");
//         yelayLiteVault.addFundsFacet(init, fundsFacet, address(underlyingAsset), yieldExtractor);
//         yelayLiteVault.addManagementFacet(managementFacet);

//         IPool.ReserveData memory reserveData = IPool(AAVE_V3_POOL).getReserveData(DAI_ADDRESS);
//         aTokenAddress = reserveData.aTokenAddress;

//         aaveAdapter = new AaveV3Strategy(AAVE_V3_POOL, DAI_ADDRESS, aTokenAddress);
//         vm.stopPrank();

//         vm.startPrank(user);
//         underlyingAsset.approve(yelayLiteVault, type(uint256).max);
//         vm.stopPrank();
//         vm.startPrank(user2);
//         underlyingAsset.approve(yelayLiteVault, type(uint256).max);
//         vm.stopPrank();
//     }

//     function test_deposit_with_no_strategy() external {
//         uint256 userBalance = 10_000e18;
//         uint256 toDeposit = 1000e18;
//         deal(address(underlyingAsset), user, userBalance);

//         assertEq(underlyingAsset.balanceOf(user), userBalance);
//         assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
//         assertEq(FundsFacet(yelayLiteVault).totalAssets(), 0);
//         assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
//         assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), 0);

//         vm.startPrank(user);
//         FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
//         vm.stopPrank();

//         assertEq(underlyingAsset.balanceOf(user), userBalance - toDeposit);
//         assertEq(underlyingAsset.balanceOf(yelayLiteVault), toDeposit);
//         assertEq(FundsFacet(yelayLiteVault).totalAssets(), toDeposit);
//         assertEq(TokenFacet(yelayLiteVault).totalSupply(), toDeposit);
//         assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), toDeposit);
//     }

//     function test_withdraw_with_no_strategy() external {
//         uint256 userBalance = 10_000e18;
//         uint256 toDeposit = 1000e18;
//         deal(address(underlyingAsset), user, userBalance);

//         vm.startPrank(user);
//         FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
//         FundsFacet(yelayLiteVault).redeem(toDeposit, projectId, user);
//         vm.stopPrank();

//         assertEq(underlyingAsset.balanceOf(user), userBalance);
//         assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
//         assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
//         assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), 0);
//     }

//     function test_managing_deposit_queue() external {
//         assertEq(FundsFacet(yelayLiteVault).getDepositQueue(), new address[](0));
//         vm.startPrank(owner);
//         {
//             address[] memory depositQueue_ = new address[](1);
//             depositQueue_[0] = address(aaveAdapter);
//             FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
//             assertEq(FundsFacet(yelayLiteVault).getDepositQueue(), depositQueue_);
//         }
//         {
//             address[] memory depositQueue_ = new address[](0);
//             FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
//             assertEq(FundsFacet(yelayLiteVault).getDepositQueue(), depositQueue_);
//         }
//         vm.stopPrank();
//     }

//     function test_managing_withdraw_queue() external {
//         assertEq(FundsFacet(yelayLiteVault).getWithdrawQueue(), new address[](0));
//         vm.startPrank(owner);
//         {
//             address[] memory withdrawQueue_ = new address[](1);
//             withdrawQueue_[0] = address(aaveAdapter);
//             FundsFacet(yelayLiteVault).updateWithdrawQueue(withdrawQueue_);
//             assertEq(FundsFacet(yelayLiteVault).getWithdrawQueue(), withdrawQueue_);
//         }
//         {
//             address[] memory withdrawQueue_ = new address[](0);
//             FundsFacet(yelayLiteVault).updateWithdrawQueue(withdrawQueue_);
//             assertEq(FundsFacet(yelayLiteVault).getWithdrawQueue(), withdrawQueue_);
//         }
//         vm.stopPrank();
//     }

//     function test_deposit_with_strategy() external {
//         vm.startPrank(owner);
//         {
//             address[] memory depositQueue_ = new address[](1);
//             depositQueue_[0] = address(aaveAdapter);
//             FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
//         }
//         vm.stopPrank();
//         uint256 userBalance = 10_000e18;
//         uint256 toDeposit = 1000e18;
//         deal(address(underlyingAsset), user, userBalance);

//         assertEq(underlyingAsset.balanceOf(user), userBalance);
//         assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
//         assertEq(FundsFacet(yelayLiteVault).totalAssets(), 0);
//         assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
//         assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), 0);

//         vm.startPrank(user);
//         FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
//         vm.stopPrank();

//         assertEq(underlyingAsset.balanceOf(user), userBalance - toDeposit);
//         assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
//         assertApproxEqAbs(FundsFacet(yelayLiteVault).totalAssets(), toDeposit, 1);
//         assertEq(TokenFacet(yelayLiteVault).totalSupply(), toDeposit);
//         assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), toDeposit);
//         assertApproxEqAbs(ERC20(aTokenAddress).balanceOf(yelayLiteVault), toDeposit, 1);
//     }

//     function test_withdraw_with_strategy() external {
//         vm.startPrank(owner);
//         {
//             address[] memory depositQueue_ = new address[](1);
//             depositQueue_[0] = address(aaveAdapter);
//             FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
//             FundsFacet(yelayLiteVault).updateWithdrawQueue(depositQueue_);
//         }
//         vm.stopPrank();
//         uint256 userBalance = 10_000e18;
//         uint256 toDeposit = 1000e18;
//         deal(address(underlyingAsset), user, userBalance);

//         vm.startPrank(user);
//         FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
//         FundsFacet(yelayLiteVault).redeem(toDeposit, projectId, user);
//         vm.stopPrank();

//         assertApproxEqAbs(underlyingAsset.balanceOf(user), userBalance, 1);
//         assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
//         assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
//         assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), 0);
//     }

//     function test_yield_extraction() external {
//         vm.startPrank(owner);
//         {
//             address[] memory depositQueue_ = new address[](1);
//             depositQueue_[0] = address(aaveAdapter);
//             FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
//             FundsFacet(yelayLiteVault).updateWithdrawQueue(depositQueue_);
//         }
//         vm.stopPrank();

//         uint256 toDeposit = 1_000e18;
//         uint256 yieldExtractorShareBalance;

//         for (uint256 i = 1; i < 20; i++) {
//             address user3 = address(bytes20(bytes32(111111111111111111111111111111111111111111 * i)));
//             deal(address(underlyingAsset), user3, toDeposit);
//             vm.startPrank(user3);
//             underlyingAsset.approve(yelayLiteVault, type(uint256).max);
//             FundsFacet(yelayLiteVault).deposit(toDeposit, i, user3);
//             vm.stopPrank();
//             assertEq(underlyingAsset.balanceOf(user3), 0);
//             if (i + 1 < 20) {
//                 vm.warp(block.timestamp + 10 weeks);
//             }
//             uint256 newYieldExtractorShareBalance = TokenFacet(yelayLiteVault).balanceOf(yieldExtractor, yieldProjectId);
//             if (newYieldExtractorShareBalance > 0) {
//                 assertGt(newYieldExtractorShareBalance, yieldExtractorShareBalance);
//             }
//             yieldExtractorShareBalance = newYieldExtractorShareBalance;
//         }

//         assertEq(underlyingAsset.balanceOf(yieldExtractor), 0);

//         vm.startPrank(yieldExtractor);
//         FundsFacet(yelayLiteVault).redeem(yieldExtractorShareBalance, yieldProjectId, yieldExtractor);
//         vm.stopPrank();

//         assertGt(underlyingAsset.balanceOf(yieldExtractor), 0);
//         assertApproxEqAbs(underlyingAsset.balanceOf(yieldExtractor), yieldExtractorShareBalance, 1);

//         assertApproxEqAbs(TokenFacet(yelayLiteVault).totalSupply(), FundsFacet(yelayLiteVault).totalAssets(), 1);

//         assertEq(TokenFacet(yelayLiteVault).balanceOf(yieldExtractor, yieldProjectId), 0);

//         for (uint256 i = 1; i < 20; i++) {
//             address user3 = address(bytes20(bytes32(111111111111111111111111111111111111111111 * i)));
//             vm.startPrank(user3);
//             FundsFacet(yelayLiteVault).redeem(TokenFacet(yelayLiteVault).balanceOf(user3, i), i, user3);
//             vm.stopPrank();
//             assertEq(underlyingAsset.balanceOf(user3), toDeposit);
//             if (i + 1 < 20) {
//                 vm.warp(block.timestamp + 10 weeks);
//             }
//         }

//         assertGt(TokenFacet(yelayLiteVault).totalSupply(), 0);
//         assertGt(FundsFacet(yelayLiteVault).totalAssets(), 0);
//         assertGt(TokenFacet(yelayLiteVault).balanceOf(yieldExtractor, yieldProjectId), 0);

//         {
//             uint256 sharesBefore = TokenFacet(yelayLiteVault).balanceOf(yieldExtractor, yieldProjectId);
//             uint256 assetsBefore = underlyingAsset.balanceOf(yieldExtractor);
//             vm.startPrank(yieldExtractor);
//             FundsFacet(yelayLiteVault).redeem(sharesBefore, yieldProjectId, yieldExtractor);
//             vm.stopPrank();

//             uint256 assetsAfter = underlyingAsset.balanceOf(yieldExtractor);

//             assertApproxEqAbs(assetsAfter - assetsBefore, sharesBefore, 2);
//         }

//         assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
//         assertEq(FundsFacet(yelayLiteVault).totalAssets(), 0);
//         assertEq(TokenFacet(yelayLiteVault).balanceOf(yieldExtractor, yieldProjectId), 0);
//     }
// }

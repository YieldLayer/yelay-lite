// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

import {IPool} from "src/interfaces/external/aave/v3/IPool.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {TokenFacet} from "src/facets/TokenFacet.sol";
import {FundsFacet, ERC20} from "src/facets/FundsFacet.sol";
import {YelayLiteVaultInit} from "src/YelayLiteVaultInit.sol";
import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";

import {Utils} from "./Utils.sol";
import {DAI_ADDRESS, MAINNET_BLOCK_NUMBER, AAVE_V3_POOL} from "./Constants.sol";

contract FundsFacetTest is Test {
    using Utils for address;

    address owner = address(0x01);
    address user = address(0x02);
    address user2 = address(0x03);
    address yieldExtractor = address(0x04);

    address yelayLiteVault;
    DiamondCutFacet diamondCutFacet;
    TokenFacet tokenFacet;
    FundsFacet fundsFacet;
    ERC20 underlyingAsset = ERC20(DAI_ADDRESS);
    YelayLiteVaultInit init;

    AaveV3Strategy aaveAdapter;
    address aTokenAddress;

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_URL"), MAINNET_BLOCK_NUMBER);

        vm.startPrank(owner);
        diamondCutFacet = new DiamondCutFacet();
        yelayLiteVault = address(new YelayLiteVault(owner, address(diamondCutFacet)));
        tokenFacet = new TokenFacet();
        fundsFacet = new FundsFacet();
        init = new YelayLiteVaultInit();

        yelayLiteVault.addTokenFacet(init, tokenFacet, "Yelay DAI Vault", "YLAY-DAI");
        yelayLiteVault.addFundsFacet(init, fundsFacet, address(underlyingAsset), yieldExtractor);

        IPool.ReserveData memory reserveData = IPool(AAVE_V3_POOL).getReserveData(DAI_ADDRESS);
        aTokenAddress = reserveData.aTokenAddress;

        aaveAdapter = new AaveV3Strategy(AAVE_V3_POOL, DAI_ADDRESS, aTokenAddress);
        vm.stopPrank();
    }

    function test_deposit_with_no_strategy() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        assertEq(underlyingAsset.balanceOf(user), userBalance);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
        assertEq(FundsFacet(yelayLiteVault).totalAssets(), 0);
        assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user), 0);

        vm.startPrank(user);
        underlyingAsset.approve(yelayLiteVault, type(uint256).max);
        FundsFacet(yelayLiteVault).deposit(toDeposit, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance - toDeposit);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), toDeposit);
        assertEq(FundsFacet(yelayLiteVault).totalAssets(), toDeposit);
        assertEq(TokenFacet(yelayLiteVault).totalSupply(), toDeposit);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user), toDeposit);
    }

    function test_withdraw_with_no_strategy() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        underlyingAsset.approve(yelayLiteVault, type(uint256).max);
        FundsFacet(yelayLiteVault).deposit(toDeposit, user);

        ERC20(yelayLiteVault).approve(yelayLiteVault, type(uint256).max);
        FundsFacet(yelayLiteVault).redeem(toDeposit, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
        assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user), 0);
    }

    function test_managing_deposit_queue() external {
        assertEq(FundsFacet(yelayLiteVault).getDepositQueue(), new address[](0));
        vm.startPrank(owner);
        {
            address[] memory depositQueue_ = new address[](1);
            depositQueue_[0] = address(aaveAdapter);
            FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
            assertEq(FundsFacet(yelayLiteVault).getDepositQueue(), depositQueue_);
        }
        {
            address[] memory depositQueue_ = new address[](0);
            FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
            assertEq(FundsFacet(yelayLiteVault).getDepositQueue(), depositQueue_);
        }
        vm.stopPrank();
    }

    function test_managing_withdraw_queue() external {
        assertEq(FundsFacet(yelayLiteVault).getWithdrawQueue(), new address[](0));
        vm.startPrank(owner);
        {
            address[] memory withdrawQueue_ = new address[](1);
            withdrawQueue_[0] = address(aaveAdapter);
            FundsFacet(yelayLiteVault).updateWithdrawQueue(withdrawQueue_);
            assertEq(FundsFacet(yelayLiteVault).getWithdrawQueue(), withdrawQueue_);
        }
        {
            address[] memory withdrawQueue_ = new address[](0);
            FundsFacet(yelayLiteVault).updateWithdrawQueue(withdrawQueue_);
            assertEq(FundsFacet(yelayLiteVault).getWithdrawQueue(), withdrawQueue_);
        }
        vm.stopPrank();
    }

    function test_deposit_with_strategy() external {
        vm.startPrank(owner);
        {
            address[] memory depositQueue_ = new address[](1);
            depositQueue_[0] = address(aaveAdapter);
            FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
        }
        vm.stopPrank();
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        assertEq(underlyingAsset.balanceOf(user), userBalance);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
        assertEq(FundsFacet(yelayLiteVault).totalAssets(), 0);
        assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user), 0);

        vm.startPrank(user);
        underlyingAsset.approve(yelayLiteVault, type(uint256).max);
        FundsFacet(yelayLiteVault).deposit(toDeposit, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance - toDeposit);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).totalAssets(), toDeposit, 1);
        assertEq(TokenFacet(yelayLiteVault).totalSupply(), toDeposit);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user), toDeposit);
        assertApproxEqAbs(ERC20(aTokenAddress).balanceOf(yelayLiteVault), toDeposit, 1);
    }

    function test_withdraw_with_strategy() external {
        vm.startPrank(owner);
        {
            address[] memory depositQueue_ = new address[](1);
            depositQueue_[0] = address(aaveAdapter);
            FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
            FundsFacet(yelayLiteVault).updateWithdrawQueue(depositQueue_);
        }
        vm.stopPrank();
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        underlyingAsset.approve(yelayLiteVault, type(uint256).max);
        FundsFacet(yelayLiteVault).deposit(toDeposit, user);

        ERC20(yelayLiteVault).approve(yelayLiteVault, type(uint256).max);
        FundsFacet(yelayLiteVault).redeem(toDeposit, user);
        vm.stopPrank();

        assertApproxEqAbs(underlyingAsset.balanceOf(user), userBalance, 1);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
        assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user), 0);
    }

    function test_yield_extraction() external {
        vm.startPrank(owner);
        {
            address[] memory depositQueue_ = new address[](1);
            depositQueue_[0] = address(aaveAdapter);
            FundsFacet(yelayLiteVault).updateDepositQueue(depositQueue_);
            FundsFacet(yelayLiteVault).updateWithdrawQueue(depositQueue_);
        }
        vm.stopPrank();

        uint256 toDeposit = 1_000e18;
        uint256 yieldExtractorShareBalance;

        for (uint256 i = 1; i < 20; i++) {
            address user3 = address(bytes20(bytes32(111111111111111111111111111111111111111111 * i)));
            deal(address(underlyingAsset), user3, toDeposit);
            vm.startPrank(user3);
            underlyingAsset.approve(yelayLiteVault, type(uint256).max);
            FundsFacet(yelayLiteVault).deposit(toDeposit, user3);
            vm.stopPrank();
            if (i + 1 < 20) {
                vm.warp(block.timestamp + 10 weeks);
            }
            uint256 newYieldExtractorShareBalance = TokenFacet(yelayLiteVault).balanceOf(yieldExtractor);
            if (newYieldExtractorShareBalance > 0) {
                assertGt(newYieldExtractorShareBalance, yieldExtractorShareBalance);
            }
            yieldExtractorShareBalance = newYieldExtractorShareBalance;
        }

        assertEq(underlyingAsset.balanceOf(yieldExtractor), 0);

        vm.startPrank(yieldExtractor);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        FundsFacet(yelayLiteVault).redeem(yieldExtractorShareBalance, yieldExtractor);
        vm.stopPrank();

        assertGt(underlyingAsset.balanceOf(yieldExtractor), 0);
        assertApproxEqAbs(underlyingAsset.balanceOf(yieldExtractor), yieldExtractorShareBalance, 1);

        assertApproxEqAbs(TokenFacet(yelayLiteVault).totalSupply(), FundsFacet(yelayLiteVault).totalAssets(), 1);

        assertEq(TokenFacet(yelayLiteVault).balanceOf(yieldExtractor), 0);
    }
}

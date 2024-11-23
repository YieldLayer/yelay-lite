// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";
import {TokenFacet, ERC1155Upgradeable} from "src/facets/TokenFacet.sol";
import {FundsFacet, ERC20} from "src/facets/FundsFacet.sol";
import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {YelayLiteVaultInit} from "src/YelayLiteVaultInit.sol";

import {Utils} from "../Utils.sol";

import {MorphoBlueStrategy} from "src/strategies/MorphoBlueStrategy.sol";
import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {DAI_ADDRESS, MAINNET_BLOCK_NUMBER, MORPHO_BLUE, MORPHO_BLUE_DAI_ID, AAVE_V3_POOL} from "../Constants.sol";

contract ReallocationTest is Test {
    using Utils for address;

    address owner = address(0x01);
    address user = address(0x02);
    address user2 = address(0x03);
    address yieldExtractor = address(0x04);

    address yelayLiteVault;
    DiamondCutFacet diamondCutFacet;
    TokenFacet tokenFacet;
    FundsFacet fundsFacet;
    ManagementFacet managementFacet;

    ERC20 underlyingAsset = ERC20(DAI_ADDRESS);
    YelayLiteVaultInit init;

    address strategyAdapter;
    address strategyShare;
    uint256 yieldProjectId = 0;
    uint256 projectId = 1;

    function _setupStrategy() internal {
        vm.startPrank(owner);
        {
            LibManagement.StrategyData memory strategy = LibManagement.StrategyData({
                adapter: address(new AaveV3Strategy(AAVE_V3_POOL)),
                supplement: abi.encode(
                    address(underlyingAsset), IPool(AAVE_V3_POOL).getReserveData(address(underlyingAsset)).aTokenAddress
                )
            });
            ManagementFacet(yelayLiteVault).addStrategy(strategy);
        }
        {
            LibManagement.StrategyData memory strategy = LibManagement.StrategyData({
                adapter: address(new MorphoBlueStrategy(MORPHO_BLUE)),
                supplement: abi.encode(address(underlyingAsset), MORPHO_BLUE_DAI_ID)
            });
            ManagementFacet(yelayLiteVault).addStrategy(strategy);
        }
        uint256[] memory queue = new uint256[](2);
        queue[0] = 0;
        queue[1] = 1;
        ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
        ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
        vm.stopPrank();
    }

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_URL"), MAINNET_BLOCK_NUMBER);

        vm.startPrank(owner);
        diamondCutFacet = new DiamondCutFacet();
        yelayLiteVault = address(new YelayLiteVault(owner, address(diamondCutFacet)));
        tokenFacet = new TokenFacet();
        fundsFacet = new FundsFacet();
        managementFacet = new ManagementFacet();
        init = new YelayLiteVaultInit();

        yelayLiteVault.addTokenFacet(init, tokenFacet, "https://yelay-lite-vault/{id}.json");
        yelayLiteVault.addFundsFacet(init, fundsFacet, address(underlyingAsset), yieldExtractor);
        yelayLiteVault.addManagementFacet(managementFacet);
        vm.stopPrank();

        vm.startPrank(user);
        underlyingAsset.approve(yelayLiteVault, type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user2);
        underlyingAsset.approve(yelayLiteVault, type(uint256).max);
        vm.stopPrank();
    }

    function test_managed_deposit() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
        vm.stopPrank();

        _setupStrategy();

        {
            vm.startPrank(owner);
            FundsFacet.StrategyArgs memory strategyArgs = FundsFacet.StrategyArgs({index: 0, amount: toDeposit / 2});
            FundsFacet(yelayLiteVault).managedDeposit(strategyArgs);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(yelayLiteVault), toDeposit / 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).totalAssets(), toDeposit, 1);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(1), 0, 2);

        {
            vm.startPrank(owner);
            FundsFacet.StrategyArgs memory strategyArgs = FundsFacet.StrategyArgs({index: 1, amount: toDeposit / 4});
            FundsFacet(yelayLiteVault).managedDeposit(strategyArgs);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(yelayLiteVault), toDeposit / 4);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).totalAssets(), toDeposit, 1);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(1), toDeposit / 4, 2);
    }

    function test_managed_withdraw() external {
        _setupStrategy();

        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
        vm.stopPrank();

        {
            // swap deposit queue
            vm.startPrank(owner);
            uint256[] memory queue = new uint256[](2);
            queue[0] = 1;
            queue[1] = 0;
            ManagementFacet(yelayLiteVault).updateDepositQueue(queue);
            ManagementFacet(yelayLiteVault).updateWithdrawQueue(queue);
            vm.stopPrank();
        }

        // deposit second time in another strategy
        vm.startPrank(user);
        FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(0), toDeposit, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(1), toDeposit, 2);

        {
            vm.startPrank(owner);
            FundsFacet.StrategyArgs memory strategyArgs = FundsFacet.StrategyArgs({index: 0, amount: toDeposit / 2});
            FundsFacet(yelayLiteVault).managedWithdraw(strategyArgs);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(yelayLiteVault), toDeposit / 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).totalAssets(), toDeposit * 2, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(1), toDeposit, 2);

        {
            vm.startPrank(owner);
            FundsFacet.StrategyArgs memory strategyArgs = FundsFacet.StrategyArgs({index: 1, amount: toDeposit / 4});
            FundsFacet(yelayLiteVault).managedWithdraw(strategyArgs);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 3 * toDeposit / 4);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).totalAssets(), 2 * toDeposit, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(1), 3 * toDeposit / 4, 2);
    }

    function test_reallocation() external {
        _setupStrategy();

        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).totalAssets(), toDeposit, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(0), toDeposit, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(1), 0, 2);

        {
            vm.startPrank(owner);
            FundsFacet.StrategyArgs[] memory withdrawals = new FundsFacet.StrategyArgs[](1);
            FundsFacet.StrategyArgs[] memory deposits = new FundsFacet.StrategyArgs[](1);
            withdrawals[0] = FundsFacet.StrategyArgs({index: 0, amount: toDeposit / 2});
            deposits[0] = FundsFacet.StrategyArgs({index: 1, amount: toDeposit / 2});
            FundsFacet(yelayLiteVault).reallocate(withdrawals, deposits);
            vm.stopPrank();
        }

        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).totalAssets(), toDeposit, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(0), toDeposit / 2, 2);
        assertApproxEqAbs(FundsFacet(yelayLiteVault).strategyAssets(1), toDeposit / 2, 2);
    }
}

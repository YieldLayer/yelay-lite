// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {SwapArgs} from "src/interfaces/ISwapper.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {Reward} from "src/interfaces/IStrategyBase.sol";
import {GearboxV3Strategy} from "src/strategies/GearboxV3Strategy.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {MockExchange, Quote} from "../MockExchange.sol";
import {Utils} from "../Utils.sol";
import {
    DAI_ADDRESS, MAINNET_BLOCK_NUMBER, GEARBOX_DAI_POOL, GEARBOX_DAI_STAKING, GEARBOX_TOKEN
} from "../Constants.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

contract CompoundTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant user = address(0x02);
    address constant yieldExtractor = address(0x04);
    uint256 constant yieldProjectId = 0;
    uint256 constant projectId = 1;

    IYelayLiteVault yelayLiteVault;

    IERC20 underlyingAsset = IERC20(DAI_ADDRESS);

    MockExchange mockExchange;

    function _setupStrategy() internal {
        vm.startPrank(owner);
        address strategyAdapter = address(new GearboxV3Strategy(GEARBOX_TOKEN));
        StrategyData memory strategy = StrategyData({
            adapter: strategyAdapter,
            name: "gearbox",
            supplement: abi.encode(GEARBOX_DAI_POOL, GEARBOX_DAI_STAKING)
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

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_URL"), MAINNET_BLOCK_NUMBER);

        vm.startPrank(owner);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        yelayLiteVault.grantRole(LibRoles.QUEUES_OPERATOR, owner);
        yelayLiteVault.grantRole(LibRoles.STRATEGY_AUTHORITY, owner);

        yelayLiteVault.grantRole(LibRoles.FUNDS_OPERATOR, owner);

        mockExchange = new MockExchange();
        Utils.addExchange(yelayLiteVault, address(mockExchange));
        vm.stopPrank();

        vm.startPrank(user);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        vm.stopPrank();

        _setupStrategy();
    }

    function test_view_rewards() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(LibErrors.OnlyView.selector));
        yelayLiteVault.strategyRewards(0);

        {
            vm.startPrank(address(0), address(0));
            Reward[] memory rewards = yelayLiteVault.strategyRewards(0);
            vm.stopPrank();

            assertEq(rewards.length, 1);
            assertEq(rewards[0].token, GEARBOX_TOKEN);
            assertEq(rewards[0].amount, 0);
        }

        vm.warp(block.timestamp + 1 weeks);

        {
            vm.startPrank(address(0), address(0));
            Reward[] memory rewards = yelayLiteVault.strategyRewards(0);
            vm.stopPrank();

            assertEq(rewards.length, 1);
            assertEq(rewards[0].token, GEARBOX_TOKEN);
            assertGt(rewards[0].amount, 0);
        }
    }

    function test_claim_rewards() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 weeks);

        assertEq(IERC20(GEARBOX_TOKEN).balanceOf(address(yelayLiteVault)), 0);

        vm.startPrank(owner);
        yelayLiteVault.claimStrategyRewards(0);
        vm.stopPrank();

        assertGt(IERC20(GEARBOX_TOKEN).balanceOf(address(yelayLiteVault)), 0);
    }

    function test_compound() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 weeks);

        vm.startPrank(owner);
        yelayLiteVault.accrueFee();
        vm.stopPrank();

        deal(address(underlyingAsset), address(mockExchange), 1000e18);
        deal(GEARBOX_TOKEN, address(mockExchange), 1000e18);
        mockExchange.setQuote(GEARBOX_TOKEN, address(underlyingAsset), Quote({fromAmount: 10e18, toAmount: 1e18}));

        vm.startPrank(owner);
        yelayLiteVault.claimStrategyRewards(0);
        vm.stopPrank();

        uint256 gearBalance = IERC20(GEARBOX_TOKEN).balanceOf(address(yelayLiteVault));

        uint256 underlyingAssetBefore = yelayLiteVault.underlyingBalance();

        vm.startPrank(owner);
        {
            SwapArgs[] memory s = new SwapArgs[](1);
            s[0] = SwapArgs({
                tokenIn: address(underlyingAsset),
                swapTarget: address(mockExchange),
                swapCallData: abi.encodeWithSelector(
                    MockExchange.swap.selector, GEARBOX_TOKEN, address(underlyingAsset), gearBalance / 2
                )
            });
            vm.expectRevert(
                abi.encodeWithSelector(
                    IAccessControl.AccessControlUnauthorizedAccount.selector, owner, LibRoles.SWAP_REWARDS_OPERATOR
                )
            );
            yelayLiteVault.swapRewards(s);

            yelayLiteVault.grantRole(LibRoles.SWAP_REWARDS_OPERATOR, owner);

            vm.expectRevert(abi.encodeWithSelector(LibErrors.CompoundUnderlyingForbidden.selector));
            yelayLiteVault.swapRewards(s);
        }
        SwapArgs[] memory swapArgs = new SwapArgs[](1);
        swapArgs[0] = SwapArgs({
            tokenIn: GEARBOX_TOKEN,
            swapTarget: address(mockExchange),
            swapCallData: abi.encodeWithSelector(
                MockExchange.swap.selector, GEARBOX_TOKEN, address(underlyingAsset), gearBalance / 2
            )
        });
        uint256 compounded = yelayLiteVault.swapRewards(swapArgs);
        vm.stopPrank();

        assertEq(yelayLiteVault.underlyingBalance(), underlyingAssetBefore + compounded);
        assertEq(IERC20(GEARBOX_TOKEN).balanceOf(address(yelayLiteVault)), gearBalance / 2);
        assertEq(compounded, mockExchange.previewSwap(GEARBOX_TOKEN, address(underlyingAsset), gearBalance / 2));
    }

    function test_accrueFee() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        yelayLiteVault.deposit(toDeposit, projectId, user);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 weeks);

        assertEq(yelayLiteVault.balanceOf(yieldExtractor, 0), 0);
        uint256 totalSupplyBefore = yelayLiteVault.totalSupply();
        uint256 totalSupply0Before = yelayLiteVault.totalSupply(0);
        uint256 lastTotalAssetsBefore = yelayLiteVault.lastTotalAssets();
        uint256 lastTotalAssetsTimestampBefore = yelayLiteVault.lastTotalAssetsTimestamp();
        assertEq(totalSupply0Before, 0);

        yelayLiteVault.accrueFee();

        assertGt(yelayLiteVault.balanceOf(yieldExtractor, 0), 0);
        assertGt(yelayLiteVault.totalSupply(), totalSupplyBefore);
        assertGt(yelayLiteVault.totalSupply(0), 0);
        assertGt(yelayLiteVault.lastTotalAssets(), lastTotalAssetsBefore);
        assertEq(yelayLiteVault.lastTotalAssetsTimestamp(), lastTotalAssetsTimestampBefore + 10 weeks);
    }
}

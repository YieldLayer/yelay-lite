// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {ERC4626Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

import {ERC4626PluginFactory} from "src/plugins/ERC4626PluginFactory.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";

import {ERC4626Plugin} from "src/plugins/ERC4626Plugin.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {MockYieldExtractor} from "test/mocks/MockYieldExtractor.sol";
import {MockToken} from "test/mocks/MockToken.sol";
import {MockStrategy, MockProtocol} from "test/mocks/MockStrategy.sol";
import {Utils} from "test/Utils.sol";

contract ERC4626PluginTest is Test {
    ERC4626Plugin erc4626Plugin;
    MockYieldExtractor yieldExtractor;
    IYelayLiteVault yelayLiteVault;
    MockToken underlyingAsset;
    MockProtocol mockProtocol;
    MockStrategy mockStrategy;
    ERC4626PluginFactory factory;

    string constant PLUGIN_SYMBOL = "TP";
    string constant PLUGIN_NAME = "TestPlugin";
    uint256 constant PROJECT_ID = 33;
    bytes32 constant SALT = keccak256("test-salt");
    string constant URI = "https://yelay-lite-vault/{id}.json";

    uint256 constant WITHDRAW_MARGIN = 10;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    uint256 toDeposit = 1000e6;

    uint256 DECIMAL_OFFSET;

    function setUp() public {
        underlyingAsset = new MockToken("Underlying", "UND", 6);

        yieldExtractor = new MockYieldExtractor();

        yelayLiteVault = Utils.deployDiamond(address(this), address(underlyingAsset), address(yieldExtractor), URI);

        factory = new ERC4626PluginFactory(address(this), address(new ERC4626Plugin(address(yieldExtractor))));

        erc4626Plugin = factory.deploy(PLUGIN_NAME, PLUGIN_SYMBOL, address(yelayLiteVault), PROJECT_ID);

        mockProtocol = new MockProtocol(address(underlyingAsset));
        mockStrategy = new MockStrategy(address(mockProtocol));

        yelayLiteVault.grantRole(LibRoles.QUEUES_OPERATOR, address(this));
        yelayLiteVault.grantRole(LibRoles.STRATEGY_AUTHORITY, address(this));

        StrategyData memory strategy = StrategyData({adapter: address(mockStrategy), supplement: "", name: ""});
        yelayLiteVault.addStrategy(strategy);
        yelayLiteVault.approveStrategy(0, type(uint256).max);
        {
            uint256[] memory queue = new uint256[](1);
            queue[0] = 0;
            yelayLiteVault.activateStrategy(0, queue, queue);
        }

        vm.startPrank(user1);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        underlyingAsset.approve(address(erc4626Plugin), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user2);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        underlyingAsset.approve(address(erc4626Plugin), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(user3);
        underlyingAsset.approve(address(yelayLiteVault), type(uint256).max);
        underlyingAsset.approve(address(erc4626Plugin), type(uint256).max);
        vm.stopPrank();

        deal(address(underlyingAsset), user1, toDeposit);
        deal(address(underlyingAsset), user2, toDeposit);
        deal(address(underlyingAsset), user3, toDeposit);

        // pre-seed vault
        vm.startPrank(user3);
        yelayLiteVault.deposit(toDeposit, 1, user3);
        vm.stopPrank();

        // generate yield - 10%
        mockProtocol.increaseAssetBalance(address(yelayLiteVault), toDeposit / 10);
        yelayLiteVault.accrueFee();

        DECIMAL_OFFSET = erc4626Plugin.DECIMALS_OFFSET();
    }

    function _toShares(uint256 amount) internal view returns (uint256) {
        return amount * 10 ** DECIMAL_OFFSET;
    }

    function _toAssets(uint256 amount) internal view returns (uint256) {
        return amount / (10 ** DECIMAL_OFFSET);
    }

    function _generateYield() internal returns (uint256) {
        uint256 yieldShares = yelayLiteVault.balanceOf(address(yieldExtractor), 0);
        uint256 yieldToGenerate = yieldShares / 2;
        yieldExtractor.setToClaim(yieldToGenerate);
        erc4626Plugin.accrue(YieldExtractor.ClaimRequest(address(yelayLiteVault), PROJECT_ID, 0, 0, new bytes32[](0)));
        return yieldToGenerate;
    }

    function test_vault_setup() external view {
        assertEq(yelayLiteVault.totalAssets(), toDeposit * 11 / 10, "Total Assets");
        assertEq(yelayLiteVault.totalSupply(), toDeposit * 11 / 10, "Total Supply");
        assertEq(yelayLiteVault.totalSupply(0), toDeposit / 10, "Yield Supply");
        assertEq(erc4626Plugin.DECIMALS_OFFSET(), 12, "Decimal offset");
        assertEq(erc4626Plugin.totalAssets(), 0, "No assets");
        assertEq(erc4626Plugin.totalSupply(), 0, "No supply");
        assertEq(erc4626Plugin.decimals(), 18, "Decimals");
    }

    function test_preview_empty_plugin() external view {
        assertEq(
            erc4626Plugin.previewDeposit(toDeposit),
            _toShares(toDeposit),
            "previewDeposit: Return same amount of shares"
        );
        assertEq(
            erc4626Plugin.previewMint(_toShares(toDeposit)), toDeposit, "previewMint: Return same amount of assets"
        );
        assertEq(
            erc4626Plugin.previewRedeem(_toShares(toDeposit)), toDeposit, "previewRedeem: Return same amount of assets"
        );
        assertEq(
            erc4626Plugin.previewWithdraw(toDeposit),
            _toShares(toDeposit),
            "previewWithdraw: Return same amount of shares"
        );
    }

    function test_convert_empty_plugin() external view {
        assertEq(erc4626Plugin.convertToAssets(_toShares(toDeposit)), toDeposit, "Return same amount of assets");
        assertEq(erc4626Plugin.convertToShares(toDeposit), _toShares(toDeposit), "Return same amount of shares");
    }

    function test_deposit() external {
        vm.prank(user1);
        erc4626Plugin.deposit(toDeposit, user1);

        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit));
        assertEq(erc4626Plugin.balanceOf(user2), 0);
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit));
        assertEq(erc4626Plugin.totalAssets(), toDeposit);

        vm.prank(user2);
        erc4626Plugin.deposit(toDeposit / 2, user2);

        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit));
        assertEq(erc4626Plugin.balanceOf(user2), _toShares(toDeposit / 2));
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit * 3 / 2));
        assertEq(erc4626Plugin.totalAssets(), toDeposit * 3 / 2);
    }

    function test_mint() external {
        vm.startPrank(user1);
        erc4626Plugin.mint(_toShares(toDeposit), user1);
        vm.stopPrank();

        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit));
        assertEq(erc4626Plugin.balanceOf(user2), 0);
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit));
        assertEq(erc4626Plugin.totalAssets(), toDeposit);

        vm.startPrank(user2);
        erc4626Plugin.mint(_toShares(toDeposit / 2), user2);
        vm.stopPrank();

        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit));
        assertEq(erc4626Plugin.balanceOf(user2), _toShares(toDeposit / 2));
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit * 3 / 2));
        assertEq(erc4626Plugin.totalAssets(), toDeposit * 3 / 2);
    }

    function test_preview_non_empty_without_yield() external {
        vm.prank(user1);
        erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        erc4626Plugin.deposit(toDeposit / 2, user2);

        assertEq(erc4626Plugin.previewDeposit(toDeposit), _toShares(toDeposit), "Return same amount of shares");
        assertEq(erc4626Plugin.previewMint(_toShares(toDeposit)), toDeposit, "Return same amount of assets");
        assertEq(erc4626Plugin.previewRedeem(_toShares(toDeposit)), toDeposit, "Almost the same amount of assets");
        assertEq(erc4626Plugin.previewWithdraw(toDeposit), _toShares(toDeposit), "Almost the same amount of shares");
    }

    function test_preview_non_empty_with_yield() external {
        vm.prank(user1);
        erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        erc4626Plugin.deposit(toDeposit / 2, user2);

        uint256 totalSupplyBefore = yelayLiteVault.totalSupply(PROJECT_ID);

        // we already have 10% of yield shares, generate up to 50% for all holders
        mockProtocol.increaseAssetBalance(address(yelayLiteVault), 29 * toDeposit / 10);
        yelayLiteVault.accrueFee();

        uint256 generatedShares = _generateYield();

        uint256 totalSupplyAfter = yelayLiteVault.totalSupply(PROJECT_ID);

        assertEq(totalSupplyBefore, generatedShares, "Generated full supply of yield");
        assertEq(totalSupplyBefore * 2, totalSupplyAfter, "Supply has been doubled");

        assertApproxEqAbs(
            erc4626Plugin.previewDeposit(toDeposit),
            _toShares(toDeposit) / 2,
            // since shares are more precise there is no 100% match
            10 ** DECIMAL_OFFSET,
            "Would return half amount of shares"
        );
        assertEq(erc4626Plugin.previewMint(_toShares(toDeposit)), toDeposit * 2, "Need double amount of assets");
        assertApproxEqAbs(
            erc4626Plugin.previewRedeem(_toShares(toDeposit)),
            toDeposit * 2,
            1,
            "Since we doubled totalAssets user should get twice as much"
        );
        assertApproxEqAbs(
            erc4626Plugin.previewWithdraw(toDeposit),
            _toShares(toDeposit) / 2,
            1e12,
            "We need half of the shares to get the depositAmount"
        );
    }

    function test_convert_non_empty_without_yield() external {
        vm.prank(user1);
        erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        erc4626Plugin.deposit(toDeposit / 2, user2);

        assertEq(erc4626Plugin.convertToAssets(_toShares(toDeposit)), toDeposit, "Return same amount of assets");
        assertEq(erc4626Plugin.convertToShares(toDeposit), _toShares(toDeposit), "Return same amount of shares");
    }

    function test_convert_non_empty_with_yield() external {
        vm.prank(user1);
        erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        erc4626Plugin.deposit(toDeposit / 2, user2);

        // we already have 10% of yield shares, generate up to 50% for all holders
        mockProtocol.increaseAssetBalance(address(yelayLiteVault), 29 * toDeposit / 10);
        yelayLiteVault.accrueFee();
        _generateYield();

        assertApproxEqAbs(
            erc4626Plugin.convertToAssets(_toShares(toDeposit)), toDeposit * 2, 1, "Return double amount of assets"
        );
        assertApproxEqAbs(
            erc4626Plugin.convertToShares(toDeposit),
            _toShares(toDeposit) / 2,
            10 ** DECIMAL_OFFSET,
            "Return half amount of shares"
        );
    }

    function test_deposit_redeem_without_yield() external {
        vm.prank(user1);
        uint256 user1Shares = erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        uint256 user2Shares = erc4626Plugin.deposit(toDeposit / 2, user2);

        uint256 user1PreviewRedeem = erc4626Plugin.previewRedeem(user1Shares / 2);

        // partial withdraw
        vm.prank(user1);
        uint256 user1AssetsWithdrawn = erc4626Plugin.redeem(user1Shares / 2, user1, user1);

        assertEq(user1AssetsWithdrawn, user1PreviewRedeem, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user1), toDeposit / 2, "Check user1 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), _toShares(toDeposit / 2), "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit), "Total supply");
        assertEq(erc4626Plugin.totalAssets(), toDeposit, "Total assets");

        uint256 user2PreviewRedeem = erc4626Plugin.previewRedeem(user2Shares);

        // full withdraw
        vm.prank(user2);
        uint256 user2AssetsWithdrawn = erc4626Plugin.redeem(user2Shares, user2, user2);

        assertEq(user2AssetsWithdrawn, user2PreviewRedeem, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user2), toDeposit, "Check user2 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), 0, "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit / 2), "Total supply");
        assertEq(erc4626Plugin.totalAssets(), toDeposit / 2, "Total assets");
    }

    function test_deposit_redeem_with_yield() external {
        vm.prank(user1);
        uint256 user1Shares = erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        uint256 user2Shares = erc4626Plugin.deposit(toDeposit / 2, user2);

        // we already have 10% of yield shares, generate up to 50% for all holders
        mockProtocol.increaseAssetBalance(address(yelayLiteVault), 29 * toDeposit / 10);
        yelayLiteVault.accrueFee();
        _generateYield();

        uint256 user1PreviewRedeem = erc4626Plugin.previewRedeem(user1Shares / 2);

        // partial withdraw
        vm.prank(user1);
        uint256 user1AssetsWithdrawn = erc4626Plugin.redeem(user1Shares / 2, user1, user1);

        assertEq(user1AssetsWithdrawn, user1PreviewRedeem, "Compare preview and actual action");
        assertApproxEqAbs(underlyingAsset.balanceOf(user1), toDeposit, 1, "Check user1 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), _toShares(toDeposit / 2), "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit), "Total supply");
        assertApproxEqAbs(erc4626Plugin.totalAssets(), toDeposit * 2, 1, "Total assets");

        uint256 user2PreviewRedeem = erc4626Plugin.previewRedeem(user2Shares);

        // full withdraw
        vm.prank(user2);
        uint256 user2AssetsWithdrawn = erc4626Plugin.redeem(user2Shares, user2, user2);

        assertEq(user2AssetsWithdrawn, user2PreviewRedeem, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user2), toDeposit * 3 / 2, "Check user2 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), 0, "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit / 2), "Total supply");
        assertApproxEqAbs(erc4626Plugin.totalAssets(), toDeposit, 1, "Total assets");
    }

    function test_deposit_withdraw_without_yield() external {
        vm.prank(user1);
        erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        erc4626Plugin.deposit(toDeposit / 2, user2);

        uint256 user1PreviewWithdraw = erc4626Plugin.previewWithdraw(toDeposit / 2);

        // partial withdraw
        vm.prank(user1);
        uint256 user1SharesBurned = erc4626Plugin.withdraw(toDeposit / 2, user1, user1);

        assertEq(user1PreviewWithdraw, user1SharesBurned, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user1), toDeposit / 2, "Check user1 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), _toShares(toDeposit / 2), "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit), "Total supply");
        assertEq(erc4626Plugin.totalAssets(), toDeposit, "Total assets");
        assertEq(
            underlyingAsset.balanceOf(address(erc4626Plugin)), WITHDRAW_MARGIN, "Withdrawal margin remained on plugin"
        );

        uint256 user2PreviewWithdraw = erc4626Plugin.previewWithdraw(toDeposit / 2);

        // full withdraw
        vm.prank(user2);
        uint256 user2SharesBurned = erc4626Plugin.withdraw(toDeposit / 2, user2, user2);

        assertEq(user2PreviewWithdraw, user2SharesBurned, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user2), toDeposit, "Check user2 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), 0, "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit / 2), "Total supply");
        assertEq(erc4626Plugin.totalAssets(), toDeposit / 2, "Total assets");
        assertEq(
            underlyingAsset.balanceOf(address(erc4626Plugin)),
            WITHDRAW_MARGIN * 2,
            "Withdrawal margin remained on plugin"
        );
    }

    function test_deposit_withdraw_with_yield() external {
        vm.prank(user1);
        erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        erc4626Plugin.deposit(toDeposit / 2, user2);

        // we already have 10% of yield shares, generate up to 50% for all holders
        mockProtocol.increaseAssetBalance(address(yelayLiteVault), 29 * toDeposit / 10);
        yelayLiteVault.accrueFee();
        _generateYield();

        uint256 user1PreviewWithdraw = erc4626Plugin.previewWithdraw(toDeposit / 2);

        // partial withdraw
        vm.prank(user1);
        uint256 user1SharesBurned = erc4626Plugin.withdraw(toDeposit / 2, user1, user1);

        assertEq(user1PreviewWithdraw, user1SharesBurned, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user1), toDeposit / 2, "Check user1 balance");
        assertApproxEqAbs(erc4626Plugin.balanceOf(user1), _toShares(3 * toDeposit / 4), 1e11, "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), _toShares(toDeposit / 2), "User2 shares");
        assertApproxEqAbs(erc4626Plugin.totalSupply(), _toShares(5 * toDeposit / 4), 1e11, "Total supply");
        assertEq(erc4626Plugin.totalAssets(), 5 * toDeposit / 2, "Total assets");
        assertEq(
            underlyingAsset.balanceOf(address(erc4626Plugin)), WITHDRAW_MARGIN, "Withdrawal margin remained on plugin"
        );

        uint256 user2MaxWithdraw = erc4626Plugin.maxWithdraw(user2);

        assertApproxEqAbs(user2MaxWithdraw, toDeposit, 1);

        uint256 user2PreviewWithdraw = erc4626Plugin.previewWithdraw(user2MaxWithdraw);

        // full withdraw
        vm.prank(user2);
        uint256 user2SharesBurned = erc4626Plugin.withdraw(user2MaxWithdraw, user2, user2);

        assertEq(user2PreviewWithdraw, user2SharesBurned, "Compare preview and actual action");
        assertApproxEqAbs(underlyingAsset.balanceOf(user2), 3 * toDeposit / 2, 1, "Check user2 balance");
        assertApproxEqAbs(erc4626Plugin.balanceOf(user1), _toShares(3 * toDeposit / 4), 1e11, "User1 shares");
        assertApproxEqAbs(erc4626Plugin.balanceOf(user2), 0, 1e12, "User2 shares");
        assertApproxEqAbs(erc4626Plugin.totalSupply(), _toShares(3 * toDeposit / 4), 3e11, "Total supply");
        assertApproxEqAbs(erc4626Plugin.totalAssets(), 3 * toDeposit / 2, 1, "Total assets");
        assertEq(
            underlyingAsset.balanceOf(address(erc4626Plugin)),
            WITHDRAW_MARGIN * 2,
            "Withdrawal margin remained on plugin"
        );
    }

    function test_skim() external {
        vm.prank(user1);
        erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        erc4626Plugin.deposit(toDeposit / 2, user2);

        // full withdraw
        vm.startPrank(user2);
        uint256 user2MaxWithdraw = erc4626Plugin.maxWithdraw(user2);
        uint256 sharesBurnt = erc4626Plugin.withdraw(user2MaxWithdraw, user2, user2);
        vm.stopPrank();

        assertEq(toDeposit / 2, user2MaxWithdraw, "User2 has withdrawn his funds");
        assertEq(_toShares(toDeposit / 2), sharesBurnt, "User2 has withdrawn his funds");

        assertEq(erc4626Plugin.totalAssets(), toDeposit, "Total assets");
        assertEq(
            underlyingAsset.balanceOf(address(erc4626Plugin)), WITHDRAW_MARGIN, "Withdrawal margin remained on plugin"
        );

        uint256 skimmed = erc4626Plugin.skim();

        assertEq(skimmed, WITHDRAW_MARGIN, "Skimmed withdraw margin");
        assertEq(erc4626Plugin.totalAssets(), toDeposit, "Total assets");
        assertEq(underlyingAsset.balanceOf(address(erc4626Plugin)), 0, "Plugin doesn't hold assets");
    }

    function test_deposit_zero_assets_reverts() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroValue.selector));
        erc4626Plugin.deposit(0, user1);
        vm.stopPrank();
    }

    function test_deposit_zero_shares_reverts() external {
        uint256 largeLooseBalance = 1e30;
        deal(address(underlyingAsset), address(erc4626Plugin), largeLooseBalance);

        assertEq(erc4626Plugin.previewDeposit(1), 0, "previewDeposit should round to zero shares");

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroValue.selector));
        erc4626Plugin.deposit(1, user1);
        vm.stopPrank();
    }

    function test_mint_zero_shares_reverts() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroValue.selector));
        erc4626Plugin.mint(0, user1);
        vm.stopPrank();
    }

    function test_redeem_zero_shares_reverts() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroValue.selector));
        erc4626Plugin.redeem(0, user1, user1);
        vm.stopPrank();
    }

    function test_redeem_zero_assets_reverts() external {
        vm.startPrank(user1);
        erc4626Plugin.deposit(toDeposit, user1);
        vm.stopPrank();

        uint256 pluginShares = yelayLiteVault.balanceOf(address(erc4626Plugin), PROJECT_ID);
        vm.mockCall(
            address(yelayLiteVault),
            abi.encodeWithSelector(IFundsFacet.convertToAssets.selector, pluginShares),
            abi.encode(uint256(0))
        );

        assertEq(erc4626Plugin.previewRedeem(1), 0, "previewRedeem should round to zero assets");

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroValue.selector));
        erc4626Plugin.redeem(1, user1, user1);
        vm.stopPrank();

        vm.clearMockedCalls();
    }

    function test_withdraw_zero_assets_reverts() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroValue.selector));
        erc4626Plugin.withdraw(0, user1, user1);
        vm.stopPrank();
    }

    function test_redeem_ERC4626ExceededMaxRedeem() external {
        vm.startPrank(user1);
        uint256 shares = erc4626Plugin.deposit(toDeposit, user1);

        vm.expectRevert(
            abi.encodeWithSelector(ERC4626Upgradeable.ERC4626ExceededMaxRedeem.selector, user1, shares + 1, shares)
        );
        erc4626Plugin.redeem(shares + 1, user1, user1);
    }

    function test_withdraw_ERC4626ExceededMaxWithdraw() external {
        vm.startPrank(user1);
        erc4626Plugin.deposit(toDeposit, user1);

        uint256 maxWithdraw = erc4626Plugin.maxWithdraw(user1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC4626Upgradeable.ERC4626ExceededMaxWithdraw.selector, user1, maxWithdraw + 1, maxWithdraw
            )
        );
        erc4626Plugin.withdraw(maxWithdraw + 1, user1, user1);
    }

    function test_WithdrawSlippageExceeded() external {
        vm.startPrank(user1);
        erc4626Plugin.deposit(toDeposit, user1);

        uint256 toWithdraw = toDeposit - WITHDRAW_MARGIN;

        uint256 yelayLiteShares = yelayLiteVault.previewWithdraw(toWithdraw);

        vm.mockCall(
            address(yelayLiteVault),
            abi.encodeWithSelector(IFundsFacet.redeem.selector, yelayLiteShares, PROJECT_ID, address(erc4626Plugin)),
            abi.encode(toWithdraw - 1)
        );

        vm.expectRevert(abi.encodeWithSelector(LibErrors.WithdrawSlippageExceeded.selector, toWithdraw, toWithdraw - 1));
        erc4626Plugin.withdraw(toWithdraw, user1, user1);
    }

    function test_last_withdraw() external {
        vm.prank(user1);
        uint256 user1Shares = erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        uint256 user2Shares = erc4626Plugin.deposit(toDeposit, user2);

        vm.startPrank(user1);
        uint256 user1MaxWithdraw = erc4626Plugin.maxWithdraw(user1);
        uint256 user1Burnt = erc4626Plugin.withdraw(user1MaxWithdraw, user1, user1);
        assertEq(user1Burnt, user1Shares, "User1 burnt");
        assertEq(user1MaxWithdraw, toDeposit, "User1 withdrawn");
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 user2MaxWithdraw = erc4626Plugin.maxWithdraw(user2);
        uint256 user2Burnt = erc4626Plugin.withdraw(user2MaxWithdraw, user2, user2);
        assertEq(user2Burnt, user2Shares, "User2 burnt");
        assertEq(user2MaxWithdraw, toDeposit, "User2 withdrawn");
        vm.stopPrank();
    }

    function test_accrue() external {
        vm.prank(user1);
        uint256 shares = erc4626Plugin.deposit(toDeposit, user1);

        uint256 totalAssetsBefore = erc4626Plugin.totalAssets();

        assertEq(totalAssetsBefore, toDeposit);
        assertEq(erc4626Plugin.totalSupply(), shares);
        assertEq(yelayLiteVault.totalSupply(PROJECT_ID), toDeposit);

        uint256 pluginShares = yelayLiteVault.totalSupply(PROJECT_ID);
        uint256 generatedYield = _generateYield();

        assertEq(yelayLiteVault.balanceOf(address(yieldExtractor), 0), generatedYield, "Yield shares reduced");

        assertEq(
            erc4626Plugin.totalAssets(),
            (totalAssetsBefore * (pluginShares + generatedYield)) / pluginShares,
            "Total assets increase"
        );
        assertEq(erc4626Plugin.totalSupply(), shares, "Total supply unchanged");
        assertEq(
            yelayLiteVault.totalSupply(PROJECT_ID),
            toDeposit + generatedYield,
            "Yelay lite vault project total supply increase"
        );
    }

    function test_withdraw_within_margin() external {
        uint256 reducedMargin = 7;

        vm.startPrank(user1);
        erc4626Plugin.deposit(toDeposit, user1);

        uint256 toWithdraw = toDeposit / 2;

        // return withing margin but less then requested
        mockProtocol.setWithdraw(toWithdraw + reducedMargin);

        uint256 userBalanceBefore = underlyingAsset.balanceOf(user1);
        erc4626Plugin.withdraw(toWithdraw, user1, user1);
        uint256 userBalanceAfter = underlyingAsset.balanceOf(user1);
        assertEq(userBalanceAfter - toWithdraw, userBalanceBefore, "User has withdrawn what was requested");

        assertEq(
            underlyingAsset.balanceOf(address(erc4626Plugin)),
            reducedMargin,
            "Reduced margin is remained on erc4626Plugin"
        );
        assertEq(erc4626Plugin.totalAssets(), toDeposit / 2 - WITHDRAW_MARGIN + reducedMargin, "Total assets");
    }

    // function test_donation_attack() external {
    //     uint256 OFFSET = 0;
    //     uint256 amount = 1e18;
    //     uint256 donation = amount * (1 + 10 ** OFFSET);

    //     MockToken WETH = new MockToken("WETH", "WETH", 18);

    //     IYelayLiteVault vault = Utils.deployDiamond(address(this), address(WETH), address(yieldExtractor), URI);

    //     ERC4626Plugin plugin = factory.deploy("WETH TEST", "T_WETH", address(vault), PROJECT_ID);

    //     address attacker = makeAddr("attacker");
    //     deal(address(WETH), attacker, 100 * amount);

    //     vm.startPrank(attacker);
    //     WETH.approve(address(plugin), type(uint256).max);
    //     WETH.approve(address(vault), type(uint256).max);
    //     plugin.mint(1, attacker);
    //     vault.deposit(donation, PROJECT_ID, address(plugin));
    //     vm.stopPrank();

    //     deal(address(WETH), user1, amount);

    //     vm.startPrank(user1);
    //     WETH.approve(address(plugin), type(uint256).max);

    //     uint256 received = plugin.deposit(amount, user1);
    //     assertEq(received, 0, "User lost funds");
    //     vm.stopPrank();

    //     vm.startPrank(attacker);
    //     uint256 taken = plugin.redeem(1, attacker, attacker);
    //     assertEq(taken, 1 + 3 * amount / 2);
    //     assertLt(taken, donation);
    //     vm.stopPrank();
    // }
}

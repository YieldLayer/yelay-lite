// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ERC4626PluginFactory} from "src/plugins/ERC4626PluginFactory.sol";
import {ERC4626Plugin} from "src/plugins/ERC4626Plugin.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
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

    string constant PLUGIN_SYMBOL = "TP";
    string constant PLUGIN_NAME = "TestPlugin";
    uint256 constant PROJECT_ID = 33;
    bytes32 constant SALT = keccak256("test-salt");
    string constant URI = "https://yelay-lite-vault/{id}.json";

    uint256 constant WITHDRAW_MARGIN = 10;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    uint256 toDeposit = 1000e18;

    function setUp() public {
        underlyingAsset = new MockToken("Underlying", "UND", 6);

        yieldExtractor = new MockYieldExtractor();

        yelayLiteVault = Utils.deployDiamond(address(this), address(underlyingAsset), address(yieldExtractor), URI);

        ERC4626PluginFactory factory =
            new ERC4626PluginFactory(address(this), address(new ERC4626Plugin(address(yieldExtractor))));

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
    }

    function _toShares(uint256 amount) internal view returns (uint256) {
        return amount * 10 ** erc4626Plugin.DECIMALS_OFFSET();
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
        assertEq(erc4626Plugin.previewDeposit(toDeposit), _toShares(toDeposit), "Return same amount of shares");
        assertEq(erc4626Plugin.previewMint(_toShares(toDeposit)), toDeposit, "Return same amount of assets");
        assertEq(erc4626Plugin.previewRedeem(_toShares(toDeposit)), 0, "Zero assets");
        assertEq(erc4626Plugin.previewWithdraw(toDeposit), 0, "Zero shares");
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
        assertEq(
            erc4626Plugin.previewRedeem(_toShares(toDeposit)),
            toDeposit - WITHDRAW_MARGIN,
            "Almost the same amount of assets, minus withdrawal margin"
        );
        assertEq(
            erc4626Plugin.previewWithdraw(toDeposit),
            _toShares(toDeposit) + _toShares(WITHDRAW_MARGIN),
            "Almost the same amount of shares, plus withdrawal margin"
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

    function test_deposit_redeem_without_yield() external {
        vm.prank(user1);
        uint256 user1Shares = erc4626Plugin.deposit(toDeposit, user1);
        vm.prank(user2);
        uint256 user2Shares = erc4626Plugin.deposit(toDeposit / 2, user2);

        uint256 user1PreviewRedeem = erc4626Plugin.previewRedeem(user1Shares / 2);

        // partial withdraw
        vm.prank(user1);
        uint256 user1AssetsWithdrawn = erc4626Plugin.redeem(user1Shares / 2, user1, user1);

        assertEq(user1AssetsWithdrawn, user1PreviewRedeem + WITHDRAW_MARGIN, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user1), toDeposit / 2, "Check user1 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), _toShares(toDeposit / 2), "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit), "Total supply");
        assertEq(erc4626Plugin.totalAssets(), toDeposit, "Total assets");

        uint256 user2PreviewRedeem = erc4626Plugin.previewRedeem(user2Shares);

        // full withdraw
        vm.prank(user2);
        uint256 user2AssetsWithdrawn = erc4626Plugin.redeem(user2Shares, user2, user2);

        assertEq(user2AssetsWithdrawn, user2PreviewRedeem + WITHDRAW_MARGIN, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user2), toDeposit, "Check user2 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), 0, "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit / 2), "Total supply");
        assertEq(erc4626Plugin.totalAssets(), toDeposit / 2, "Total assets");
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
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2) - _toShares(WITHDRAW_MARGIN), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), _toShares(toDeposit / 2), "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit) - _toShares(WITHDRAW_MARGIN), "Total supply");
        assertEq(erc4626Plugin.totalAssets(), toDeposit, "Total assets");
        assertEq(
            underlyingAsset.balanceOf(address(erc4626Plugin)), WITHDRAW_MARGIN, "Withdrawal margin remained on plugin"
        );

        uint256 user2PreviewWithdraw = erc4626Plugin.previewWithdraw(toDeposit / 2 - WITHDRAW_MARGIN);

        // full withdraw
        vm.prank(user2);
        uint256 user2SharesBurned = erc4626Plugin.withdraw(toDeposit / 2 - WITHDRAW_MARGIN, user2, user2);

        assertEq(user2PreviewWithdraw, user2SharesBurned, "Compare preview and actual action");
        assertEq(underlyingAsset.balanceOf(user2), toDeposit - WITHDRAW_MARGIN, "Check user2 balance");
        assertEq(erc4626Plugin.balanceOf(user1), _toShares(toDeposit / 2) - _toShares(WITHDRAW_MARGIN), "User1 shares");
        assertEq(erc4626Plugin.balanceOf(user2), 0, "User2 shares");
        assertEq(erc4626Plugin.totalSupply(), _toShares(toDeposit / 2) - _toShares(WITHDRAW_MARGIN), "Total supply");
        assertEq(erc4626Plugin.totalAssets(), toDeposit / 2 + WITHDRAW_MARGIN, "Total assets");
        assertEq(
            underlyingAsset.balanceOf(address(erc4626Plugin)),
            WITHDRAW_MARGIN * 2,
            "Withdrawal margin remained on plugin"
        );
    }
}

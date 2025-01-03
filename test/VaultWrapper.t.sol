// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {ISwapper, SwapArgs} from "src/interfaces/ISwapper.sol";
import {IWETH} from "src/interfaces/external/weth/IWETH.sol";

import {MockExchange, Quote} from "./MockExchange.sol";
import {Utils} from "./Utils.sol";
import {VaultWrapper} from "src/VaultWrapper.sol";
import {WETH9} from "./WETH9.sol";
import {MockToken} from "./MockToken.sol";

contract VaultWrapperTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant user = address(0x02);
    address constant yieldExtractor = address(0x04);
    uint256 constant yieldProjectId = 0;
    uint256 constant projectId = 1;

    IYelayLiteVault yelayLiteVaultEth;
    IYelayLiteVault yelayLiteVaultUsdc;

    VaultWrapper vaultWrapper;

    IERC20 usdc;
    IERC20 weth;

    MockExchange mockExchange;

    function setUp() external {
        usdc = IERC20(address(new MockToken("USDC", "USDC", 6)));
        weth = IERC20(address(new WETH9()));
        vm.startPrank(owner);
        yelayLiteVaultEth =
            Utils.deployDiamond(owner, address(weth), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        yelayLiteVaultUsdc =
            Utils.deployDiamond(owner, address(usdc), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        address vaultWrapperImpl =
            address(new VaultWrapper(IWETH(address(weth)), ISwapper(yelayLiteVaultEth.swapper())));
        vaultWrapper = VaultWrapper(
            payable(
                new ERC1967Proxy(
                    address(vaultWrapperImpl), abi.encodeWithSelector(VaultWrapper.initialize.selector, owner)
                )
            )
        );

        mockExchange = new MockExchange();
        Utils.addExchange(yelayLiteVaultEth, address(mockExchange));
        Utils.addExchange(yelayLiteVaultUsdc, address(mockExchange));
        vm.stopPrank();

        deal(user, 100 ether);
        deal(address(usdc), user, 10000e6);
    }

    function test_wrapEthAndDeposit() external {
        uint256 userEtherBalance = user.balance;
        vm.startPrank(user);
        vaultWrapper.wrapEthAndDeposit{value: 1 ether}(address(yelayLiteVaultEth), 1);
        vm.stopPrank();

        assertEq(weth.balanceOf(address(yelayLiteVaultEth)), 1 ether);
        assertEq(yelayLiteVaultEth.totalAssets(), 1 ether);
        assertEq(yelayLiteVaultEth.totalSupply(), 1 ether);
        assertEq(yelayLiteVaultEth.balanceOf(user, 1), 1 ether);
        assertEq(user.balance, userEtherBalance - 1 ether);
        assertEq(weth.balanceOf(address(vaultWrapper)), 0);
        assertEq(address(vaultWrapper).balance, 0);
    }

    function test_swapAndDeposit_usdc_to_weth() external {
        uint256 userUsdcBalance = usdc.balanceOf(user);

        deal(address(usdc), address(mockExchange), 1000e18);
        deal(address(weth), address(mockExchange), 1000e18);
        mockExchange.setQuote(address(weth), address(usdc), Quote({fromAmount: 1 ether, toAmount: 3339e6}));

        vm.startPrank(user);
        usdc.approve(address(vaultWrapper), 10000e6);
        SwapArgs[] memory swapArgs = new SwapArgs[](1);
        swapArgs[0] = SwapArgs({
            tokenIn: address(usdc),
            swapTarget: address(mockExchange),
            swapCallData: abi.encodeWithSelector(MockExchange.swap.selector, address(usdc), address(weth), 3339e6)
        });
        vaultWrapper.swapAndDeposit(address(yelayLiteVaultEth), 1, swapArgs, 3400e6);

        assertEq(usdc.balanceOf(user), userUsdcBalance - 3339e6);
        assertEq(weth.balanceOf(address(yelayLiteVaultEth)), 1 ether);
        assertEq(yelayLiteVaultEth.totalAssets(), 1 ether);
        assertEq(yelayLiteVaultEth.totalSupply(), 1 ether);
        assertEq(yelayLiteVaultEth.balanceOf(user, 1), 1 ether);
        assertEq(usdc.balanceOf(address(vaultWrapper)), 0);
        assertEq(weth.balanceOf(address(vaultWrapper)), 0);
    }

    function test_swapAndDeposit_eth_to_usdc() external {
        uint256 userEthBalance = user.balance;

        deal(address(usdc), address(mockExchange), 1000e18);
        deal(address(weth), address(mockExchange), 1000e18);
        mockExchange.setQuote(address(weth), address(usdc), Quote({fromAmount: 1 ether, toAmount: 1000e6}));

        vm.startPrank(user);
        SwapArgs[] memory swapArgs = new SwapArgs[](1);
        swapArgs[0] = SwapArgs({
            tokenIn: address(weth),
            swapTarget: address(mockExchange),
            swapCallData: abi.encodeWithSelector(MockExchange.swap.selector, address(weth), address(usdc), 0.9 ether)
        });
        vaultWrapper.swapAndDeposit{value: 1 ether}(address(yelayLiteVaultUsdc), 1, swapArgs, 0);

        assertEq(user.balance, userEthBalance - 0.9 ether);
        assertEq(usdc.balanceOf(address(yelayLiteVaultUsdc)), 900e6);
        assertEq(yelayLiteVaultUsdc.totalAssets(), 900e6);
        assertEq(yelayLiteVaultUsdc.totalSupply(), 900e6);
        assertEq(yelayLiteVaultUsdc.balanceOf(user, 1), 900e6);
        assertEq(usdc.balanceOf(address(vaultWrapper)), 0);
        assertEq(weth.balanceOf(address(vaultWrapper)), 0);
    }
}

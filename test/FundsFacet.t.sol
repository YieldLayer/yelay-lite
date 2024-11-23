// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

import {IPool} from "src/interfaces/external/aave/v3/IPool.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {TokenFacet, ERC1155Upgradeable} from "src/facets/TokenFacet.sol";
import {FundsFacet} from "src/facets/FundsFacet.sol";
import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {YelayLiteVaultInit} from "src/YelayLiteVaultInit.sol";
import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";

import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract FundsFacetTest is Test {
    using Utils for address;

    address owner = address(0x01);
    address user = address(0x02);
    address yieldExtractor = address(0x04);

    address yelayLiteVault;
    DiamondCutFacet diamondCutFacet;
    TokenFacet tokenFacet;
    FundsFacet fundsFacet;
    ManagementFacet managementFacet;

    MockToken underlyingAsset;
    YelayLiteVaultInit init;

    uint256 projectId = 1;

    function setUp() external {
        vm.startPrank(owner);
        diamondCutFacet = new DiamondCutFacet();
        yelayLiteVault = address(new YelayLiteVault(owner, address(diamondCutFacet)));
        tokenFacet = new TokenFacet();
        fundsFacet = new FundsFacet();
        managementFacet = new ManagementFacet();
        init = new YelayLiteVaultInit();
        underlyingAsset = new MockToken("DAI", "DAI", 18);

        yelayLiteVault.addTokenFacet(init, tokenFacet, "https://yelay-lite-vault/{id}.json");
        yelayLiteVault.addFundsFacet(init, fundsFacet, address(underlyingAsset), yieldExtractor);
        yelayLiteVault.addManagementFacet(managementFacet);
        vm.stopPrank();

        vm.startPrank(user);
        underlyingAsset.approve(yelayLiteVault, type(uint256).max);
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
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), 0);

        vm.startPrank(user);
        FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance - toDeposit);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), toDeposit);
        assertEq(FundsFacet(yelayLiteVault).totalAssets(), toDeposit);
        assertEq(TokenFacet(yelayLiteVault).totalSupply(), toDeposit);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), toDeposit);
    }

    function test_withdraw_with_no_strategy() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        vm.startPrank(user);
        FundsFacet(yelayLiteVault).deposit(toDeposit, projectId, user);
        FundsFacet(yelayLiteVault).redeem(toDeposit, projectId, user);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);
        assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user, projectId), 0);
    }
}

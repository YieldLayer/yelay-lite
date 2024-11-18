// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {TokenFacet} from "src/facets/TokenFacet.sol";
import {FundsFacet, ERC20} from "src/facets/FundsFacet.sol";

import {Utils} from "./Utils.sol";
import {DAI_ADDRESS, MAINNET_BLOCK_NUMBER} from "./Constants.sol";

contract FundsFacetTest is Test {
    using Utils for address;

    address owner = address(0x01);
    address user = address(0x02);

    address yelayLiteVault;
    DiamondCutFacet diamondCutFacet;
    TokenFacet tokenFacet;
    FundsFacet fundsFacet;
    ERC20 underlyingAsset = ERC20(DAI_ADDRESS);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_URL"), MAINNET_BLOCK_NUMBER);

        vm.startPrank(owner);
        diamondCutFacet = new DiamondCutFacet();
        yelayLiteVault = address(new YelayLiteVault(owner, address(diamondCutFacet)));
        tokenFacet = new TokenFacet();
        fundsFacet = new FundsFacet();

        yelayLiteVault.addTokenFacet(tokenFacet, "Yelay DAI Vault", "YLAY-DAI");
        yelayLiteVault.addFundsFacet(fundsFacet, address(underlyingAsset));
        vm.stopPrank();
    }

    function test_deposit() external {
        uint256 userBalance = 10_000e18;
        uint256 toDeposit = 1000e18;
        deal(address(underlyingAsset), user, userBalance);

        assertEq(underlyingAsset.balanceOf(user), userBalance);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), 0);

        assertEq(TokenFacet(yelayLiteVault).totalSupply(), 0);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user), 0);

        vm.startPrank(user);
        underlyingAsset.approve(yelayLiteVault, type(uint256).max);
        FundsFacet(yelayLiteVault).deposit(user, toDeposit);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(user), userBalance - toDeposit);
        assertEq(underlyingAsset.balanceOf(yelayLiteVault), toDeposit);

        assertEq(TokenFacet(yelayLiteVault).totalSupply(), toDeposit);
        assertEq(TokenFacet(yelayLiteVault).balanceOf(user), toDeposit);
    }
}

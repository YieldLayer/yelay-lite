// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {TokenFacet} from "src/facets/TokenFacet.sol";

import {Utils} from "./Utils.sol";

contract TokenFacetTest is Test {
    using Utils for address;

    address owner = address(0x01);

    address yelayLiteVault;
    DiamondCutFacet diamondCutFacet;
    TokenFacet tokenFacet;

    function setUp() external {
        vm.startPrank(owner);
        diamondCutFacet = new DiamondCutFacet();
        yelayLiteVault = address(new YelayLiteVault(owner, address(diamondCutFacet)));
        tokenFacet = new TokenFacet();
        vm.stopPrank();
    }

    function test_addTokenFacet() external {
        string memory name = "Yelay Lite USDC";
        string memory symbol = "Yelay Lite USDC";

        vm.startPrank(owner);
        yelayLiteVault.addTokenFacet(tokenFacet, name, symbol);
        vm.stopPrank();

        assertEq(TokenFacet(yelayLiteVault).name(), name);
        assertEq(TokenFacet(yelayLiteVault).symbol(), symbol);
    }
}

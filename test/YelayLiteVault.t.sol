// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract YelayLiteVaultTest is Test {
    address constant owner = address(0x01);
    address constant yieldExtractor = address(0x02);
    string constant uri = "https://yelay-lite-vault/{id}.json";

    function test_addTokenFacet() external {
        address underlyingAsset = address(new MockToken("Y-Test", "Y-T", 18));

        vm.startPrank(owner);
        IYelayLiteVault yelayLiteVault = Utils.deployDiamond(owner, underlyingAsset, yieldExtractor, uri);
        vm.stopPrank();

        assertEq(yelayLiteVault.underlyingAsset(), underlyingAsset);
        assertEq(yelayLiteVault.yieldExtractor(), yieldExtractor);
        assertEq(yelayLiteVault.owner(), owner);
        assertEq(yelayLiteVault.uri(0), uri);
    }
}

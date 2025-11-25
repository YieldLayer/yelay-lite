// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";

import {MockToken, ERC20} from "test/mocks/MockToken.sol";
import {Utils} from "test/Utils.sol";

contract YelayLiteVaultTest is Test {
    address constant owner = address(0x01);
    address constant yieldExtractor = address(0x02);
    string constant uri = "https://yelay-lite-vault/{id}.json";

    function test_facets() external {
        address underlyingAsset = address(new MockToken("Y-Test", "Y-T", 18));

        vm.startPrank(owner);
        IYelayLiteVault yelayLiteVault = Utils.deployDiamond(owner, underlyingAsset, yieldExtractor, uri);
        vm.stopPrank();

        assertEq(yelayLiteVault.underlyingAsset(), underlyingAsset);
        assertEq(yelayLiteVault.yieldExtractor(), yieldExtractor);
        assertEq(yelayLiteVault.owner(), owner);
        assertEq(yelayLiteVault.uri(0), uri);
        vm.expectRevert(
            abi.encodeWithSelector(LibErrors.InvalidSelector.selector, bytes4(keccak256("balanceOf(address)")))
        );
        ERC20(address(yelayLiteVault)).balanceOf(address(this));
    }
}

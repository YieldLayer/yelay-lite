// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";

import {ClientsFacet} from "src/facets/ClientsFacet.sol";

import {MockStrategy} from "./MockStrategy.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

contract ClientsFacetTest is Test {
    using Utils for address;

    address constant owner = address(0x01);
    address constant yieldExtractor = address(0x02);
    address constant user = address(0x03);
    address constant client = address(0x04);

    IYelayLiteVault yelayLiteVault;

    MockToken underlyingAsset;

    function setUp() external {
        vm.startPrank(owner);
        underlyingAsset = new MockToken("Y-Test", "Y-T", 18);
        yelayLiteVault =
            Utils.deployDiamond(owner, address(underlyingAsset), yieldExtractor, "https://yelay-lite-vault/{id}.json");
        vm.stopPrank();
    }

    function test_createClient() external {
        vm.startPrank(client);
        vm.expectRevert();
        yelayLiteVault.createClient(client, 0, 1, "test");
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert();
        yelayLiteVault.createClient(client, 0, 1, "test");
        vm.stopPrank();
    }
}

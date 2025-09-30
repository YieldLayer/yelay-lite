// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ERC4626PluginFactory} from "src/plugins/ERC4626PluginFactory.sol";
import {ERC4626Plugin} from "src/plugins/ERC4626Plugin.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {MockYieldExtractor} from "test/mocks/MockYieldExtractor.sol";
import {MockToken} from "test/mocks/MockToken.sol";
import {Utils} from "test/Utils.sol";

contract ERC4626PluginTest is Test {
    ERC4626Plugin erc4626Plugin;
    MockYieldExtractor yieldExtractor;
    IYelayLiteVault yelayLiteVault;
    MockToken underlying;

    string constant PLUGIN_SYMBOL = "TP";
    string constant PLUGIN_NAME = "TestPlugin";
    uint256 constant PROJECT_ID = 33;
    bytes32 constant SALT = keccak256("test-salt");
    string constant URI = "https://yelay-lite-vault/{id}.json";

    function setUp() public {
        underlying = new MockToken("Underlying", "UND", 18);

        yieldExtractor = new MockYieldExtractor();

        yelayLiteVault = Utils.deployDiamond(address(this), address(underlying), address(yieldExtractor), URI);

        ERC4626PluginFactory factory =
            new ERC4626PluginFactory(address(this), address(new ERC4626Plugin(address(yieldExtractor))));

        erc4626Plugin = factory.deploy(PLUGIN_NAME, PLUGIN_SYMBOL, address(yelayLiteVault), PROJECT_ID);
    }

    function test_some() external {}
}

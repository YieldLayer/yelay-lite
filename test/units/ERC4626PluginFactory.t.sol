// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import {ERC4626PluginFactory} from "src/plugins/ERC4626PluginFactory.sol";
import {ERC4626Plugin} from "src/plugins/ERC4626Plugin.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {MockToken} from "test/mocks/MockToken.sol";
import {Utils} from "test/Utils.sol";

contract ERC4626PluginFactoryTest is Test {
    ERC4626PluginFactory public factory;
    ERC4626Plugin public pluginImplementation;
    YieldExtractor public yieldExtractor;
    IYelayLiteVault public mockVault;
    MockToken public underlying;

    address public owner = address(0x1111);
    address public nonOwner = address(0x2222);
    address public yieldExtractorAddress = address(0x3333);

    string public constant PLUGIN_NAME = "TestPlugin";
    string public constant PLUGIN_SYMBOL = "TP";
    uint256 public constant PROJECT_ID = 123;
    bytes32 public constant SALT = keccak256("test-salt");
    string public constant URI = "https://yelay-lite-vault/{id}.json";

    function setUp() public {
        // Deploy underlying asset
        underlying = new MockToken("Underlying", "UND", 18);

        // Deploy mock vault using Utils
        vm.startPrank(owner);
        mockVault = Utils.deployDiamond(owner, address(underlying), yieldExtractorAddress, URI);
        mockVault.activateProject(PROJECT_ID);
        vm.stopPrank();

        // Deploy yield extractor (need actual implementation for plugin initialization)
        YieldExtractor yieldExtractorImpl = new YieldExtractor();
        yieldExtractor = YieldExtractor(
            address(
                new ERC1967Proxy(
                    address(yieldExtractorImpl),
                    abi.encodeWithSelector(YieldExtractor.initialize.selector, owner, owner)
                )
            )
        );

        // Deploy ERC4626Plugin implementation
        pluginImplementation = new ERC4626Plugin(yieldExtractor);

        // Deploy factory with owner and implementation
        factory = new ERC4626PluginFactory(owner, address(pluginImplementation));
    }

    // Constructor Tests
    function test_constructor_setsOwnerAndImplementation() public view {
        // Check owner is set correctly
        assertEq(factory.owner(), owner);

        // Check implementation is set correctly
        assertEq(factory.implementation(), address(pluginImplementation));
    }

    function test_constructor_withZeroOwner() public {
        vm.expectRevert();
        new ERC4626PluginFactory(address(0), address(pluginImplementation));
    }

    function test_constructor_withZeroImplementation() public {
        vm.expectRevert();
        new ERC4626PluginFactory(owner, address(0));
    }

    // Deploy Function Tests
    function test_deploy_success() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, false);
        emit LibEvents.ERC4626PluginDeployed(address(0)); // We don't know the exact address

        ERC4626Plugin plugin = factory.deploy(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID);

        // Verify plugin was deployed correctly
        assertTrue(address(plugin) != address(0));
        assertEq(plugin.name(), PLUGIN_NAME);
        assertEq(plugin.symbol(), PLUGIN_SYMBOL);
        assertEq(address(plugin.yelayLiteVault()), address(mockVault));
        assertEq(plugin.projectId(), PROJECT_ID);
        assertEq(address(plugin.asset()), address(underlying));
    }

    function test_deploy_onlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        factory.deploy(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID);
    }

    // Deterministic Deploy Function Tests
    function test_deployDeterministically_success() public {
        address predictedAddress =
            factory.predictDeterministicAddress(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID, SALT);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.ERC4626PluginDeployed(predictedAddress);

        ERC4626Plugin plugin =
            factory.deployDeterministically(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID, SALT);

        // Verify plugin was deployed correctly
        assertTrue(address(plugin) != address(0));
        assertEq(plugin.name(), PLUGIN_NAME);
        assertEq(plugin.symbol(), PLUGIN_SYMBOL);
        assertEq(address(plugin.yelayLiteVault()), address(mockVault));
        assertEq(plugin.projectId(), PROJECT_ID);
        assertEq(address(plugin.asset()), address(underlying));

        // Addresses should match
        assertEq(predictedAddress, address(plugin));
    }

    function test_deployDeterministically_onlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        factory.deployDeterministically(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID, SALT);
    }

    function test_deployDeterministically_sameSaltTwice() public {
        vm.startPrank(owner);

        // First deployment should succeed
        factory.deployDeterministically(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID, SALT);

        // Second deployment with same salt should fail
        vm.expectRevert();
        factory.deployDeterministically(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID, SALT);

        vm.stopPrank();
    }

    function test_deployDeterministically_differentSalts() public {
        vm.startPrank(owner);

        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");

        ERC4626Plugin plugin1 =
            factory.deployDeterministically(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID, salt1);

        ERC4626Plugin plugin2 =
            factory.deployDeterministically(PLUGIN_NAME, PLUGIN_SYMBOL, address(mockVault), PROJECT_ID, salt2);

        // Different salts should produce different addresses
        assertTrue(address(plugin1) != address(plugin2));

        vm.stopPrank();
    }

    function test_factory_canUpgradeImplementation() public {
        // Deploy new implementation
        ERC4626Plugin newImplementation = new ERC4626Plugin(yieldExtractor);

        // Upgrade implementation
        vm.prank(owner);
        factory.upgradeTo(address(newImplementation));

        // Check new implementation is set
        assertEq(factory.implementation(), address(newImplementation));
    }

    function test_factory_upgradeOnlyOwner() public {
        ERC4626Plugin newImplementation = new ERC4626Plugin(yieldExtractor);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        factory.upgradeTo(address(newImplementation));
    }
}

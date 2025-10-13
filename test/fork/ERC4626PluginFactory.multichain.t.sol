// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC4626PluginFactory} from "src/plugins/ERC4626PluginFactory.sol";
import {ERC4626Plugin} from "src/plugins/ERC4626Plugin.sol";

/**
 * @title ERC4626PluginFactory Multichain Test Suite
 * @notice Comprehensive test suite for ERC4626PluginFactory across multiple chains
 * @dev This test suite validates CREATE3 deployment functionality across:
 *      - Mainnet, Base, Arbitrum, Avalanche, Sonic
 */

// -----------------------------------------------------------------------------
// A new implementation contract for upgrade testing.
// This contract inherits from ERC4626Plugin and adds an extra function.
// -----------------------------------------------------------------------------
contract ERC4626PluginV2 is ERC4626Plugin {
    constructor(address _yieldExtractor) ERC4626Plugin(_yieldExtractor) {}
    
    function version() external pure returns (uint256) {
        return 2;
    }
}

contract ERC4626PluginFactoryMultichainTest is Test {
    struct ChainConfig {
        string name;
        string rpcUrl;
        uint256 blockNumber;
        address vaultAddress;
        address yieldExtractor;
    }

    address public constant OWNER = address(0x1111);
    address public constant DEPLOYMENT_PROXY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    string public constant PLUGIN_NAME = "TestPlugin";
    string public constant PLUGIN_SYMBOL = "TP";
    uint256 public constant PROJECT_ID = 123;
    bytes32 public constant TEST_SALT = keccak256("multichain-test-salt");

    ChainConfig[] public chainConfigs;

    function setUp() public {
        chainConfigs.push(ChainConfig({
            name: "mainnet",
            rpcUrl: vm.envString("MAINNET_URL"),
            blockNumber: 23555798,
            vaultAddress: 0x39DAc87bE293DC855b60feDd89667364865378cc,
            yieldExtractor: 0x226239384EB7d78Cdf279BA6Fb458E2A4945E275
        }));

        chainConfigs.push(ChainConfig({
            name: "base",
            rpcUrl: vm.envString("BASE_URL"),
            blockNumber: 36706133,
            vaultAddress: 0x0c6dAf9B4e0EB49A0c80c325da82EC028Cb8118B,
            yieldExtractor: 0x4D6A89dc55d8bACC0cbC3824BD7e44fa051c3958
        }));

        chainConfigs.push(ChainConfig({
            name: "arbitrum",
            rpcUrl: vm.envString("ARBITRUM_URL"),
            blockNumber: 388466669,
            vaultAddress: 0x2e988479F14Ff61586F8Fd0F09E8720484Eb6030,
            yieldExtractor: 0x79b7e90F1BAe837362DBD2c83Bd0715c2De5E47f
        }));

        chainConfigs.push(ChainConfig({
            name: "avalanche",
            rpcUrl: vm.envString("AVALANCHE_URL"),
            blockNumber: 70146443,
            vaultAddress: 0x90b8695EDCdEfAFA678Df6d819307573f7B1a18C,
            yieldExtractor: 0x98732e2FEb854bAd400D4b5336f4439E7E53fe88
        }));

        chainConfigs.push(ChainConfig({
            name: "sonic",
            rpcUrl: vm.envString("SONIC_URL"),
            blockNumber: 50212587,
            vaultAddress: 0x56b0c5C989C65e712463278976ED26D6e07592ab,
            yieldExtractor: 0xB84B621D3da3E5e47A1927883C685455Ad731D7C
        }));
    }

    function _deployFactoryForChain(ChainConfig memory config) internal returns (
        ERC4626PluginFactory factory,
        ERC4626Plugin pluginImplementation
    ) {
        vm.createSelectFork(config.rpcUrl, config.blockNumber);
        
        // Deploy dummy implementation first (deterministic)
        // Use different deployer per chain to show deterministic deployment works regardless of nonce
        address dummyDeployer = address(uint160(uint256(keccak256(abi.encodePacked("dummy", config.name)))));
        bytes32 dummyImplSalt = keccak256("ERC4626Plugin-Dummy-Implementation");
        bytes memory dummyImplInitCode = abi.encodePacked(
            type(ERC4626Plugin).creationCode,
            abi.encode(address(0)) // zero address for yield extractor
        );
        
        vm.prank(dummyDeployer);
        (bool success,) = DEPLOYMENT_PROXY.call(
            abi.encodePacked(dummyImplSalt, dummyImplInitCode)
        );
        require(success, "Dummy implementation deployment failed");
        
        address dummyImplAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            DEPLOYMENT_PROXY,
            dummyImplSalt,
            keccak256(dummyImplInitCode)
        )))));
        
        // Deploy factory with dummy implementation (deterministic)
        // Use different deployer per chain to show deterministic deployment works regardless of nonce
        address factoryDeployer = address(uint160(uint256(keccak256(abi.encodePacked("factory", config.name)))));
        bytes32 factorySalt = keccak256("ERC4626PluginFactory-v1.0.0");
        bytes memory factoryInitCode = abi.encodePacked(
            type(ERC4626PluginFactory).creationCode,
            abi.encode(OWNER, dummyImplAddress)
        );
        
        vm.prank(factoryDeployer);
        (success,) = DEPLOYMENT_PROXY.call(
            abi.encodePacked(factorySalt, factoryInitCode)
        );
        require(success, "Factory deployment failed");
        
        address factoryAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            DEPLOYMENT_PROXY,
            factorySalt,
            keccak256(factoryInitCode)
        )))));
        factory = ERC4626PluginFactory(factoryAddress);
        
        // Deploy implementation normally (different addresses per chain)
        // Use different deployer per chain to get different addresses (simulate different nonce)
        address implDeployer = address(uint160(uint256(keccak256(abi.encodePacked("impl", config.name)))));
        vm.prank(implDeployer);
        pluginImplementation = new ERC4626Plugin(address(config.yieldExtractor));
        
        // Upgrade factory to use the implementation
        vm.prank(OWNER);
        factory.upgradeTo(address(pluginImplementation));
    }

    function test_deployDeterministically_acrossAllChains() public {
        address[] memory factoryAddresses = new address[](chainConfigs.length);
        address[] memory pluginAddresses = new address[](chainConfigs.length);
        
        for (uint256 i = 0; i < chainConfigs.length; i++) {
            ChainConfig memory config = chainConfigs[i];
            (
                ERC4626PluginFactory factory,
            ) = _deployFactoryForChain(config);

            // Test CREATE3 deployment
            vm.prank(OWNER);
            ERC4626Plugin plugin = factory.deployDeterministically(
                PLUGIN_NAME,
                PLUGIN_SYMBOL,
                address(config.vaultAddress),
                PROJECT_ID,
                TEST_SALT
            );

            // Verify deployment
            assertEq(plugin.name(), PLUGIN_NAME);
            assertEq(plugin.symbol(), PLUGIN_SYMBOL);
            assertEq(address(plugin.yelayLiteVault()), address(config.vaultAddress));
            assertEq(plugin.projectId(), PROJECT_ID);

            // Store factory and plugin addresses for verification
            factoryAddresses[i] = address(factory);
            pluginAddresses[i] = address(plugin);
        }

        // Verify that all factory deployments have the same address
        for (uint256 i = 1; i < factoryAddresses.length; i++) {
            assertEq(factoryAddresses[i], factoryAddresses[0], "Factory addresses should be identical across chains");
        }
        
        // Verify that all plugin deployments have the same predicted address
        for (uint256 i = 0; i < pluginAddresses.length; i++) {
            assertEq(pluginAddresses[i], pluginAddresses[0], "Plugin addresses should be identical across chains");
        }
    }

    function test_upgradeTo_acrossAllChains() public {
        for (uint256 i = 0; i < chainConfigs.length; i++) {
            ChainConfig memory config = chainConfigs[i];
            
            (
                ERC4626PluginFactory factory,
                ERC4626Plugin pluginImplementation
            ) = _deployFactoryForChain(config);

            vm.prank(OWNER);
            ERC4626Plugin plugin = factory.deployDeterministically(
                PLUGIN_NAME,
                PLUGIN_SYMBOL,
                address(config.vaultAddress),
                PROJECT_ID,
                TEST_SALT
            );

            // Verify initial implementation
            assertEq(factory.implementation(), address(pluginImplementation));
            vm.expectRevert();
            ERC4626PluginV2(address(plugin)).version();

            // Upgrade implementation to V2
            ERC4626PluginV2 newImplementation = new ERC4626PluginV2(address(0x3333));
            vm.prank(OWNER);
            factory.upgradeTo(address(newImplementation));

            // Check new implementation is set in factory
            assertEq(factory.implementation(), address(newImplementation));

            // Verify plugin now uses new implementation
            uint256 version = ERC4626PluginV2(address(plugin)).version();
            assertEq(version, 2);
        }
    }
}

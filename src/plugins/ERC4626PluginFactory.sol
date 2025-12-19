// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {CREATE3} from "@solady/utils/CREATE3.sol";

import {ERC4626Plugin} from "./ERC4626Plugin.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

/**
 * @title ERC4626PluginFactory
 * @notice Factory contract for deploying ERC4626Plugin instances using beacon proxy pattern
 * @dev This factory uses the beacon proxy pattern to enable efficient deployment of multiple
 *      ERC4626Plugin instances that share the same implementation. This allows for gas-efficient
 *      deployments and streamlined upgradeability.
 */
contract ERC4626PluginFactory is UpgradeableBeacon {
    // ============ Constructor ============

    /**
     * @notice Initializes the factory with the implementation and owner
     * @param owner The address that will own this factory contract
     * @param implementation The address of the ERC4626Plugin implementation contract
     * @dev The implementation contract serves as the beacon for all deployed plugin instances
     */
    constructor(address owner, address implementation) UpgradeableBeacon(implementation, owner) {}

    // ============ Deployment Functions ============

    /**
     * @notice Deploys a new ERC4626Plugin instance
     * @param name The name of the ERC20 token for the plugin
     * @param symbol The symbol of the ERC20 token for the plugin
     * @param yelayLiteVault The address of the YelayLiteVault contract
     * @param projectId The project ID within the YelayLiteVault system
     * @return plugin The deployed ERC4626Plugin instance
     * @dev Only the owner can deploy new plugin instances
     */
    function deploy(string memory name, string memory symbol, address yelayLiteVault, uint256 projectId)
        external
        onlyOwner
        returns (ERC4626Plugin)
    {
        address erc4626Plugin = address(
            new BeaconProxy(address(this), _encodeInitializationCalldata(name, symbol, yelayLiteVault, projectId))
        );

        emit LibEvents.ERC4626PluginDeployed(erc4626Plugin);

        return ERC4626Plugin(erc4626Plugin);
    }

    /**
     * @notice Deploys a new ERC4626Plugin instance deterministically using CREATE3
     * @param name The name of the ERC20 token for the plugin
     * @param symbol The symbol of the ERC20 token for the plugin
     * @param yelayLiteVault The address of the YelayLiteVault contract
     * @param projectId The project ID within the YelayLiteVault system
     * @param salt The salt for deterministic deployment
     * @return plugin The deployed ERC4626Plugin instance
     * @dev Only the owner can deploy new plugin instances. The salt must be unique for each deployment
     */
    function deployDeterministically(
        string memory name,
        string memory symbol,
        address yelayLiteVault,
        uint256 projectId,
        bytes32 salt
    ) external onlyOwner returns (ERC4626Plugin) {
        bytes memory beaconProxyBytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(address(this), _encodeInitializationCalldata(name, symbol, yelayLiteVault, projectId))
        );

        address erc4626Plugin = CREATE3.deployDeterministic(beaconProxyBytecode, salt);

        emit LibEvents.ERC4626PluginDeployed(erc4626Plugin);

        return ERC4626Plugin(erc4626Plugin);
    }

    // ============ View Functions ============

    /**
     * @notice Predicts the address where a plugin will be deployed deterministically
     * @param salt The salt for deterministic deployment
     * @return predictedAddress The predicted address of the plugin
     * @dev This function uses CREATE3 address prediction algorithm
     */
    function predictDeterministicAddress(bytes32 salt) external view returns (address) {
        return CREATE3.predictDeterministicAddress(salt);
    }

    // ============ Internal Functions ============

    /**
     * @notice Encodes the initialization calldata for the ERC4626Plugin
     * @param name The name of the ERC20 token
     * @param symbol The symbol of the ERC20 token
     * @param yelayLiteVault The address of the YelayLiteVault contract
     * @param projectId The project ID within the YelayLiteVault system
     * @return calldata The encoded initialization calldata
     * @dev This function creates the calldata needed to initialize the deployed plugin
     */
    function _encodeInitializationCalldata(
        string memory name,
        string memory symbol,
        address yelayLiteVault,
        uint256 projectId
    ) private pure returns (bytes memory) {
        return abi.encodeWithSelector(ERC4626Plugin.initialize.selector, name, symbol, yelayLiteVault, projectId);
    }
}

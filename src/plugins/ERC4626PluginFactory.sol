// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {ERC4626Plugin} from "./ERC4626Plugin.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

contract ERC4626PluginFactory is UpgradeableBeacon {
    constructor(address owner, address implementation) UpgradeableBeacon(implementation, owner) {}

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

    function deployDeterministically(
        string memory name,
        string memory symbol,
        address yelayLiteVault,
        uint256 projectId,
        bytes32 salt
    ) external onlyOwner returns (ERC4626Plugin) {
        address erc4626Plugin = address(
            new BeaconProxy{salt: salt}(
                address(this), _encodeInitializationCalldata(name, symbol, yelayLiteVault, projectId)
            )
        );

        emit LibEvents.ERC4626PluginDeployed(erc4626Plugin);

        return ERC4626Plugin(erc4626Plugin);
    }

    function predictDeterministicAddress(
        string memory name,
        string memory symbol,
        address yelayLiteVault,
        uint256 projectId,
        bytes32 salt
    ) external view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(BeaconProxy).creationCode,
                                    abi.encode(
                                        address(this),
                                        _encodeInitializationCalldata(name, symbol, yelayLiteVault, projectId)
                                    )
                                )
                            )
                        )
                    )
                )
            )
        );
    }

    function _encodeInitializationCalldata(
        string memory name,
        string memory symbol,
        address yelayLiteVault,
        uint256 projectId
    ) private pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "initialize(string,string,address,uint256)", name, symbol, yelayLiteVault, projectId
        );
    }
}

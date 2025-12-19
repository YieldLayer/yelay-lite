// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

contract YelayLiteDeployer is Ownable {
    constructor(address owner_) Ownable(owner_) {}

    function deploy(
        bytes32 salt,
        address _ownerFacet,
        address underlyingAsset,
        address yieldExtractor,
        string memory uri,
        address[] memory facets,
        bytes[] memory payloads
    ) external onlyOwner returns (address) {
        YelayLiteVault vault = YelayLiteVault(payable(Create2.deploy(0, salt, type(YelayLiteVault).creationCode)));
        vault.initialize(owner(), _ownerFacet, underlyingAsset, yieldExtractor, uri, facets, payloads);
        emit LibEvents.YelayLiteVaultDeployed(address(vault));
        return address(vault);
    }

    function computeAddress(bytes32 salt) external view returns (address) {
        return Create2.computeAddress(salt, keccak256(type(YelayLiteVault).creationCode));
    }
}

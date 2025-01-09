// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ClientsFacet} from "src/facets/ClientsFacet.sol";

struct ClientData {
    uint128 minProjectId;
    uint128 maxProjectId;
    bytes32 clientName;
}

library LibClients {
    /// @custom:storage-location erc7201:yelay-vault.storage.ClientsFacet
    struct ClientsStorage {
        uint256 lastProjectId;
        mapping(address => ClientData) ownerToClientData;
        mapping(bytes32 => bool) isClientNameTaken;
        mapping(uint256 => bytes32) projectIdToClientName;
        mapping(uint256 => bool) projectIdActive;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.ClientsFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ClientsStorageLocation = 0x78b8360ea116a1ac1aaf7d99dc2a2fa96091e5ce27ad9c46aa3a48ffec134800;

    function _getClientsStorage() internal pure returns (ClientsStorage storage $) {
        assembly {
            $.slot := ClientsStorageLocation
        }
    }

    /**
     * @dev Checks if a project is active.
     * @param projectId The ID of the project.
     * @return True if the project is active, false otherwise.
     */
    function _isProjectActive(uint256 projectId) internal view returns (bool) {
        ClientsStorage storage clientStorage = _getClientsStorage();
        return clientStorage.projectIdActive[projectId];
    }

    /**
     * @dev Checks if two project IDs belong to the same client.
     * @param projectId1 The first project ID.
     * @param projectId2 The second project ID.
     * @return True if both project IDs belong to the same client, false otherwise.
     */
    function _sameClient(uint256 projectId1, uint256 projectId2) internal view returns (bool) {
        ClientsStorage storage clientStorage = _getClientsStorage();
        return clientStorage.projectIdToClientName[projectId1] == clientStorage.projectIdToClientName[projectId2];
    }
}

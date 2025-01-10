// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ClientData} from "src/libraries/LibClients.sol";

interface IClientsFacet {
    /**
     * @dev Creates a new client with the specified parameters.
     * @param clientOwner The address of the client owner.
     * @param reservedProjects The number of projects reserved for the client.
     * @param clientName The name of the client.
     */
    function createClient(address clientOwner, uint128 reservedProjects, bytes32 clientName) external;

    /**
     * @dev Transfers the ownership of the client to a new owner.
     * @param newClientOwner The address of the new client owner.
     */
    function transferClientOwnership(address newClientOwner) external;

    /**
     * @dev Activates a project for the client.
     * @param projectId The ID of the project to activate.
     */
    function activateProject(uint256 projectId) external;

    /**
     * @dev Returns the last project ID.
     * @return The last project ID.
     */
    function lastProjectId() external view returns (uint256);

    /**
     * @dev Checks if a client name is taken.
     * @param clientName The name of the client.
     * @return True if the client name is taken, false otherwise.
     */
    function isClientNameTaken(bytes32 clientName) external view returns (bool);

    /**
     * @dev Returns the client data for a given owner.
     * @param owner The address of the client owner.
     * @return The client data.
     */
    function ownerToClientData(address owner) external view returns (ClientData memory);

    /**
     * @dev Returns the client name for a given project ID.
     * @param projectId The ID of the project.
     * @return The client name.
     */
    function projectIdToClientName(uint256 projectId) external view returns (bytes32);

    /**
     * @dev Checks if a project ID is active.
     * @param projectId The ID of the project.
     * @return True if the project ID is active, false otherwise.
     */
    function projectIdActive(uint256 projectId) external view returns (bool);
}

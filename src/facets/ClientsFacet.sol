// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {RoleCheck} from "src/abstract/RoleCheck.sol";
import {PausableCheck} from "src/abstract/PausableCheck.sol";
import {IClientsFacet} from "src/interfaces/IClientsFacet.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibClients, ClientData} from "src/libraries/LibClients.sol";

/**
 * @title ClientsFacet
 * @dev Contract that provides functionality to manage clients and allow them to manage their projects.
 */
contract ClientsFacet is PausableCheck, RoleCheck, IClientsFacet {
    /// @inheritdoc IClientsFacet
    function createClient(address clientOwner, uint128 reservedProjects, bytes32 clientName)
        external
        onlyRole(LibRoles.CLIENT_MANAGER)
    {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        require(clientStorage.ownerToClientData[clientOwner].minProjectId == 0, LibErrors.ClientOwnerReserved());
        require(reservedProjects > 0, LibErrors.ReservedProjectsIsZero());
        require(clientName != bytes32(0), LibErrors.ClientNameEmpty());
        require(clientStorage.isClientNameTaken[clientName] == false, LibErrors.ClientNameTaken());
        uint128 minProjectId = SafeCast.toUint128(clientStorage.lastProjectId + 1);
        uint128 maxProjectId = minProjectId + reservedProjects - 1;
        clientStorage.ownerToClientData[clientOwner] =
            ClientData({minProjectId: minProjectId, maxProjectId: maxProjectId, clientName: clientName});
        clientStorage.lastProjectId = maxProjectId;
        clientStorage.isClientNameTaken[clientName] = true;
        emit LibEvents.NewProjectIds(clientOwner, minProjectId, maxProjectId);
    }

    /// @inheritdoc IClientsFacet
    function transferClientOwnership(address newClientOwner) external notPaused {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        require(clientStorage.ownerToClientData[newClientOwner].minProjectId == 0, LibErrors.ClientOwnerReserved());
        ClientData memory clientData = clientStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId > 0, LibErrors.NotClientOwner());
        delete clientStorage.ownerToClientData[msg.sender];
        clientStorage.ownerToClientData[newClientOwner] = clientData;
        emit LibEvents.ClientOwnershipTransfer(clientData.clientName, msg.sender, newClientOwner);
    }

    /// @inheritdoc IClientsFacet
    function activateProject(uint256 projectId) external notPaused {
        _activateProject(msg.sender, projectId);
    }

    /// @inheritdoc IClientsFacet
    function activateProjectByManager(address client, uint256 projectId)
        external
        notPaused
        onlyRole(LibRoles.CLIENT_MANAGER)
    {
        _activateProject(client, projectId);
    }

    function _activateProject(address client, uint256 projectId) internal {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ClientData memory clientData = clientStorage.ownerToClientData[client];
        require(clientData.minProjectId > 0, LibErrors.NotClientOwner());
        require(
            clientData.minProjectId <= projectId && clientData.maxProjectId >= projectId,
            LibErrors.OutOfBoundProjectId()
        );
        require(clientStorage.projectIdActive[projectId] == false, LibErrors.ProjectActive());
        clientStorage.projectIdActive[projectId] = true;
        clientStorage.projectIdToClientName[projectId] = clientData.clientName;
        emit LibEvents.ProjectActivated(projectId);
    }

    /// @inheritdoc IClientsFacet
    function lastProjectId() external view returns (uint256) {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        return clientStorage.lastProjectId;
    }

    /// @inheritdoc IClientsFacet
    function isClientNameTaken(bytes32 clientName) external view returns (bool) {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        return clientStorage.isClientNameTaken[clientName];
    }

    /// @inheritdoc IClientsFacet
    function ownerToClientData(address owner) external view returns (ClientData memory) {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        return clientStorage.ownerToClientData[owner];
    }

    /// @inheritdoc IClientsFacet
    function projectIdToClientName(uint256 projectId) external view returns (bytes32) {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        return clientStorage.projectIdToClientName[projectId];
    }

    /// @inheritdoc IClientsFacet
    function projectIdActive(uint256 projectId) external view returns (bool) {
        return LibClients._isProjectActive(projectId);
    }
}

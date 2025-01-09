// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PausableCheck} from "src/abstract/PausableCheck.sol";
import {IClientsFacet} from "src/interfaces/IClientsFacet.sol";
import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibClients, ClientData} from "src/libraries/LibClients.sol";

/**
 * @title ClientsFacet
 * @dev Contract that provides functionality to manage clients and allow them to manage their projects.
 */
contract ClientsFacet is PausableCheck, IClientsFacet {
    /// @inheritdoc IClientsFacet
    function createClient(address clientOwner, uint128 minProjectId, uint128 maxProjectId, bytes32 clientName)
        external
    {
        LibOwner.onlyOwner();
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        require(minProjectId > 0, LibErrors.MinIsZero());
        require(maxProjectId > minProjectId, LibErrors.MaxLessThanMin());
        require(minProjectId > clientStorage.lastProjectId, LibErrors.MinLessThanLastProjectId());
        require(clientName != bytes32(0), LibErrors.ClientNameEmpty());
        require(clientStorage.isClientNameTaken[clientName] == false, LibErrors.ClientNameTaken());
        clientStorage.ownerToClientData[clientOwner] =
            ClientData({minProjectId: minProjectId, maxProjectId: maxProjectId, clientName: clientName});
        clientStorage.lastProjectId = maxProjectId;
        clientStorage.isClientNameTaken[clientName] = true;
        emit LibEvents.NewProjectIds(clientOwner, minProjectId, maxProjectId);
    }

    /// @inheritdoc IClientsFacet
    function transferClientOwnership(address newClientOwner) external notPaused {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ClientData memory clientData = clientStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId > 0, LibErrors.NotClientOwner());
        delete clientStorage.ownerToClientData[msg.sender];
        clientStorage.ownerToClientData[newClientOwner] = clientData;
        emit LibEvents.ClientOwnershipTransfer(clientData.clientName, msg.sender, newClientOwner);
    }

    /// @inheritdoc IClientsFacet
    function activateProject(uint256 projectId) external notPaused {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ClientData memory clientData = clientStorage.ownerToClientData[msg.sender];
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
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        return clientStorage.projectIdActive[projectId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SelfOnly} from "src/abstract/SelfOnly.sol";

import {IClientsFacet} from "src/interfaces/IClientsFacet.sol";

import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibClients, ClientData, LockConfig, ProjectInterceptor, UserLock} from "src/libraries/LibClients.sol";

// TODO: cover with tests
contract ClientsFacet is SelfOnly, IClientsFacet {
    function createClient(address clientOwner, uint128 minProjectId, uint128 maxProjectId, bytes32 clientName)
        external
    {
        LibOwner.onlyOwner();
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        require(minProjectId > 0, LibErrors.MinIsZero());
        require(maxProjectId > minProjectId, LibErrors.MaxLessThanMin());
        require(minProjectId > clientStorage.nextProjectId, LibErrors.MinLessThanNextProjectId());
        require(clientName != bytes32(0), LibErrors.ClientNameEmpty());
        require(clientStorage.clientNameTaken[clientName] == false, LibErrors.ClientNameIsTaken());
        clientStorage.ownerToClientData[clientOwner] =
            ClientData({minProjectId: minProjectId, maxProjectId: maxProjectId, clientName: clientName});
        clientStorage.nextProjectId = maxProjectId;
        clientStorage.clientNameTaken[clientName] = true;
        emit LibEvents.NewProjectIds(clientOwner, minProjectId, maxProjectId);
    }

    function transferClientOwnership(address newClientOwner) external {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ClientData memory clientData = clientStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId > 0, LibErrors.NotClientOwner());
        delete clientStorage.ownerToClientData[msg.sender];
        clientStorage.ownerToClientData[newClientOwner] = clientData;
        emit LibEvents.OwnershipTransferProjectIds(newClientOwner, clientData.minProjectId, clientData.maxProjectId);
    }

    function activateProject(uint256 projectId) external {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ClientData memory clientData = clientStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId <= projectId, LibErrors.OutOfBoundProjectId());
        require(clientData.maxProjectId >= projectId, LibErrors.OutOfBoundProjectId());
        require(clientStorage.projectIdActive[projectId] == false, LibErrors.ProjectIsActive());
        clientStorage.projectIdActive[projectId] = true;
        clientStorage.projectIdToClientName[projectId] = clientData.clientName;
        emit LibEvents.ProjectActivated(projectId);
    }

    function setProjectInterceptor(uint256 projectId, ProjectInterceptor projectInterceptor) external {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ClientData memory clientData = clientStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId <= projectId, LibErrors.OutOfBoundProjectId());
        require(clientData.maxProjectId >= projectId, LibErrors.OutOfBoundProjectId());
        require(projectInterceptor != ProjectInterceptor.None, LibErrors.ProjectInterceptorIsNone());
        require(
            clientStorage.projectIdToProjectInterceptor[projectId] == ProjectInterceptor.None,
            LibErrors.ProjectInterceptorIsSet()
        );
        clientStorage.projectIdToProjectInterceptor[projectId] = projectInterceptor;
        emit LibEvents.ProjectOptionSet(projectId, uint256(projectInterceptor));
    }

    // TODO: should we split interceptors to separate facets??
    function setLockConfig(uint256 projectId, LockConfig calldata lockConfig) external {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ClientData memory clientData = clientStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId <= projectId, LibErrors.OutOfBoundProjectId());
        require(clientData.maxProjectId >= projectId, LibErrors.OutOfBoundProjectId());
        require(
            clientStorage.projectIdToProjectInterceptor[projectId] == ProjectInterceptor.Lock,
            LibErrors.ProjectInterceptorIsNotLock()
        );
        clientStorage.projectIdToLockConfig[projectId] = lockConfig;
        emit LibEvents.LockConfigSet(projectId, lockConfig.duration);
    }

    function depositHook(uint256 projectId, address, address receiver, uint256, uint256 shares) external onlySelf {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ProjectInterceptor projectInterceptor = clientStorage.projectIdToProjectInterceptor[projectId];
        if (projectInterceptor == ProjectInterceptor.Lock) {
            clientStorage.userToProjectIdToUserLock[receiver][projectId].locks.push(
                UserLock({timestamp: uint64(block.timestamp), shares: uint192(shares)})
            );
        }
    }

    function redeemHook(uint256 projectId, address redeemer, address, uint256, uint256 shares) external onlySelf {
        LibClients.ClientsStorage storage clientStorage = LibClients._getClientsStorage();
        ProjectInterceptor projectInterceptor = clientStorage.projectIdToProjectInterceptor[projectId];
        if (projectInterceptor == ProjectInterceptor.Lock) {
            uint256 i = clientStorage.userToProjectIdToUserLock[redeemer][projectId].pointer;
            uint256 allLocks = clientStorage.userToProjectIdToUserLock[redeemer][projectId].locks.length;
            for (i; i < allLocks; i++) {
                UserLock memory lock = clientStorage.userToProjectIdToUserLock[redeemer][projectId].locks[i];
                require(lock.timestamp > block.timestamp, LibErrors.UserLocked());
                clientStorage.userToProjectIdToUserLock[redeemer][projectId].pointer++;
                shares -= lock.shares;
                if (shares == 0) {
                    break;
                }
            }
        }
    }
}

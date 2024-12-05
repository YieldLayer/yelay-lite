// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SelfOnly} from "src/abstract/SelfOnly.sol";

import {IClientsFacet} from "src/interfaces/IClientsFacet.sol";

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibClients, ClientData, LockConfig, ProjectInterceptor, UserLock} from "src/libraries/LibClients.sol";

contract ClientsFacet is SelfOnly, IClientsFacet {
    error MinIsZero();
    error MaxLessThanMin();
    error MinLessThanNextProjectId();
    error NotClientOwner();
    error OutOfBoundProjectId();
    error ProjectInterceptorIsNone();
    error ProjectInterceptorIsSet();
    error ProjectInterceptorIsNotLock();
    error ProjectIsActive();
    error ClientNameEmpty();
    error ClientNameIsTaken();

    error UserLocked();

    function createClient(address clientOwner, uint128 minProjectId, uint128 maxProjectId, bytes32 clientName)
        external
    {
        LibDiamond.enforceIsContractOwner();
        LibClients.ClientsStorage storage projectsStorage = LibClients._getClientsStorage();
        require(minProjectId > 0, MinIsZero());
        require(maxProjectId > minProjectId, MaxLessThanMin());
        require(minProjectId > projectsStorage.nextProjectId, MinLessThanNextProjectId());
        require(clientName != bytes32(0), ClientNameEmpty());
        require(projectsStorage.clientNameTaken[clientName] == false, ClientNameIsTaken());
        projectsStorage.ownerToClientData[clientOwner] =
            ClientData({minProjectId: minProjectId, maxProjectId: maxProjectId, clientName: clientName});
        projectsStorage.nextProjectId = maxProjectId;
        projectsStorage.clientNameTaken[clientName] = true;
        emit LibEvents.NewProjectIds(clientOwner, minProjectId, maxProjectId);
    }

    function transferClientOwnership(address newClientOwner) external {
        LibClients.ClientsStorage storage projectsStorage = LibClients._getClientsStorage();
        ClientData memory clientData = projectsStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId > 0, NotClientOwner());
        delete projectsStorage.ownerToClientData[msg.sender];
        projectsStorage.ownerToClientData[newClientOwner] = clientData;
        emit LibEvents.OwnershipTransferProjectIds(newClientOwner, clientData.minProjectId, clientData.maxProjectId);
    }

    function activateProject(uint256 projectId) external {
        LibClients.ClientsStorage storage projectsStorage = LibClients._getClientsStorage();
        ClientData memory clientData = projectsStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId <= projectId, OutOfBoundProjectId());
        require(clientData.maxProjectId >= projectId, OutOfBoundProjectId());
        require(projectsStorage.projectIdActive[projectId] == false, ProjectIsActive());
        projectsStorage.projectIdActive[projectId] = true;
        projectsStorage.projectIdToClientName[projectId] = clientData.clientName;
        emit LibEvents.ProjectActivated(projectId);
    }

    function setProjectInterceptor(uint256 projectId, ProjectInterceptor projectInterceptor) external {
        LibClients.ClientsStorage storage projectsStorage = LibClients._getClientsStorage();
        ClientData memory clientData = projectsStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId <= projectId, OutOfBoundProjectId());
        require(clientData.maxProjectId >= projectId, OutOfBoundProjectId());
        require(projectInterceptor != ProjectInterceptor.None, ProjectInterceptorIsNone());
        require(
            projectsStorage.projectIdToProjectInterceptor[projectId] == ProjectInterceptor.None,
            ProjectInterceptorIsSet()
        );
        projectsStorage.projectIdToProjectInterceptor[projectId] = projectInterceptor;
        emit LibEvents.ProjectOptionSet(projectId, uint256(projectInterceptor));
    }

    function setLockConfig(uint256 projectId, LockConfig calldata lockConfig) external {
        LibClients.ClientsStorage storage projectsStorage = LibClients._getClientsStorage();
        ClientData memory clientData = projectsStorage.ownerToClientData[msg.sender];
        require(clientData.minProjectId <= projectId, OutOfBoundProjectId());
        require(clientData.maxProjectId >= projectId, OutOfBoundProjectId());
        require(
            projectsStorage.projectIdToProjectInterceptor[projectId] == ProjectInterceptor.Lock,
            ProjectInterceptorIsNotLock()
        );
        projectsStorage.projectIdToLockConfig[projectId] = lockConfig;
        emit LibEvents.LockConfigSet(projectId, lockConfig.duration);
    }

    function depositHook(uint256 projectId, address depositor, address receiver, uint256 assets, uint256 shares)
        external
        onlySelf
    {
        LibClients.ClientsStorage storage projectsStorage = LibClients._getClientsStorage();
        ProjectInterceptor projectInterceptor = projectsStorage.projectIdToProjectInterceptor[projectId];
        if (projectInterceptor == ProjectInterceptor.Lock) {
            projectsStorage.userToProjectIdToUserLock[depositor][projectId].locks.push(
                UserLock({timestamp: uint64(block.timestamp), shares: uint192(shares)})
            );
        }
    }

    function redeemHook(uint256 projectId, address redeemer, address receiver, uint256 assets, uint256 shares)
        external
        onlySelf
    {
        LibClients.ClientsStorage storage projectsStorage = LibClients._getClientsStorage();
        ProjectInterceptor projectInterceptor = projectsStorage.projectIdToProjectInterceptor[projectId];
        if (projectInterceptor == ProjectInterceptor.Lock) {
            uint256 i = projectsStorage.userToProjectIdToUserLock[redeemer][projectId].pointer;
            uint256 allLocks = projectsStorage.userToProjectIdToUserLock[redeemer][projectId].locks.length;
            for (i; i < allLocks; i++) {
                UserLock memory lock = projectsStorage.userToProjectIdToUserLock[redeemer][projectId].locks[i];
                require(lock.timestamp > block.timestamp, UserLocked());
                projectsStorage.userToProjectIdToUserLock[redeemer][projectId].pointer++;
                shares -= lock.shares;
                if (shares == 0) {
                    break;
                }
            }
        }
    }
}

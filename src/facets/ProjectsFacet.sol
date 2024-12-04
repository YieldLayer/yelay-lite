// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SelfOnly} from "src/abstract/SelfOnly.sol";

import {IProjectsFacet} from "src/interfaces/IProjectsFacet.sol";

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibProjects, ProjectIds, LockConfig, ProjectOption, UserLock} from "src/libraries/LibProjects.sol";

contract ProjectsFacet is SelfOnly, IProjectsFacet {
    error MinIsZero();
    error MaxLessThanMin();
    error MinLessThanUpperBoundProjectId();
    error NotProjectOwner();
    error OutOfBoundProjectId();
    error ProjectOptionIsDefault();
    error ProjectOptionIsAlreadySet();
    error ProjectOptionIsNotLock();
    error ProjectIsAlreadyActive();

    error UserLocked();

    function grantProjectIds(address projectOwner, uint256 min, uint256 max) external {
        LibDiamond.enforceIsContractOwner();
        LibProjects.ProjectsStorage storage projectsStorage = LibProjects._getProjectsStorage();
        require(min > 0, MinIsZero());
        require(max > min, MaxLessThanMin());
        require(min > projectsStorage.upperBoundProjectId, MinLessThanUpperBoundProjectId());
        projectsStorage.ownerToProjectIds[projectOwner] = ProjectIds({min: min, max: max});
        projectsStorage.upperBoundProjectId = max;
        emit LibEvents.NewProjectIds(projectOwner, min, max);
    }

    function transferProjectIdsOwnership(address newProjectOwner) external {
        LibProjects.ProjectsStorage storage projectsStorage = LibProjects._getProjectsStorage();
        ProjectIds memory ownerProjectIds = projectsStorage.ownerToProjectIds[msg.sender];
        require(ownerProjectIds.min > 0, NotProjectOwner());
        delete projectsStorage.ownerToProjectIds[msg.sender];
        projectsStorage.ownerToProjectIds[newProjectOwner] = ownerProjectIds;
        emit LibEvents.OwnershipTransferProjectIds(newProjectOwner, ownerProjectIds.min, ownerProjectIds.max);
    }

    function activateProject(uint256 projectId) external {
        LibProjects.ProjectsStorage storage projectsStorage = LibProjects._getProjectsStorage();
        ProjectIds memory ownerProjectIds = projectsStorage.ownerToProjectIds[msg.sender];
        require(ownerProjectIds.min <= projectId, OutOfBoundProjectId());
        require(ownerProjectIds.max >= projectId, OutOfBoundProjectId());
        require(projectsStorage.projectIdActive[projectId] == false, ProjectIsAlreadyActive());
        projectsStorage.projectIdActive[projectId] = true;
        emit LibEvents.ProjectActivated(projectId);
    }

    function setProjectOption(uint256 projectId, ProjectOption projectOption) external {
        LibProjects.ProjectsStorage storage projectsStorage = LibProjects._getProjectsStorage();
        ProjectIds memory ownerProjectIds = projectsStorage.ownerToProjectIds[msg.sender];
        require(ownerProjectIds.min <= projectId, OutOfBoundProjectId());
        require(ownerProjectIds.max >= projectId, OutOfBoundProjectId());
        require(projectOption != ProjectOption.None, ProjectOptionIsDefault());
        require(projectsStorage.projectIdToProjectOption[projectId] == ProjectOption.None, ProjectOptionIsAlreadySet());
        projectsStorage.projectIdToProjectOption[projectId] = projectOption;
        emit LibEvents.ProjectOptionSet(projectId, uint256(projectOption));
    }

    function setLockConfig(uint256 projectId, LockConfig calldata lockConfig) external {
        LibProjects.ProjectsStorage storage projectsStorage = LibProjects._getProjectsStorage();
        ProjectIds memory ownerProjectIds = projectsStorage.ownerToProjectIds[msg.sender];
        require(ownerProjectIds.min <= projectId, OutOfBoundProjectId());
        require(ownerProjectIds.max >= projectId, OutOfBoundProjectId());
        require(projectsStorage.projectIdToProjectOption[projectId] == ProjectOption.Lock, ProjectOptionIsNotLock());
        projectsStorage.projectIdToLockConfig[projectId] = lockConfig;
        emit LibEvents.LockConfigSet(projectId, lockConfig.duration);
    }

    function depositHook(uint256 projectId, address depositor, address receiver, uint256 assets, uint256 shares)
        external
        onlySelf
    {
        LibProjects.ProjectsStorage storage projectsStorage = LibProjects._getProjectsStorage();
        ProjectOption projectOption = projectsStorage.projectIdToProjectOption[projectId];
        if (projectOption == ProjectOption.Lock) {
            projectsStorage.userToProjectIdToUserLock[depositor][projectId].locks.push(
                UserLock({timestamp: uint64(block.timestamp), shares: uint192(shares)})
            );
        }
    }

    function redeemHook(uint256 projectId, address redeemer, address receiver, uint256 assets, uint256 shares)
        external
        onlySelf
    {
        LibProjects.ProjectsStorage storage projectsStorage = LibProjects._getProjectsStorage();
        ProjectOption projectOption = projectsStorage.projectIdToProjectOption[projectId];
        if (projectOption == ProjectOption.Lock) {
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/utils/Address.sol";

import {ProjectsFacet} from "src/facets/ProjectsFacet.sol";

struct ProjectIds {
    uint256 min;
    uint256 max;
}

enum ProjectOption {
    None,
    Lock
}

struct LockConfig {
    uint256 duration;
}

struct UserLockData {
    uint256 pointer;
    UserLock[] locks;
}

struct UserLock {
    uint64 timestamp;
    uint192 shares;
}

library LibProjects {
    using Address for address;

    /// @custom:storage-location erc7201:yelay-vault.storage.ProjectsFacet
    struct ProjectsStorage {
        uint256 upperBoundProjectId;
        mapping(address => ProjectIds) ownerToProjectIds;
        mapping(uint256 => bool) projectIdActive;
        mapping(uint256 => ProjectOption) projectIdToProjectOption;
        // Lock part
        mapping(uint256 => LockConfig) projectIdToLockConfig;
        mapping(address => mapping(uint256 => UserLockData)) userToProjectIdToUserLock;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.ProjectsFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ProjectsStorageLocation =
        0xa44f1d363d278df8243e63e8c69452e057d71834bc075e2e46d76a5e211dd200;

    function _getProjectsStorage() internal pure returns (ProjectsStorage storage $) {
        assembly {
            $.slot := ProjectsStorageLocation
        }
    }

    function isProjectActive(uint256 projectId) internal view returns (bool) {
        ProjectsStorage storage projectsStorage = _getProjectsStorage();
        return projectsStorage.projectIdActive[projectId];
    }

    function onDeposit(uint256 projectId, address depositor, address receiver, uint256 assets, uint256 shares)
        internal
    {
        ProjectsStorage storage projectsStorage = _getProjectsStorage();
        if (projectsStorage.projectIdToProjectOption[projectId] != ProjectOption.None) {
            address(this).functionDelegateCall(
                abi.encodeWithSelector(ProjectsFacet.depositHook.selector, projectId, depositor, receiver, shares)
            );
        }
    }

    function onRedeem(uint256 projectId, address redeemer, address receiver, uint256 assets, uint256 shares) internal {
        ProjectsStorage storage projectsStorage = _getProjectsStorage();
        if (projectsStorage.projectIdToProjectOption[projectId] != ProjectOption.None) {
            address(this).functionDelegateCall(
                abi.encodeWithSelector(ProjectsFacet.redeemHook.selector, projectId, redeemer, receiver, shares)
            );
        }
    }
}

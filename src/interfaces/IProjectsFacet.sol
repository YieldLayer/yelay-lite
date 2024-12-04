// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ProjectIds, LockConfig, ProjectOption} from "src/libraries/LibProjects.sol";

interface IProjectsFacet {
    function grantProjectIds(address projectOwner, uint256 min, uint256 max) external;
    function transferProjectIdsOwnership(address newProjectOwner) external;
    function activateProject(uint256 projectId) external;
    function setProjectOption(uint256 projectId, ProjectOption projectOption) external;
    function setLockConfig(uint256 projectId, LockConfig calldata lockConfig) external;
    function depositHook(uint256 projectId, address depositor, address receiver, uint256 assets, uint256 shares)
        external;
    function redeemHook(uint256 projectId, address redeemer, address receiver, uint256 assets, uint256 shares)
        external;
}

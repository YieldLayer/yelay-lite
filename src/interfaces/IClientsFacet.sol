// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ClientData, LockConfig, ProjectInterceptor, UserLockData} from "src/libraries/LibClients.sol";

interface IClientsFacet {
    function createClient(address projectOwner, uint128 minProjectId, uint128 maxProjectId, bytes32 clientName)
        external;
    function transferClientOwnership(address newClientOwner) external;
    function activateProject(uint256 projectId) external;
    function setProjectInterceptor(uint256 projectId, ProjectInterceptor projectInterceptor) external;
    function setLockConfig(uint256 projectId, LockConfig calldata lockConfig) external;
    function depositHook(uint256 projectId, address depositor, address receiver, uint256 assets, uint256 shares)
        external;
    function redeemHook(uint256 projectId, address redeemer, address receiver, uint256 assets, uint256 shares)
        external;
    function lastProjectId() external view returns (uint256);
    function clientNameTaken(bytes32 clientName) external view returns (bool);
    function ownerToClientData(address owner) external view returns (ClientData memory);
    function projectIdToClientName(uint256 projectId) external view returns (bytes32);
    function projectIdActive(uint256 projectId) external view returns (bool);
    function projectIdToProjectInterceptor(uint256 projectId) external view returns (ProjectInterceptor);
    function projectIdToLockConfig(uint256 projectId) external view returns (LockConfig memory);
    function userToProjectIdToUserLock(address user, uint256 projectId) external view returns (UserLockData memory);
}

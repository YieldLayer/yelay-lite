// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ClientData, LockConfig, ProjectInterceptor} from "src/libraries/LibClients.sol";

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
}

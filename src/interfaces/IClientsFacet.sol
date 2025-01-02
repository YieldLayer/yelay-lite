// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ClientData} from "src/libraries/LibClients.sol";

interface IClientsFacet {
    function createClient(address projectOwner, uint128 minProjectId, uint128 maxProjectId, bytes32 clientName)
        external;
    function transferClientOwnership(address newClientOwner) external;
    function activateProject(uint256 projectId) external;
    function lastProjectId() external view returns (uint256);
    function clientNameTaken(bytes32 clientName) external view returns (bool);
    function ownerToClientData(address owner) external view returns (ClientData memory);
    function projectIdToClientName(uint256 projectId) external view returns (bytes32);
    function projectIdActive(uint256 projectId) external view returns (bool);
}

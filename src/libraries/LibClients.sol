// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {ClientsFacet} from "src/facets/ClientsFacet.sol";

struct ClientData {
    uint128 minProjectId;
    uint128 maxProjectId;
    bytes32 clientName;
}

enum ProjectInterceptor {
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

library LibClients {
    using Address for address;

    /// @custom:storage-location erc7201:yelay-vault.storage.ClientsFacet
    struct ClientsStorage {
        uint256 lastProjectId;
        mapping(address => ClientData) ownerToClientData;
        mapping(bytes32 => bool) clientNameTaken;
        mapping(uint256 => bytes32) projectIdToClientName;
        mapping(uint256 => bool) projectIdActive;
        mapping(uint256 => ProjectInterceptor) projectIdToProjectInterceptor;
        // Lock part
        mapping(uint256 => LockConfig) projectIdToLockConfig;
        mapping(address => mapping(uint256 => UserLockData)) userToProjectIdToUserLock;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.ClientsFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ClientsStorageLocation = 0x78b8360ea116a1ac1aaf7d99dc2a2fa96091e5ce27ad9c46aa3a48ffec134800;

    function _getClientsStorage() internal pure returns (ClientsStorage storage $) {
        assembly {
            $.slot := ClientsStorageLocation
        }
    }

    function isProjectActive(uint256 projectId) internal view returns (bool) {
        ClientsStorage storage clientStorage = _getClientsStorage();
        return clientStorage.projectIdActive[projectId];
    }

    function sameClient(uint256 projectId1, uint256 projectId2) internal view returns (bool) {
        ClientsStorage storage clientStorage = _getClientsStorage();
        return clientStorage.projectIdToClientName[projectId1] == clientStorage.projectIdToClientName[projectId2];
    }

    function onDeposit(uint256 projectId, address depositor, address receiver, uint256 assets, uint256 shares)
        internal
    {
        ClientsStorage storage clientStorage = _getClientsStorage();
        if (clientStorage.projectIdToProjectInterceptor[projectId] != ProjectInterceptor.None) {
            address(this).functionDelegateCall(
                abi.encodeWithSelector(
                    ClientsFacet.depositHook.selector, projectId, depositor, receiver, assets, shares
                )
            );
        }
    }

    function onRedeem(uint256 projectId, address redeemer, address receiver, uint256 assets, uint256 shares) internal {
        ClientsStorage storage clientStorage = _getClientsStorage();
        if (clientStorage.projectIdToProjectInterceptor[projectId] != ProjectInterceptor.None) {
            address(this).functionDelegateCall(
                abi.encodeWithSelector(ClientsFacet.redeemHook.selector, projectId, redeemer, receiver, assets, shares)
            );
        }
    }
}

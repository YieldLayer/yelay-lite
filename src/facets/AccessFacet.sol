// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {
    AccessControlUpgradeable,
    IAccessControl
} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {IAccessFacet} from "src/interfaces/IAccessFacet.sol";

import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibPausable} from "src/libraries/LibPausable.sol";

/**
 * @title AccessFacet
 * @dev Contract that provides role-based access control and pausing functionality.
 */
contract AccessFacet is AccessControlEnumerableUpgradeable, IAccessFacet {
    /// @inheritdoc IAccessControl
    function grantRole(bytes32 role, address account) public override(AccessControlUpgradeable, IAccessControl) {
        LibOwner.onlyOwner();
        _grantRole(role, account);
    }

    /// @inheritdoc IAccessControl
    function revokeRole(bytes32 role, address account) public override(AccessControlUpgradeable, IAccessControl) {
        LibOwner.onlyOwner();
        _revokeRole(role, account);
    }

    /// @inheritdoc IAccessFacet
    function checkRole(bytes32 role) external view {
        _checkRole(role);
    }

    /// @inheritdoc IAccessFacet
    function setPaused(bytes4 selector, bool paused) external {
        if (paused) {
            _checkRole(LibRoles.PAUSER, msg.sender);
        } else {
            _checkRole(LibRoles.UNPAUSER, msg.sender);
        }
        LibPausable.PausableStorage storage s = LibPausable._getPausableStorage();
        s.selectorToPaused[selector] = paused;
        emit LibEvents.PausedChange(selector, paused);
    }

    /// @inheritdoc IAccessFacet
    function selectorToPaused(bytes4 selector) external view returns (bool) {
        return LibPausable._getPausableStorage().selectorToPaused[selector];
    }

        function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

}

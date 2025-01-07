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

contract AccessFacet is AccessControlEnumerableUpgradeable, IAccessFacet {
    function grantRole(bytes32 role, address account) public override(AccessControlUpgradeable, IAccessControl) {
        LibOwner.onlyOwner();
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public override(AccessControlUpgradeable, IAccessControl) {
        LibOwner.onlyOwner();
        _revokeRole(role, account);
    }

    function checkRole(bytes32 role) external view {
        _checkRole(role);
    }

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

    function selectorToPaused(bytes4 selector) external view returns (bool) {
        return LibPausable._getPausableStorage().selectorToPaused[selector];
    }
}

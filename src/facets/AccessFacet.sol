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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {AccessControlUpgradeable, IAccessControl} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";

import {IAccessFacet} from "src/interfaces/IAccessFacet.sol";

contract AccessFacet is AccessControlEnumerableUpgradeable, IAccessFacet {
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    function grantRole(bytes32 role, address account)
        public
        override(AccessControlUpgradeable, IAccessControl)
        onlyOwner
    {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account)
        public
        override(AccessControlUpgradeable, IAccessControl)
        onlyOwner
    {
        _revokeRole(role, account);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        LibDiamond.setContractOwner(_newOwner);
    }

    function checkRole(bytes32 role) external view {
        _checkRole(role);
    }

    function owner() external view returns (address) {
        return LibDiamond.contractOwner();
    }
}

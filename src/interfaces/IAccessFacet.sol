// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IAccessControlEnumerable} from "@openzeppelin/access/extensions/IAccessControlEnumerable.sol";

interface IAccessFacet is IAccessControlEnumerable {
    function checkRole(bytes32 role) external view;
    function owner() external view returns (address);
    function transferOwnership(address _newOwner) external;
}

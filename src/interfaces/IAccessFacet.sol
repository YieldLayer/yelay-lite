// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IAccessControlEnumerable} from "@openzeppelin/access/extensions/IAccessControlEnumerable.sol";

interface IAccessFacet is IAccessControlEnumerable {
    function checkRole(bytes32 role) external view;
}

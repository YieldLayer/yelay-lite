// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IAccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

interface IAccessFacet is IAccessControlEnumerable {
    function checkRole(bytes32 role) external view;
    function setPaused(bytes4 selector, bool paused) external;
    function selectorToPaused(bytes4 selector) external view returns (bool);
}

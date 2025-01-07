// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

interface IAccessFacet is IAccessControlEnumerable {
    /**
     * @dev Checks if the caller has a specific role.
     * @param role The role identifier.
     */
    function checkRole(bytes32 role) external view;

    /**
     * @dev Sets the paused state for a specific function selector.
     * @param selector The function selector.
     * @param paused The paused state.
     */
    function setPaused(bytes4 selector, bool paused) external;

    /**
     * @dev Gets the paused state for a specific function selector.
     * @param selector The function selector.
     * @return paused The paused state.
     */
    function selectorToPaused(bytes4 selector) external view returns (bool);
}

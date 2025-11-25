// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

struct SelectorsToFacet {
    address facet;
    bytes4[] selectors;
}

interface IOwnerFacet {
    /**
     * @dev Returns the address of the current owner.
     * @return The address of the current owner.
     */
    function owner() external view returns (address);

    /**
     * @dev Returns the address of the pending owner.
     * @return The address of the pending owner.
     */
    function pendingOwner() external view returns (address);

    function addSelectors(SelectorsToFacet[] calldata arr) external;
    function updateSelectors(SelectorsToFacet[] calldata arr) external;
    function removeSelectors(bytes4[] calldata selectors) external;

    /**
     * @dev Returns the facet address for a given function selector.
     * @param selector The function selector.
     * @return The address of the facet.
     */
    function selectorToFacet(bytes4 selector) external view returns (address);

    /**
     * @dev Initiates the transfer of ownership to a new owner.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external;

    /**
     * @dev Accepts the transfer of ownership.
     */
    function acceptOwnership() external;
}

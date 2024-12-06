// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

struct SelectorsToFacet {
    address facet;
    bytes4[] selectors;
}

interface IOwnerFacet {
    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function acceptOwnership() external;

    function setSelectorToFacets(SelectorsToFacet[] calldata arr) external;

    function selectorToFacet(bytes4 selector) external view returns (address);
}

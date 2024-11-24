// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IAccessFacet {
    function checkRole(bytes32 role) external view;
    function owner() external view returns (address);
    function transferOwnership(address _newOwner) external;
}

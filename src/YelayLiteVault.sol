// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Diamond} from "@diamond/Diamond.sol";
import {Multicall} from "@openzeppelin/utils/Multicall.sol";

contract YelayLiteVault is Diamond, Multicall {
    constructor(address _contractOwner, address _diamondCutFacet) payable Diamond(_contractOwner, _diamondCutFacet) {}
}

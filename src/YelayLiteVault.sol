// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Diamond} from "@diamond/Diamond.sol";

contract YelayLiteVault is Diamond {
    constructor(address _contractOwner, address _diamondCutFacet) payable Diamond(_contractOwner, _diamondCutFacet) {}
}

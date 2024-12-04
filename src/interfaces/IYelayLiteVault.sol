// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ITokenFacet} from "./ITokenFacet.sol";
import {IFundsFacet} from "./IFundsFacet.sol";
import {IManagementFacet} from "./IManagementFacet.sol";
import {IAccessFacet} from "./IAccessFacet.sol";
import {IProjectsFacet} from "./IProjectsFacet.sol";

interface IYelayLiteVault is ITokenFacet, IFundsFacet, IManagementFacet, IAccessFacet, IProjectsFacet {}

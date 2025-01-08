// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IFundsFacet} from "./IFundsFacet.sol";
import {IManagementFacet} from "./IManagementFacet.sol";
import {IAccessFacet} from "./IAccessFacet.sol";
import {IClientsFacet} from "./IClientsFacet.sol";
import {IOwnerFacet} from "./IOwnerFacet.sol";
import {IMulticall} from "./IMulticall.sol";

interface IYelayLiteVault is
    IFundsFacet,
    IManagementFacet,
    IAccessFacet,
    IClientsFacet,
    IOwnerFacet,
    IMulticall
{}

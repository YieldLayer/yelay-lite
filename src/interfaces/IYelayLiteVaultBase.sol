// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IManagementFacet} from "./IManagementFacet.sol";
import {IAccessFacet} from "./IAccessFacet.sol";
import {IClientsFacet} from "./IClientsFacet.sol";
import {IOwnerFacet} from "./IOwnerFacet.sol";
import {IMulticall} from "./IMulticall.sol";

interface IYelayLiteVaultBase is IManagementFacet, IAccessFacet, IClientsFacet, IOwnerFacet, IMulticall {}

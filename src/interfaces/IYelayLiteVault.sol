// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFundsFacet} from "./IFundsFacet.sol";
import {IYelayLiteVaultBase} from "./IYelayLiteVaultBase.sol";

interface IYelayLiteVault is IFundsFacet, IYelayLiteVaultBase {}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAsyncFundsFacet} from "./IAsyncFundsFacet.sol";
import {IYelayLiteVaultBase} from "./IYelayLiteVaultBase.sol";

interface IYelayLiteVaultAsync is IAsyncFundsFacet, IYelayLiteVaultBase {}

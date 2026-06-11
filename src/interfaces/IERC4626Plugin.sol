// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ClaimRequest} from "src/interfaces/IYieldExtractor.sol";

interface IERC4626Plugin {
    function accrue(ClaimRequest calldata data) external;
}

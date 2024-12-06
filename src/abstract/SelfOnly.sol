// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibErrors} from "src/libraries/LibErrors.sol";

abstract contract SelfOnly {
    // TODO: foundry soon should have a fix for forge fmt error on transient storage
    bool transient isSelf;

    modifier onlySelf() {
        require(isSelf, LibErrors.NotSelf());
        _;
    }

    modifier allowSelf() {
        isSelf = true;
        _;
        isSelf = false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract SelfOnly {
    // TODO: foundry soon should have a fix for forge fmt error on transient storage 
    bool transient isSelf;

    error NotSelf();

    modifier onlySelf() {
        require(isSelf, NotSelf());
        _;
    }

    modifier allowSelf() {
        isSelf = true;
        _;
        isSelf = false;
    }
}

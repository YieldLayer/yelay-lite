// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


abstract contract SelfOnly {
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

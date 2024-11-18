// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


abstract contract SelfOnly {
    // TODO: implement erc7201 ?
    bool transient isSelf; 

    error NotSelf();

    modifier onlySelf() {
        require(isSelf, NotSelf());
        _;
        isSelf = false;
    }

    modifier allowSelf() {
        isSelf = true;
        _;
        isSelf = false;
    }
}

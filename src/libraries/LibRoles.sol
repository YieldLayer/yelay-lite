// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibRoles {
    // 0xbf935b513649871c60054e0279e4e5798d3dfd05785c3c3c5b311fb39ec270fe
    bytes32 constant STRATEGY_AUTHORITY = keccak256("STRATEGY_AUTHORITY");

    // 0xffd2865c3eadba5ddbf1543e65a692d7001b37f737db7363a54642156548df64
    bytes32 constant FUNDS_OPERATOR = keccak256("FUNDS_OPERATOR");

    //0xb95e9900cc6e2c54ae5b00d8f86008697b24bf67652a40653ea0c09c6fc4a856
    bytes32 constant QUEUES_OPERATOR = keccak256("QUEUES_OPERATOR");
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibRoles {
    // 0xbf935b513649871c60054e0279e4e5798d3dfd05785c3c3c5b311fb39ec270fe
    bytes32 constant STRATEGY_AUTHORITY = keccak256("STRATEGY_AUTHORITY");

    // 0xffd2865c3eadba5ddbf1543e65a692d7001b37f737db7363a54642156548df64
    bytes32 constant FUNDS_OPERATOR = keccak256("FUNDS_OPERATOR");

    // 0xb95e9900cc6e2c54ae5b00d8f86008697b24bf67652a40653ea0c09c6fc4a856
    bytes32 constant QUEUES_OPERATOR = keccak256("QUEUES_OPERATOR");

    // 0x8bf6ce5ec02ea9a811a4884ff857c405447f2dfa3ad4c8a5e93888abb5d17ceb
    bytes32 constant SWAP_REWARDS_OPERATOR = keccak256("SWAP_REWARDS_OPERATOR");

    // 0x539440820030c4994db4e31b6b800deafd503688728f932addfe7a410515c14c
    bytes32 constant PAUSER = keccak256("PAUSER");

    // 0x82b32d9ab5100db08aeb9a0e08b422d14851ec118736590462bf9c085a6e9448
    bytes32 constant UNPAUSER = keccak256("UNPAUSER");

    // 0xe1e438f510a6787349796e72348290fc4309699b8925cfe7df77feeaca3b7020
    bytes32 constant YIELD_PUBLISHER = keccak256("YIELD_PUBLISHER");
}

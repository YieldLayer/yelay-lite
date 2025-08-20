// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMessageTransmitter {
    function receiveMessage(bytes memory message, bytes calldata attestation) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IMessageTransmitter
 * @dev Interface for Circle's CCTP MessageTransmitter contract
 */
interface IMessageTransmitter {
    /**
     * @notice Receive a message. Messages with a given nonce
     * can only be broadcast once for a (sourceDomain, destinationDomain)
     * pair. The message body cannot exceed maxMessageBodySize bytes.
     *
     * The nonce must be reserved by pausing the contract and calling
     * `setUsedNonce` for the message to be valid.
     *
     * This function will:
     *  1. Verify the message signature
     *  2. Verify the message is for this domain
     *  3. Verify the message was not already used
     *  4. Mark the message as used
     *  5. Call the message recipient with the message body
     *
     * @dev Signature requirements:
     * - A valid signature consists of the concatenated signatures of `t+1` signers,
     *   where `t = floor((n-1)/3)` and `n` is the number of attesters.
     * - Signatures must be sorted in ascending order by the public key of the signers
     * - A signature is 65 bytes: `r (32 bytes) || s (32 bytes) || v (1 byte)`
     * - The final signature in the concatenated signature must be a padding signature:
     *   `bytes32(0) || bytes32(0) || bytes1(0x00)`
     *
     * @param message Message bytes
     * @param attestation Concatenated signatures of message
     * @return success bool, true if successful
     */
    function receiveMessage(bytes memory message, bytes calldata attestation) external returns (bool success);

    /**
     * @notice Replace a message. Only callable by owner.
     * @param originalMessage Original message to replace
     * @param originalAttestation Attestation for original message
     * @param newMessageBody New message body of replaced message
     * @param newDestinationCaller New destination caller, which may be the
     * same as the original destination caller, a new destination caller, or an empty
     * destination caller (bytes32(0), indicating that any destination caller is valid.)
     */
    function replaceMessage(
        bytes calldata originalMessage,
        bytes calldata originalAttestation,
        bytes calldata newMessageBody,
        bytes32 newDestinationCaller
    ) external;

    /**
     * @notice Returns domain of contract.
     * @return domain identifier of local domain
     */
    function localDomain() external view returns (uint32);

    /**
     * @notice Returns version of contract.
     * @return version identifier of contract
     */
    function version() external view returns (uint32);

    /**
     * @notice Get nonce reserved by message.
     * @param message Message to get nonce of
     * @return nonce reserved by message
     */
    function getNonce(bytes calldata message) external pure returns (uint64);

    /**
     * @notice Get message sender.
     * @param message Message to get sender of
     * @return sender of message as bytes32
     */
    function getSender(bytes calldata message) external pure returns (bytes32);

    /**
     * @notice Get message recipient.
     * @param message Message to get recipient of
     * @return recipient of message as bytes32
     */
    function getRecipient(bytes calldata message) external pure returns (bytes32);

    /**
     * @notice Get message destination caller.
     * @param message Message to get destination caller of
     * @return destination caller of message as bytes32
     */
    function getDestinationCaller(bytes calldata message) external pure returns (bytes32);

    /**
     * @notice Get message body.
     * @param message Message to get body of
     * @return body of message
     */
    function getMessageBody(bytes calldata message) external pure returns (bytes calldata);

    /**
     * @notice Returns whether message with nonce was used.
     * @param sourceDomain Domain of message sender
     * @param nonce Message nonce
     * @return used True if message with nonce was used
     */
    function usedNonces(uint32 sourceDomain, uint64 nonce) external view returns (bool);

    event MessageReceived(
        address indexed caller, uint32 sourceDomain, uint64 indexed nonce, bytes32 sender, bytes messageBody
    );
    event MessageSent(bytes message);
}

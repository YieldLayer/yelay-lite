// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ITokenMessenger
 * @dev Interface for Circle's CCTP TokenMessenger contract
 */
interface ITokenMessenger {
    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - given burnToken is not supported
     * - given destinationDomain has no TokenMessenger registered
     * - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
     * to this contract is less than `amount`.
     * - burn() reverts. For example, if `amount` is 0.
     * - maxFee is greater than or equal to `amount`.
     * - maxFee is less than `amount * minFee / MIN_FEE_MULTIPLIER`.
     * - MessageTransmitterV2#sendMessage reverts.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain to receive message on
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken token to burn `amount` of, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32. If equal to bytes32(0),
     * any address can broadcast the message.
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param minFinalityThreshold the minimum finality at which a burn message will be attested to.
     * @return nonce unique nonce reserved by message
     */
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external returns (uint64 nonce);

    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * The mint on the destination domain must be called by `destinationCaller`.
     * WARNING: if the `destinationCaller` does not represent a valid address as bytes32, then it will not be possible
     * to broadcast the message on the destination domain. This is an advanced feature, and the standard
     * depositForBurn() should be preferred for most use cases.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - given destinationCaller is zero address
     * - given burnToken is not supported
     * - given destinationDomain has no TokenMessenger registered
     * - transferFrom() reverts. For example, if sender has insufficient balance.
     * - burn() reverts. For example, if sender has insufficient balance.
     * @param amount amount to burn
     * @param destinationDomain destination domain
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken address of contract to burn deposited tokens, on local domain
     * @param destinationCaller address of caller on destination domain
     * @return nonce unique nonce reserved by message
     */

    /**
     * @notice Returns local domain of contract.
     * @return domain identifier of local domain
     */
    function localDomain() external view returns (uint32);

    /**
     * @notice Returns version of contract.
     * @return version identifier of contract
     */
    function version() external view returns (uint32);

    /**
     * @notice Get the address of the MessageTransmitter
     * @return address of MessageTransmitter
     */
    function messageTransmitter() external view returns (address);

    /**
     * @notice Get the address of the local token for the given remote domain and token
     * @param remoteDomain the remote domain
     * @param remoteToken the remote token address
     * @return localToken the local token address
     */
    function getLocalToken(uint32 remoteDomain, bytes32 remoteToken) external view returns (address localToken);

    event DepositForBurn(
        uint64 indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller
    );
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ICCTPV2Facet
 * @dev Interface for CCTP v2 facet that handles cross-chain USDC transfers between vaults
 */
interface ICCTPV2Facet {
    /**
     * @dev Initiates a cross-chain USDC bridge from current vault to another vault on different chain
     * Simply transfers USDC from this vault's balance to destination vault's balance
     * Destination vault is automatically deduced from the destination domain
     * @param amount The amount of USDC to bridge
     * @param destinationDomain The destination chain domain ID
     */
    function bridgeUSDC(uint256 amount, uint32 destinationDomain) external;

    /**
     * @dev Receives and processes a CCTP message by calling Circle's MessageTransmitter
     * Gated function that calls receiveMessage on Circle's contracts and updates vault balance
     * @param message The CCTP message bytes
     * @param attestation The attestation signature from Circle
     */
    function receiveUSDC(bytes calldata message, bytes calldata attestation) external;

    /**
     * @dev Sets the vault address for a specific domain (whitelisting/delisting in one function)
     * Only STRATEGY_AUTHORITY can set domain vaults to prevent compromised FUNDS_OPERATOR
     * from sending USDC to arbitrary addresses
     * @param destinationDomain The CCTP domain ID for the destination chain
     * @param vault The vault address for the domain (address(0) to remove/delist)
     */
    function setDomainVault(uint32 destinationDomain, address vault) external;

    /**
     * @dev Gets the vault address for a specific domain
     * @param destinationDomain The CCTP domain ID for the destination chain
     * @return vault The vault address (address(0) if not set)
     */
    function getDomainVault(uint32 destinationDomain) external view returns (address vault);

    /**
     * @dev Gets the CCTP domain ID for current chain
     * @return domain The domain ID
     */
    function getDomain() external view returns (uint32 domain);

    /**
     * @dev Gets the TokenMessenger contract address
     * @return tokenMessenger The TokenMessenger address
     */
    function getTokenMessenger() external view returns (address tokenMessenger);

    /**
     * @dev Gets the MessageTransmitter contract address
     * @return messageTransmitter The MessageTransmitter address
     */
    function getMessageTransmitter() external view returns (address messageTransmitter);

    /**
     * @dev Sets the CCTP contract addresses (admin only)
     * @param tokenMessenger_ The TokenMessenger contract address
     * @param messageTransmitter_ The MessageTransmitter contract address
     */
    function setCCTPContracts(address tokenMessenger_, address messageTransmitter_) external;

    /**
     * @dev Sets domain mapping for supported chains
     * @param chainId The chain ID
     * @param domain The CCTP domain ID
     */
    function setDomainMapping(uint256 chainId, uint32 domain) external;

    /**
     * @dev Gets domain for a chain ID
     * @param chainId The chain ID
     * @return domain The CCTP domain ID
     */
    function getDomainForChain(uint256 chainId) external view returns (uint32 domain);
}

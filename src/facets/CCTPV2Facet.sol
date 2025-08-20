// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {RoleCheck} from "src/abstract/RoleCheck.sol";
import {PausableCheck} from "src/abstract/PausableCheck.sol";

import {ICCTPV2Facet} from "src/interfaces/ICCTPV2Facet.sol";
import {ITokenMessenger} from "src/interfaces/external/cctp/ITokenMessenger.sol";
import {IMessageTransmitter} from "src/interfaces/external/cctp/IMessageTransmitter.sol";

import {LibFunds} from "src/libraries/LibFunds.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

/**
 * @title CCTPV2Facet
 * @dev Contract that handles cross-chain USDC transfers between vaults using Circle's CCTP v2
 */
contract CCTPV2Facet is RoleCheck, PausableCheck, ICCTPV2Facet {
    using SafeTransferLib for ERC20;

    /// @custom:storage-location erc7201:yelay-vault.storage.CCTPV2Facet
    struct CCTPV2Storage {
        ITokenMessenger tokenMessenger;
        IMessageTransmitter messageTransmitter;
        mapping(uint256 => uint32) chainIdToDomain;
        mapping(uint32 => address) domainToVault; // domain => vault address
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.CCTPV2Facet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CCTPV2StorageLocation = 0xdd853095aaa9b28fa456d3288c63ae7d79d70f3ee2f046d6cf6f7d9e9b082f00;

    function _getCCTPV2Storage() internal pure returns (CCTPV2Storage storage $) {
        assembly {
            $.slot := CCTPV2StorageLocation
        }
    }

    /// @inheritdoc ICCTPV2Facet
    function bridgeUSDC(uint256 amount, uint32 destinationDomain)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        notPaused
    {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        CCTPV2Storage storage sC = _getCCTPV2Storage();

        require(amount > 0, LibErrors.ZeroAmount());
        require(address(sC.tokenMessenger) != address(0), LibErrors.CCTPContractsNotConfigured());
        require(address(sC.messageTransmitter) != address(0), LibErrors.CCTPContractsNotConfigured());

        address destinationVault = sC.domainToVault[destinationDomain];
        require(destinationVault != address(0), LibErrors.InvalidDestinationVault());

        // Ensure we have enough underlying balance, if not, withdraw from strategies
        require(sF.underlyingBalance >= amount, LibErrors.InsufficientUnderlyingBalance());

        // Reduce underlying balance
        sF.underlyingBalance -= SafeCast.toUint192(amount);

        // Approve USDC to TokenMessenger
        sF.underlyingAsset.safeApprove(address(sC.tokenMessenger), amount);

        // Initiate CCTP v2 burn with destination caller (destination vault)
        uint64 nonce = sC.tokenMessenger.depositForBurn(
            amount,
            destinationDomain,
            bytes32(uint256(uint160(destinationVault))), // mintRecipient
            address(sF.underlyingAsset), // burnToken (USDC)
            bytes32(uint256(uint160(destinationVault))), // destinationCaller
            0, // maxFee = 0 for free standard transfers
            2000 // Messages with a minFinalityThreshold of 2000 are considered Standard messages. These messages are attested to at the finalized level by Iris.
        );

        emit LibEvents.CrossChainTransferInitiated(msg.sender, destinationDomain, destinationVault, amount, nonce);
    }

    /// @inheritdoc ICCTPV2Facet
    function receiveUSDC(bytes calldata message, bytes calldata attestation)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        notPaused
    {
        CCTPV2Storage storage sC = _getCCTPV2Storage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();

        require(address(sC.messageTransmitter) != address(0), LibErrors.CCTPContractsNotConfigured());

        uint256 balanceBefore = sF.underlyingAsset.balanceOf(address(this));

        // Call Circle's MessageTransmitter to receive the message
        bool success = sC.messageTransmitter.receiveMessage(message, attestation);
        require(success, LibErrors.CCTPMessageReceiveFailed());

        uint256 balanceAfter = sF.underlyingAsset.balanceOf(address(this));

        uint256 usdcReceived = balanceAfter - balanceBefore;

        require(usdcReceived > 0, LibErrors.ZeroUSDCReceived());

        // Update the vault's balance tracking
        sF.underlyingBalance += SafeCast.toUint192(usdcReceived);

        emit LibEvents.CrossChainTransferReceived(usdcReceived);
    }

    /// @inheritdoc ICCTPV2Facet
    function setDomainVault(uint32 destinationDomain, address vault)
        external
        onlyRole(LibRoles.STRATEGY_AUTHORITY)
        notPaused
    {
        CCTPV2Storage storage sC = _getCCTPV2Storage();

        address oldVault = sC.domainToVault[destinationDomain];
        sC.domainToVault[destinationDomain] = vault;

        if (vault != address(0)) {
            emit LibEvents.VaultWhitelisted(destinationDomain, vault);
        } else {
            emit LibEvents.VaultRemovedFromWhitelist(destinationDomain, oldVault);
        }
    }

    /// @inheritdoc ICCTPV2Facet
    function getDomainVault(uint32 destinationDomain) external view returns (address vault) {
        CCTPV2Storage storage sC = _getCCTPV2Storage();
        return sC.domainToVault[destinationDomain];
    }

    /// @inheritdoc ICCTPV2Facet
    function getTokenMessenger() external view returns (address tokenMessenger) {
        CCTPV2Storage storage sC = _getCCTPV2Storage();
        return address(sC.tokenMessenger);
    }

    /// @inheritdoc ICCTPV2Facet
    function getMessageTransmitter() external view returns (address messageTransmitter) {
        CCTPV2Storage storage sC = _getCCTPV2Storage();
        return address(sC.messageTransmitter);
    }

    /// @inheritdoc ICCTPV2Facet
    function setCCTPContracts(address tokenMessenger_, address messageTransmitter_)
        external
        onlyRole(LibRoles.STRATEGY_AUTHORITY)
    {
        require(tokenMessenger_ != address(0), LibErrors.ZeroAddress());
        require(messageTransmitter_ != address(0), LibErrors.ZeroAddress());

        CCTPV2Storage storage sC = _getCCTPV2Storage();
        sC.tokenMessenger = ITokenMessenger(tokenMessenger_);
        sC.messageTransmitter = IMessageTransmitter(messageTransmitter_);

        emit LibEvents.CCTPContractsUpdated(tokenMessenger_, messageTransmitter_);
    }

    /// @inheritdoc ICCTPV2Facet
    function setDomainMapping(uint256 chainId, uint32 domain) external onlyRole(LibRoles.STRATEGY_AUTHORITY) {
        CCTPV2Storage storage sC = _getCCTPV2Storage();
        sC.chainIdToDomain[chainId] = domain;

        emit LibEvents.DomainMappingUpdated(chainId, domain);
    }

    /// @inheritdoc ICCTPV2Facet
    function getDomainForChain(uint256 chainId) external view returns (uint32 domain) {
        CCTPV2Storage storage sC = _getCCTPV2Storage();
        return sC.chainIdToDomain[chainId];
    }
}

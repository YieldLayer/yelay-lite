// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {ISwapper, SwapArgs, ExchangeArgs} from "src/interfaces/ISwapper.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

contract Swapper is OwnableUpgradeable, UUPSUpgradeable, ISwapper {
    using SafeTransferLib for ERC20;
    using Address for address;

    /**
     * @dev Exchanges that are allowed to execute a swap.
     */
    mapping(address => bool) public exchangeAllowlist;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the given owner.
     * @param owner The address of the owner.
     */
    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    // @inheritdoc ISwapper
    function swap(SwapArgs[] memory swapArgs, address tokenOut) external returns (uint256 tokenOutAmount) {
        for (uint256 i; i < swapArgs.length; i++) {
            require(exchangeAllowlist[swapArgs[i].swapTarget], LibErrors.ExchangeNotAllowed(swapArgs[i].swapTarget));

            uint256 tokenInAmount = ERC20(swapArgs[i].tokenIn).balanceOf(address(this));
            require(tokenInAmount > 0, LibErrors.NothingToSwap(swapArgs[i].tokenIn));

            _approveMax(ERC20(swapArgs[i].tokenIn), swapArgs[i].swapTarget);

            swapArgs[i].swapTarget.functionCall(swapArgs[i].swapCallData);

            tokenInAmount = ERC20(swapArgs[i].tokenIn).balanceOf(address(this));
            if (tokenInAmount > 0) {
                ERC20(swapArgs[i].tokenIn).safeTransfer(msg.sender, tokenInAmount);
            }
            uint256 newTokenOutAmount = ERC20(tokenOut).balanceOf(address(this));
            require(newTokenOutAmount > tokenOutAmount, LibErrors.NothingSwapped(tokenOut));
            tokenOutAmount = newTokenOutAmount;
        }
        ERC20(tokenOut).safeTransfer(msg.sender, tokenOutAmount);
        return tokenOutAmount;
    }

    // @inheritdoc ISwapper
    function updateExchangeAllowlist(ExchangeArgs[] calldata exchangeArgs) external onlyOwner {
        for (uint256 i; i < exchangeArgs.length; ++i) {
            exchangeAllowlist[exchangeArgs[i].exchange] = exchangeArgs[i].allowed;
            emit LibEvents.ExchangeAllowlistUpdated(exchangeArgs[i].exchange, exchangeArgs[i].allowed);
        }
    }

    /**
     * @dev Approves the maximum amount of tokens for the spender.
     * @param token The token to approve.
     * @param spender The address of the spender.
     */
    function _approveMax(ERC20 token, address spender) private {
        if (token.allowance(address(this), spender) == 0) {
            token.safeApprove(spender, type(uint256).max);
        }
    }

    /**
     * @dev Authorizes the upgrade of the contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

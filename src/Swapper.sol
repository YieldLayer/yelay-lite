// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {ISwapper, SwapArgs, ExchangeArgs} from "src/interfaces/ISwapper.sol";

contract Swapper is OwnableUpgradeable, UUPSUpgradeable, ISwapper {
    using SafeTransferLib for ERC20;
    using Address for address;

    /**
     * @notice Used when trying to do a swap via an exchange that is not allowed to execute a swap.
     * @param exchange Exchange used.
     */
    error ExchangeNotAllowed(address exchange);

    error NothingToSwap(address tokenIn);
    error NothingSwapped(address tokenOut);

    /**
     * @notice Emitted when the exchange allowlist is updated.
     * @param exchange Exchange that was updated.
     * @param isAllowed Whether the exchange is allowed to be used in a swap or not after the update.
     */
    event ExchangeAllowlistUpdated(address indexed exchange, bool isAllowed);

    /* ========== STATE VARIABLES ========== */

    /**
     * @dev Exchanges that are allowed to execute a swap.
     */
    mapping(address => bool) public exchangeAllowlist;

    /* ========== CONSTRUCTOR ========== */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    /* ========== EXTERNAL MUTATIVE FUNCTIONS ========== */

    function swap(SwapArgs[] memory swapArgs, address tokenOut) external returns (uint256 tokenOutAmount) {
        for (uint256 i; i < swapArgs.length; i++) {
            require(exchangeAllowlist[swapArgs[i].swapTarget], ExchangeNotAllowed(swapArgs[i].swapTarget));

            uint256 tokenInAmount = ERC20(swapArgs[i].tokenIn).balanceOf(address(this));
            require(tokenInAmount > 0, NothingToSwap(swapArgs[i].tokenIn));

            _approveMax(ERC20(swapArgs[i].tokenIn), swapArgs[i].swapTarget);

            swapArgs[i].swapTarget.functionCall(swapArgs[i].swapCallData);

            tokenInAmount = ERC20(swapArgs[i].tokenIn).balanceOf(address(this));
            if (tokenInAmount > 0) {
                ERC20(swapArgs[i].tokenIn).safeTransfer(msg.sender, tokenInAmount);
            }
            uint256 newTokenOutAmount = ERC20(tokenOut).balanceOf(address(this));
            require(newTokenOutAmount > tokenOutAmount, NothingSwapped(tokenOut));
            tokenOutAmount += newTokenOutAmount;
        }
        ERC20(tokenOut).safeTransfer(msg.sender, tokenOutAmount);
        return tokenOutAmount;
    }

    function updateExchangeAllowlist(ExchangeArgs[] calldata exchangeArgs) external onlyOwner {
        for (uint256 i; i < exchangeArgs.length; ++i) {
            exchangeAllowlist[exchangeArgs[i].exchange] = exchangeArgs[i].allowed;
            emit ExchangeAllowlistUpdated(exchangeArgs[i].exchange, exchangeArgs[i].allowed);
        }
    }

    function _approveMax(ERC20 token, address spender) private {
        if (token.allowance(address(this), spender) == 0) {
            token.safeApprove(spender, type(uint256).max);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

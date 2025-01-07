// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {ISwapper, SwapArgs} from "src/interfaces/ISwapper.sol";
import {IWETH} from "src/interfaces/external/weth/IWETH.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";

/**
 * @title VaultWrapper
 * @dev Contract that wraps ETH and interacts with the FundsFacet for deposits and swaps.
 */
contract VaultWrapper is OwnableUpgradeable, UUPSUpgradeable {
    using SafeTransferLib for ERC20;

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IWETH public immutable weth;
    ISwapper public immutable swapper;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IWETH weth_, ISwapper swapper_) {
        weth = weth_;
        swapper = swapper_;
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the given owner.
     * @param owner The address of the owner.
     */
    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    /**
     * @dev Wraps ETH and deposits it into the specified vault.
     * @param yelayLiteVault The address of the vault.
     * @param projectId The ID of the project.
     * @return shares The amount of shares received.
     */
    function wrapEthAndDeposit(address yelayLiteVault, uint256 projectId) external payable returns (uint256 shares) {
        require(msg.value > 0, LibErrors.NoEth());
        weth.deposit{value: msg.value}();
        ERC20(address(weth)).safeApprove(yelayLiteVault, msg.value);
        return IFundsFacet(yelayLiteVault).deposit(msg.value, projectId, msg.sender);
    }

    /**
     * @dev Swaps tokens and deposits the resulting assets into the specified vault.
     * @param yelayLiteVault The address of the vault.
     * @param projectId The ID of the project.
     * @param swapArgs The swap arguments.
     * @param amount The amount of tokens to swap.
     * @return shares The amount of shares received.
     */
    function swapAndDeposit(address yelayLiteVault, uint256 projectId, SwapArgs[] calldata swapArgs, uint256 amount)
        external
        payable
        returns (uint256 shares)
    {
        require(swapArgs.length == 1, LibErrors.MonoAssetSwap());

        if (msg.value > 0) {
            require(swapArgs[0].tokenIn == address(weth), LibErrors.NotWeth());
            weth.deposit{value: msg.value}();
            ERC20(address(weth)).safeTransfer(address(swapper), msg.value);
        } else {
            ERC20(swapArgs[0].tokenIn).safeTransferFrom(msg.sender, address(swapper), amount);
        }

        address underlyingAsset = IFundsFacet(yelayLiteVault).underlyingAsset();
        uint256 assets = swapper.swap(swapArgs, underlyingAsset);
        ERC20(underlyingAsset).safeApprove(yelayLiteVault, assets);
        shares = IFundsFacet(yelayLiteVault).deposit(assets, projectId, msg.sender);

        uint256 returnBalance = ERC20(swapArgs[0].tokenIn).balanceOf(address(this));
        if (returnBalance > 0) {
            if (msg.value > 0) {
                weth.withdraw(returnBalance);
                payable(msg.sender).transfer(returnBalance);
            } else {
                ERC20(swapArgs[0].tokenIn).safeTransfer(msg.sender, returnBalance);
            }
        }
    }

    /**
     * @dev Authorizes the upgrade of the contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Fallback function to receive ETH.
     */
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {ISwapper, SwapArgs} from "src/interfaces/ISwapper.sol";
import {IWETH} from "src/interfaces/external/weth/IWETH.sol";

import {LibErrors} from "src/libraries/LibErrors.sol";

contract VaultWrapper is OwnableUpgradeable, UUPSUpgradeable {
    using SafeTransferLib for ERC20;

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /* ========== STATE VARIABLES ========== */

    IWETH public immutable weth;
    ISwapper public immutable swapper;

    /* ========== CONSTRUCTOR ========== */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IWETH weth_, ISwapper swapper_) {
        weth = weth_;
        swapper = swapper_;
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function wrapEthAndDeposit(address yelayLiteVault, uint256 projectId) external payable returns (uint256 shares) {
        require(msg.value > 0, LibErrors.NoEth());
        weth.deposit{value: msg.value}();
        ERC20(address(weth)).safeApprove(yelayLiteVault, msg.value);
        return IFundsFacet(yelayLiteVault).deposit(msg.value, projectId, msg.sender);
    }

    function swapAndDeposit(address yelayLiteVault, uint256 projectId, SwapArgs calldata swapArgs, uint256 amount)
        external
        payable
        returns (uint256 shares)
    {
        if (msg.value > 0) {
            require(swapArgs.tokenIn == address(weth), LibErrors.NotWeth());
            weth.deposit{value: msg.value}();
            ERC20(address(weth)).safeTransfer(address(swapper), msg.value);
        } else {
            ERC20(swapArgs.tokenIn).safeTransferFrom(msg.sender, address(swapper), amount);
        }

        SwapArgs[] memory swapperArgs = new SwapArgs[](1);
        swapperArgs[0] = swapArgs;
        address underlyingAsset = IFundsFacet(yelayLiteVault).underlyingAsset();
        uint256 assets = swapper.swap(swapperArgs, underlyingAsset);
        ERC20(underlyingAsset).safeApprove(yelayLiteVault, assets);
        shares = IFundsFacet(yelayLiteVault).deposit(assets, projectId, msg.sender);

        uint256 returnBalance = ERC20(swapArgs.tokenIn).balanceOf(address(this));
        if (returnBalance > 0) {
            if (msg.value > 0) {
                weth.withdraw(returnBalance);
                payable(msg.sender).transfer(returnBalance);
            } else {
                ERC20(swapArgs.tokenIn).safeTransfer(msg.sender, returnBalance);
            }
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}

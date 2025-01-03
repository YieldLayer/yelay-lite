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

    // function redeemAndUnwrapEth(address yelayLiteVault, uint256 projectId, uint256 shares)
    //     external
    //     returns (uint256 amount)
    // {
    //     require(IFundsFacet(yelayLiteVault).underlyingAsset() == address(weth), LibErrors.NotWeth());
    //     IFundsFacet(yelayLiteVault).safeTransferFrom(msg.sender, address(this), projectId, shares, "");
    //     // (address from, address to, uint256 id, uint256 value, bytes calldata data)
    //     amount = IFundsFacet(yelayLiteVault).redeem(shares, projectId, address(this));
    //     weth.withdraw(amount);
    //     payable(msg.sender).transfer(amount);
    // }

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

    // function redeemAndSwap(
    //     address yelayLiteVault,
    //     uint256 projectId,
    //     SwapArgs[] calldata swapArgs,
    //     uint256 shares,
    //     address tokenOut,
    //     bool unwrapWeth
    // ) external returns (uint256 assets) {
    //     require(swapArgs.length == 1, LibErrors.MonoAssetSwap());
    //     require(swapArgs[0].tokenIn == IFundsFacet(yelayLiteVault).underlyingAsset());

    //     uint256 amount = IFundsFacet(yelayLiteVault).redeem(shares, projectId, address(this));

    //     ERC20(swapArgs[0].tokenIn).safeTransfer(address(swapper), amount);
    //     assets = swapper.swap(swapArgs, tokenOut);
    //     if (tokenOut == address(weth) && unwrapWeth) {
    //         weth.withdraw(assets);
    //         payable(msg.sender).transfer(assets);
    //     } else {
    //         ERC20(tokenOut).safeTransfer(msg.sender, assets);
    //     }
    //     uint256 returnBalance = ERC20(swapArgs[0].tokenIn).balanceOf(address(this));
    //     if (returnBalance > 0) {
    //         ERC20(swapArgs[0].tokenIn).safeTransfer(msg.sender, returnBalance);
    //     }
    // }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}

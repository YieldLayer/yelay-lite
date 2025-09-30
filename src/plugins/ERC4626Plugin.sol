// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC1155HolderUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

contract ERC4626Plugin is ERC1155HolderUpgradeable, ERC4626Upgradeable {
    using SafeTransferLib for ERC20;
    using Math for uint256;

    YieldExtractor public immutable yieldExtractor;

    IYelayLiteVault public yelayLiteVault;
    uint256 public projectId;

    constructor(YieldExtractor _yieldExtractor) {
        yieldExtractor = _yieldExtractor;
    }

    function initialize(string memory name, string memory symbol, address _yelayLiteVault, uint256 _projectId)
        external
        initializer
    {
        projectId = _projectId;
        yelayLiteVault = IYelayLiteVault(_yelayLiteVault);
        address asset = yelayLiteVault.underlyingAsset();
        IERC20(asset).approve(address(yelayLiteVault), type(uint256).max);
        __ERC1155Holder_init();
        __ERC4626_init(IERC20(asset));
        __ERC20_init(name, symbol);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);
        yelayLiteVault.deposit(assets, projectId, address(this));
        return shares;
    }

    function mint(uint256 shares, address receiver) public override returns (uint256) {
        uint256 assets = super.mint(shares, receiver);
        yelayLiteVault.deposit(assets, projectId, address(this));
        return assets;
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 yelayLiteShares =
            shares.mulDiv(yelayLiteVault.balanceOf(address(this), projectId), totalSupply(), Math.Rounding.Floor);

        uint256 assets = yelayLiteVault.redeem(yelayLiteShares, projectId, address(this));

        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 yelayLiteShares =
            shares.mulDiv(yelayLiteVault.balanceOf(address(this), projectId), totalSupply(), Math.Rounding.Floor);
        return yelayLiteVault.previewRedeem(yelayLiteShares);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }
        uint256 yelayLiteShares = yelayLiteVault.previewWithdraw(assets);
        uint256 shares = yelayLiteShares.mulDiv(
            totalSupply(), yelayLiteVault.balanceOf(address(this), projectId), Math.Rounding.Ceil
        );

        uint256 assetsReceived = yelayLiteVault.redeem(yelayLiteShares, projectId, address(this));

        require(assetsReceived >= assets, LibErrors.WithdrawSlippageExceeded(assets, assetsReceived));

        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 yelayLiteShares = yelayLiteVault.previewWithdraw(assets);
        uint256 shares = yelayLiteShares.mulDiv(
            totalSupply(), yelayLiteVault.balanceOf(address(this), projectId), Math.Rounding.Ceil
        );
        return shares;
    }

    function accrue(YieldExtractor.ClaimRequest[] calldata data) external {
        yieldExtractor.transform(data);
        skim();
    }

    function skim() public {
        uint256 assets = IERC20(asset()).balanceOf(address(this));
        if (assets > 0) {
            yelayLiteVault.deposit(assets, projectId, address(this));
            emit LibEvents.ERC4626PluginAssetsSkimmed(assets);
        }
    }

    function totalAssets() public view override returns (uint256) {
        uint256 shares = yelayLiteVault.balanceOf(address(this), projectId);
        return yelayLiteVault.convertToAssets(shares);
    }
}

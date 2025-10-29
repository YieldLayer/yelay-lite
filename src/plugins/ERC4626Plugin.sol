// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC1155HolderUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

/**
 * @title ERC4626Plugin
 * @notice An ERC4626 vault plugin that wraps YelayLiteVault functionality
 * @dev This contract implements the ERC4626 standard for tokenized vaults and integrates
 *      with the YelayLiteVault system. It allows users to deposit assets and receive
 *      shares that represent their proportional ownership of the underlying vault.
 */
contract ERC4626Plugin is ERC1155HolderUpgradeable, ERC4626Upgradeable {
    using Math for uint256;

    // ============ Constants ============

    /// @notice The yield extractor contract used for yield accrual
    YieldExtractor public immutable yieldExtractor;

    // ============ State Variables ============

    /// @notice The YelayLiteVault contract this plugin integrates with
    IYelayLiteVault public yelayLiteVault;

    /// @notice The project ID within the YelayLiteVault system
    uint256 public projectId;

    /// @notice Decimal offset for proper scaling between asset and share decimals
    uint8 public DECIMALS_OFFSET;

    // ============ Constructor ============

    /**
     * @notice Initializes the ERC4626Plugin with the yield extractor
     * @param _yieldExtractor The address of the yield extractor contract
     */
    constructor(address _yieldExtractor) {
        yieldExtractor = YieldExtractor(_yieldExtractor);
    }

    // ============ Initialization ============

    /**
     * @notice Initializes the plugin with vault parameters
     * @param name The name of the ERC20 token
     * @param symbol The symbol of the ERC20 token
     * @param _yelayLiteVault The address of the YelayLiteVault contract
     * @param _projectId The project ID within the YelayLiteVault system
     * @dev This function sets up the ERC4626 vault with the underlying asset from YelayLiteVault
     *      and calculates the decimal offset for proper scaling
     */
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
        DECIMALS_OFFSET = uint8(FixedPointMathLib.zeroFloorSub(18, IERC20Metadata(asset).decimals()));
    }

    // ============ Yield Management ============

    /**
     * @notice Accrues yield by processing a claim request through the yield extractor
     * @param data The claim request data containing yield extraction parameters
     */
    function accrue(YieldExtractor.ClaimRequest calldata data) external {
        yieldExtractor.transform(data);
    }

    /**
     * @notice Skims loose underlying assets held by the plugin and deposits them into YelayLiteVault.
     * @return assets The amount of assets swept into the vault.
     * @dev This function keeps funds productive by forwarding any unaccounted assets to YelayLiteVault
     *      and emits an event when a positive amount is skimmed.
     */
    function skim() external returns (uint256) {
        uint256 assets = IERC20(asset()).balanceOf(address(this));
        if (assets > 0) {
            yelayLiteVault.deposit(assets, projectId, address(this));
            emit LibEvents.ERC4626PluginAssetsSkimmed(assets);
        }
        return assets;
    }

    // ============ ERC4626 Overrides ============

    /**
     * @notice Deposits assets and mints shares to the receiver
     * @param assets The amount of assets to deposit
     * @param receiver The address to receive the minted shares
     * @return shares The amount of shares minted
     * @dev Overrides the standard deposit function to also deposit assets to YelayLiteVault
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        require(assets > 0, LibErrors.ZeroValue());
        uint256 shares = super.deposit(assets, receiver);
        require(shares > 0, LibErrors.ZeroValue());
        yelayLiteVault.deposit(assets, projectId, address(this));
        return shares;
    }

    /**
     * @notice Mints shares to the receiver for the specified amount of assets
     * @param shares The amount of shares to mint
     * @param receiver The address to receive the minted shares
     * @return assets The amount of assets deposited
     * @dev Overrides the standard mint function to also deposit assets to YelayLiteVault
     */
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        require(shares > 0, LibErrors.ZeroValue());
        uint256 assets = super.mint(shares, receiver);
        require(assets > 0, LibErrors.ZeroValue());
        yelayLiteVault.deposit(assets, projectId, address(this));
        return assets;
    }

    /**
     * @notice Redeems shares for assets from the specified owner
     * @param shares The amount of shares to redeem
     * @param receiver The address to receive the assets
     * @param owner The owner of the shares
     * @return assets The amount of assets received
     * @dev Redeems shares by withdrawing from YelayLiteVault and transferring assets to receiver
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        require(shares > 0, LibErrors.ZeroValue());

        uint256 maxShares = maxRedeem(owner);
        require(shares <= maxShares, ERC4626ExceededMaxRedeem(owner, shares, maxShares));

        uint256 assets = previewRedeem(shares);
        require(assets > 0, LibErrors.ZeroValue());

        _withdraw(assets);

        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @notice Withdraws assets for the specified owner
     * @param assets The amount of assets to withdraw
     * @param receiver The address to receive the assets
     * @param owner The owner of the shares
     * @return shares The amount of shares burned
     * @dev Withdraws assets with slippage protection to ensure minimum asset amount is received
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        require(assets > 0, LibErrors.ZeroValue());

        uint256 maxAssets = maxWithdraw(owner);
        require(assets <= maxAssets, ERC4626ExceededMaxWithdraw(owner, assets, maxAssets));

        uint256 shares = previewWithdraw(assets);
        require(shares > 0, LibErrors.ZeroValue());

        _withdraw(assets);

        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    // ============ View Functions ============

    /**
     * @notice Returns the total amount of assets managed by this vault
     * @return assets The total amount of assets
     * @dev Includes both assets in YelayLiteVault and any loose assets in the contract
     */
    function totalAssets() public view override returns (uint256) {
        uint256 shares = yelayLiteVault.balanceOf(address(this), projectId);
        return yelayLiteVault.convertToAssets(shares) + IERC20(asset()).balanceOf(address(this));
    }

    // ============ Internal Functions ============

    /**
     * @dev Withdraws from YelayLiteVault
     */
    function _withdraw(uint256 assets) internal {
        uint256 preview = yelayLiteVault.previewWithdraw(assets);
        uint256 balance = yelayLiteVault.balanceOf(address(this), projectId);
        // for last withdrawal preview might be bigger than actual balance
        uint256 toRedeem = FixedPointMathLib.min(preview, balance);

        uint256 assetsReceived = yelayLiteVault.redeem(toRedeem, projectId, address(this));
        uint256 assetsBalance = IERC20(asset()).balanceOf(address(this));

        require(assetsReceived + assetsBalance >= assets, LibErrors.WithdrawSlippageExceeded(assets, assetsReceived));
    }

    /**
     * @notice Returns the decimal offset for proper scaling
     * @return offset The decimal offset value
     */
    function _decimalsOffset() internal view override returns (uint8) {
        return DECIMALS_OFFSET;
    }
}

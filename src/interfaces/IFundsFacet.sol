// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFundsFacetBase} from "./IFundsFacetBase.sol";

interface IFundsFacet is IFundsFacetBase {
    /**
     * @dev Redeems shares from the contract.
     * @param shares The amount of shares to redeem.
     * @param projectId The project ID.
     * @param receiver The address of the receiver.
     * @return assets The amount of assets redeemed.
     */
    function redeem(uint256 shares, uint256 projectId, address receiver) external returns (uint256 assets);

    /**
     * @notice Transforms yield shares from the yield project to regular shares for a specific project
     * @dev This function converts yield shares (project ID 0) to regular project shares and transfers them to the receiver
     * @param projectId The target project ID to transform yield shares into
     * @param shares The amount of yield shares to transform
     * @param receiver The address that will receive the transformed shares
     */
    function transformYieldShares(uint256 projectId, uint256 shares, address receiver) external;

    /**
     * @notice Converts a given amount of assets to the equivalent amount of shares
     * @dev Uses the current exchange rate between assets and shares to perform the conversion
     * @param assets The amount of underlying assets to convert
     * @return The equivalent amount of shares for the given assets
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @notice Converts a given amount of shares to the equivalent amount of assets
     * @dev Uses the current exchange rate between shares and assets to perform the conversion
     * @param shares The amount of shares to convert
     * @return The equivalent amount of underlying assets for the given shares
     */
    function convertToAssets(uint256 shares) external view returns (uint256);

    /**
     * @notice Previews the amount of assets that would be received when redeeming a given amount of shares
     * @dev This function simulates a redeem operation without executing it, accounting for any fees or slippage
     * @param shares The amount of shares to preview redemption for
     * @return The amount of assets that would be received upon redemption
     */
    function previewRedeem(uint256 shares) external view returns (uint256);

    /**
     * @notice Previews the amount of shares required to withdraw a specific amount of assets
     * @dev This function simulates a withdraw operation without executing it, accounting for any fees or slippage
     * @param assets The amount of assets to preview withdrawal for
     * @return The amount of shares that would be required to withdraw the specified assets
     */
    function previewWithdraw(uint256 assets) external view returns (uint256);
}

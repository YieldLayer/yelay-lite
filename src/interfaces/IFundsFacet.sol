// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {Reward} from "./IStrategyBase.sol";
import {SwapArgs} from "./ISwapper.sol";

struct StrategyArgs {
    uint256 index;
    uint256 amount;
}

interface IFundsFacet is IERC1155, IERC1155MetadataURI {
    /**
     * @dev Returns the total supply of tokens.
     * @return The total supply of tokens.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the total supply of tokens for a given ID.
     * @param id The token ID.
     * @return The total supply of tokens for the given ID.
     */
    function totalSupply(uint256 id) external view returns (uint256);

    /**
     * @dev Returns the last total assets value.
     * @return The last total assets value.
     */
    function lastTotalAssets() external view returns (uint256);

    /**
     * @dev Returns the underlying balance of the contract.
     * @return The underlying balance.
     */
    function underlyingBalance() external view returns (uint256);

    /**
     * @dev Returns the address of the underlying asset.
     * @return The address of the underlying asset.
     */
    function underlyingAsset() external view returns (address);

    /**
     * @dev Returns the address of the yield extractor.
     * @return The address of the yield extractor.
     */
    function yieldExtractor() external view returns (address);

    /**
     * @dev Sets the new yield extractor address.
     * @dev Callable by STRATEGY_AUTHORITY.
     * @param _yieldExtractor address.
     */
    function setYieldExtractor(address _yieldExtractor) external;

    /**
     * @dev Returns the address of the swapper.
     * @return The address of the swapper.
     */
    function swapper() external view returns (address);

    /**
     * @dev Returns the address of the merkl distributor.
     * @return The address of the merkl distributor.
     */
    function merklDistributor() external view returns (address);

    /**
     * @dev Returns the total assets managed by the contract.
     * @return assets The total assets managed by the contract.
     */
    function totalAssets() external view returns (uint256 assets);

    /**
     * @dev Returns the assets managed by a specific strategy.
     * @param index The index of the strategy.
     * @return The assets managed by the strategy.
     */
    function strategyAssets(uint256 index) external view returns (uint256);

    /**
     * @dev Returns the rewards for a specific strategy.
     * @param index The index of the strategy.
     * @return rewards The rewards for the strategy.
     */
    function strategyRewards(uint256 index) external view returns (Reward[] memory rewards);

    /**
     * @dev Deposits assets into the contract.
     * @param assets The amount of assets to deposit.
     * @param projectId The project ID.
     * @param receiver The address of the receiver.
     * @return shares The amount of shares minted.
     */
    function deposit(uint256 assets, uint256 projectId, address receiver) external returns (uint256 shares);

    /**
     * @dev Redeems shares from the contract.
     * @param shares The amount of shares to redeem.
     * @param projectId The project ID.
     * @param receiver The address of the receiver.
     * @return assets The amount of assets redeemed.
     */
    function redeem(uint256 shares, uint256 projectId, address receiver) external returns (uint256 assets);

    /**
     * @dev Migrates a position from one project to another.
     * @param fromProjectId The ID of the project to migrate from.
     * @param toProjectId The ID of the project to migrate to.
     * @param amount The amount to migrate.
     */
    function migratePosition(uint256 fromProjectId, uint256 toProjectId, uint256 amount) external;

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

    /**
     * @dev Deposits assets into a strategy.
     * @dev Callable by FUNDS_OPERATOR.
     * @param strategyArgs The strategy arguments.
     */
    function managedDeposit(StrategyArgs calldata strategyArgs) external;

    /**
     * @dev Withdraws assets from a strategy.
     * @dev Callable by FUNDS_OPERATOR.
     * @param strategyArgs The strategy arguments.
     */
    function managedWithdraw(StrategyArgs calldata strategyArgs) external;

    /**
     * @dev Reallocates assets between strategies.
     * @dev Callable by FUNDS_OPERATOR.
     * @param withdrawals The strategy arguments for withdrawals.
     * @param deposits The strategy arguments for deposits.
     */
    function reallocate(StrategyArgs[] calldata withdrawals, StrategyArgs[] calldata deposits) external;

    /**
     * @dev Compounds rewards by swapping them for the underlying asset.
     * @dev Callable by SWAP_REWARDS_OPERATOR.
     * @param swapArgs The swap arguments.
     * @return compounded The amount compounded.
     */
    function swapRewards(SwapArgs[] memory swapArgs) external returns (uint256 compounded);

    /**
     * @dev Compounds rewards in underlying asset.
     * @dev Callable by SWAP_REWARDS_OPERATOR.
     * @return compounded The amount compounded.
     */
    function compoundUnderlyingReward() external returns (uint256 compounded);

    /**
     * @dev Accrues fees.
     */
    function accrueFee() external;

    /**
     * @dev Claims rewards from a strategy.
     * @dev Callable by FUNDS_OPERATOR.
     * @param index The index of the strategy.
     */
    function claimStrategyRewards(uint256 index) external;

    /**
     * @dev Claims rewards from the merkl distributor.
     * @dev Callable by FUNDS_OPERATOR.
     * @param tokens Array of ERC20 tokens to be claimed.
     * @param amounts Array of token amounts to be claimed.
     * @param proofs Array of merkle proofs required to validate each claim.
     */
    function claimMerklRewards(address[] calldata tokens, uint256[] calldata amounts, bytes32[][] calldata proofs)
        external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibErrors {
    // ===================== OwnerFacet ================================
    /**
     * @dev The caller account is not authorized to perform an operation.
     * @param account The address of the unauthorized account.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The function selector is invalid.
     * @param selector The invalid function selector.
     */
    error InvalidSelector(bytes4 selector);

    // ===================== ClientsFacet ================================
    /**
     * @dev The owner address is already used by some client.
     */
    error ClientOwnerReserved();

    /**
     * @dev The caller is not the client owner.
     */
    error NotClientOwner();

    /**
     * @dev The project ID is out of bounds.
     */
    error OutOfBoundProjectId();

    /**
     * @dev The project is already active.
     */
    error ProjectActive();

    /**
     * @dev The client name is empty.
     */
    error ClientNameEmpty();

    /**
     * @dev The client name is empty.
     */
    error ReservedProjectsIsZero();

    /**
     * @dev The client name is already taken.
     */
    error ClientNameTaken();

    // ===================== FundsFacet ================================
    /**
     * @dev The project is inactive.
     */
    error ProjectInactive();

    /**
     * @dev The function can only be called in a view context.
     */
    error OnlyView();

    /**
     * @dev Compounding the underlying asset is forbidden.
     */
    error CompoundUnderlyingForbidden();

    /**
     * @dev Position migration is forbidden.
     */
    error PositionMigrationForbidden();

    /**
     * @dev There is not enough underlying assets in YelayLiteVault to cover redeem.
     */
    error NotEnoughInternalFunds();

    /**
     * @dev Redeem doesn't pass minimum asset amount
     */
    error MinRedeem();

    /**
     * @dev During swapRewards totalAssets have been reduced
     */
    error TotalAssetsLoss();

    /**
     * @dev Caller can be only YieldExtractor
     */
    error OnlyYieldExtractor();

    // ===================== SwapWrapper ================================
    /**
     * @dev The token is not WETH.
     */
    error NotWeth();

    /**
     * @dev No ETH available.
     */
    error NoEth();

    // ===================== ManagementFacet ================================
    /**
     * @dev The assets were not withdrawn from strategy.
     */
    error StrategyNotEmpty();

    /**
     * @dev The strategy is already registered.
     */
    error StrategyRegistered();

    /**
     * @dev The strategy is already active.
     */
    error StrategyActive();

    // ===================== LibPausable ================================
    /**
     * @dev The function is paused.
     * @param selector The function selector that is paused.
     */
    error Paused(bytes4 selector);

    // ===================== Swapper ================================

    /**
     * @notice Used when trying to do a swap via an exchange that is not allowed to execute a swap.
     * @param exchange Exchange used.
     */
    error ExchangeNotAllowed(address exchange);

    /**
     * @notice Used when there is nothing to swap.
     * @param tokenIn The token that was intended to be swapped.
     */
    error NothingToSwap(address tokenIn);

    /**
     * @notice Used when nothing was swapped.
     * @param tokenOut The token that was intended to be received.
     */
    error NothingSwapped(address tokenOut);

    // ===================== DepositLockPlugin ================================

    /**
     * @dev The caller is not the project owner.
     * @param vault The address of the vault.
     * @param projectId The ID of the project.
     * @param caller The address of the caller.
     */
    error NotProjectOwner(address vault, uint256 projectId, address caller);

    /**
     * @dev The lock period exceeds the maximum allowable period.
     * @param lockPeriod The lock period.
     */
    error LockPeriodExceedsMaximum(uint256 lockPeriod);

    /**
     * @dev Lock Mode is unset for the project.
     * @param vault The address of the vault.
     * @param projectId The ID of the project.
     */
    error LockModeNotSetForProject(address vault, uint256 projectId);

    /**
     * @dev The requested shares to remove is not available.
     * @param requested The requested shares to remove.
     * @param available The available shares to remove.
     */
    error NotEnoughShares(uint256 requested, uint256 available);

    /**
     * @dev The project is still locked, withdrawals are not allowed.
     * @param unlockTime The unlock time.
     */
    error GlobalUnlockTimeNotReached(uint256 unlockTime);

    /**
     * @dev Project is unlocked, deposits are not allowed.
     * @param unlockTime The unlock time.
     */
    error GlobalUnlockTimeReached(uint256 unlockTime);

    /**
     * @dev The lock mode is already set for the project.
     * @param vault The address of the vault.
     * @param projectId The ID of the project.
     * @param lockMode The lock mode.
     */
    error LockModeAlreadySet(address vault, uint256 projectId, uint256 lockMode);

    /**
     * @dev The lock mode mismatch for particular project.
     * @param vault The address of the vault.
     * @param projectId The ID of the project.
     * @param lockMode The lock mode.
     */
    error LockModeMismatch(address vault, uint256 projectId, uint256 lockMode);

    // ===================== YieldExtractor ================================

    /**
     * @notice Thrown when a Merkle proof is invalid
     * @param idx Index of the invalid claim request
     */
    error InvalidProof(uint256 idx);

    /**
     * @notice Thrown when a proof has already been claimed
     * @param idx Index of the already claimed proof
     */
    error ProofAlreadyClaimed(uint256 idx);

    /**
     * @notice Thrown when an invalid cycle number is provided
     */
    error InvalidCycle();

    // ===================== ERC4626Plugin ================================

    /**
     * @notice Thrown when the amount of assets received by ERC4626Plugin during a withdrawal is less than the requested amount
     * @param requested The amount of assets that were requested to be withdrawn
     * @param received The actual amount of assets received, which is less than requested
     */
    error WithdrawSlippageExceeded(uint256 requested, uint256 received);

    /**
     * @notice Thrown when the amount of assets or shares is zero
     */
    error ZeroValue();
}

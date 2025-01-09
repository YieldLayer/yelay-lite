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
     * @dev The minimum project ID is zero.
     */
    error MinIsZero();

    /**
     * @dev The maximum project ID is less than the minimum project ID.
     */
    error MaxLessThanMin();

    /**
     * @dev The minimum project ID is less than the last project ID.
     */
    error MinLessThanLastProjectId();

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
}

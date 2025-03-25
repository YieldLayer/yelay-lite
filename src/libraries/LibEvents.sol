// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibEvents {
    // FundsFacet
    /**
     * @dev Emitted when assets are deposited.
     * @param projectId The ID of the project.
     * @param sender The address of the sender.
     * @param receiver The address of the receiver.
     * @param assets The amount of assets deposited.
     * @param shares The amount of shares minted.
     */
    event Deposit(
        uint256 indexed projectId, address indexed sender, address indexed receiver, uint256 assets, uint256 shares
    );

    /**
     * @dev Emitted when assets are redeemed.
     * @param projectId The ID of the project.
     * @param sender The address of the sender.
     * @param receiver The address of the receiver.
     * @param assets The amount of assets redeemed.
     * @param shares The amount of shares burned.
     */
    event Redeem(
        uint256 indexed projectId, address indexed sender, address indexed receiver, uint256 assets, uint256 shares
    );

    /**
     * @dev Emitted when assets are deposited into a strategy.
     * @param strategy The name of the strategy.
     * @param amount The amount of assets deposited.
     */
    event ManagedDeposit(bytes32 indexed strategy, uint256 amount);

    /**
     * @dev Emitted when assets are withdrawn from a strategy.
     * @param strategy The name of the strategy.
     * @param amount The amount of assets withdrawn.
     */
    event ManagedWithdraw(bytes32 indexed strategy, uint256 amount);

    /**
     * @dev Emitted when interest is accrued.
     * @param newTotalAssets The new total assets value.
     * @param interest The amount of interest accrued.
     * @param feeShares The amount of fee shares minted.
     */
    event AccrueInterest(uint256 newTotalAssets, uint256 interest, uint256 feeShares);

    /**
     * @dev Emitted when the last total assets value is updated.
     * @param lastTotalAssets The updated last total assets value.
     */
    event UpdateLastTotalAssets(uint256 lastTotalAssets);

    /**
     * @dev Emitted when the yield extractor address is updated.
     * @param newYieldExtractor address.
     */
    event UpdateYieldExtractor(address newYieldExtractor);

    /**
     * @dev Emitted when assets are compounded.
     * @param amount The amount of assets compounded.
     */
    event Compounded(uint256 amount);

    /**
     * @dev Emitted when a position is migrated.
     * @param account The address of the account.
     * @param fromProjectId The ID of the project from which the position is migrated.
     * @param toProjectId The ID of the project to which the position is migrated.
     * @param shares The amount of shares migrated.
     */
    event PositionMigrated(
        address indexed account, uint256 indexed fromProjectId, uint256 indexed toProjectId, uint256 shares
    );

    /**
     * @dev Emitted when lastTotalAssetsUpdateInterval is updated.
     * @param newInterval The new interval for updating lastTotalAssets.
     */
    event UpdateLastTotalAssetsUpdateInterval(uint256 newInterval);

    // ManagementFacet
    /**
     * @dev Emitted when the deposit queue is updated.
     */
    event UpdateDepositQueue();

    /**
     * @dev Emitted when the withdraw queue is updated.
     */
    event UpdateWithdrawQueue();

    /**
     * @dev Emitted when a strategy is added.
     * @param strategy The address of the strategy.
     * @param supplement Additional data for the strategy.
     */
    event AddStrategy(address indexed strategy, bytes supplement);

    /**
     * @dev Emitted when a strategy is removed.
     * @param strategy The address of the strategy.
     * @param supplement Additional data for the strategy.
     */
    event RemoveStrategy(address indexed strategy, bytes supplement);

    /**
     * @dev Emitted when a strategy is activate.
     * @param strategy The address of the strategy.
     * @param supplement Additional data for the strategy.
     */
    event ActivateStrategy(address indexed strategy, bytes supplement);

    /**
     * @dev Emitted when a strategy is deactivated.
     * @param strategy The address of the strategy.
     * @param supplement Additional data for the strategy.
     */
    event DeactivateStrategy(address indexed strategy, bytes supplement);

    // ClientsFacet
    /**
     * @dev Emitted when new project IDs are assigned to a client.
     * @param owner The address of the client owner.
     * @param minProjectId The minimum project ID.
     * @param maxProjectId The maximum project ID.
     */
    event NewProjectIds(address indexed owner, uint256 minProjectId, uint256 maxProjectId);

    /**
     * @dev Emitted when project ownership is transferred.
     * @param clientName The name of the client.
     * @param oldOwner The address of the old owner.
     * @param newOwner The address of the new owner.
     */
    event ClientOwnershipTransfer(bytes32 indexed clientName, address indexed oldOwner, address indexed newOwner);

    /**
     * @dev Emitted when a project is activated.
     * @param project The ID of the activated project.
     */
    event ProjectActivated(uint256 indexed project);

    // OwnerFacet
    /**
     * @dev Emitted when the ownership transfer process is started.
     * @param previousOwner The address of the previous owner.
     * @param newOwner The address of the new owner.
     */
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Emitted when the ownership transfer process is completed.
     * @param previousOwner The address of the previous owner.
     * @param newOwner The address of the new owner.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Emitted when a function selector is mapped to a facet.
     * @param selector The function selector.
     * @param facet The address of the facet.
     */
    event SelectorToFacetSet(bytes4 indexed selector, address indexed facet);

    // AccessFacet
    /**
     * @dev Emitted when a method is paused or unpaused.
     * @param selector The function selector.
     * @param paused The paused state.
     */
    event PausedChange(bytes4 selector, bool paused);

    // Swapper
    /**
     * @notice Emitted when the exchange allowlist is updated.
     * @param exchange Exchange that was updated.
     * @param isAllowed Whether the exchange is allowed to be used in a swap or not after the update.
     */
    event ExchangeAllowlistUpdated(address indexed exchange, bool isAllowed);

    // DepositLockPlugin
    /**
     * @notice Event emitted when a deposit is locked in a vault.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param user The address of the user.
     * @param shares The amount of shares locked.
     * @param assets The amount of underlying assets deposited.
     */
    event DepositLocked(
        address indexed user, address indexed vault, uint256 indexed projectId, uint256 shares, uint256 assets
    );

    /**
     * @notice Event emitted when a user redeems locked shares in a vault.
     * @param user The address of the user.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param shares The amount of shares redeemed.
     * @param assets The amount of underlying assets redeemed.
     */
    event RedeemLocked(
        address indexed user, address indexed vault, uint256 indexed projectId, uint256 shares, uint256 assets
    );

    /**
     * @notice Event emitted when a user's shares are migrated from one project to another.
     * @param user The address of the user.
     * @param vault The address of the vault.
     * @param fromProjectId The project identifier from which the position is migrated.
     * @param toProjectId The project identifier to which the position is migrated.
     * @param shares The amount of shares migrated.
     */
    event MigrateLocked(
        address indexed user, address indexed vault, uint256 fromProjectId, uint256 toProjectId, uint256 shares
    );

    /**
     * @notice Event emitted when the lock period for a project in a vault is updated.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param lockPeriod The new lock period.
     */
    event LockPeriodUpdated(address indexed vault, uint256 indexed projectId, uint256 lockPeriod);

    /**
     * @notice Event emitted when the global unlock time for a vault is updated.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param unlockTime The new global unlock time.
     */
    event GlobalUnlockTimeUpdated(address indexed vault, uint256 indexed projectId, uint256 unlockTime);
}

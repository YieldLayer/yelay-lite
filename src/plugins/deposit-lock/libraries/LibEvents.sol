// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibEvents {
    /**
     * @notice Event emitted when a deposit is locked in a vault.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param user The address of the user.
     * @param shares The amount of shares locked.
     */
    event DepositLocked(address indexed vault, uint256 indexed projectId, address indexed user, uint256 shares);

    /**
     * @notice Event emitted when a user redeems locked shares in a vault.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param user The address of the user.
     * @param shares The amount of shares redeemed.
     * @param assets The amount of underlying assets redeemed.
     */
    event RedeemLocked(
        address indexed vault, uint256 indexed projectId, address indexed user, uint256 shares, uint256 assets
    );

    /**
     * @notice Event emitted when a user's shares are migrated from one project to another.
     * @param user The address of the user.
     * @param fromProjectId The project identifier from which the position is migrated.
     * @param toProjectId The project identifier to which the position is migrated.
     * @param shares The amount of shares migrated.
     */
    event MigrateLocked(
        address indexed user, uint256 indexed fromProjectId, uint256 indexed toProjectId, uint256 shares
    );

    /**
     * @notice Event emitted when the lock period for a project in a vault is updated.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param lockPeriod The new lock period.
     */
    event LockPeriodUpdated(address indexed vault, uint256 indexed projectId, uint256 lockPeriod);
}

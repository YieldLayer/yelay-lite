// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibErrors {
    /**
     * @dev The caller is not the project owner.
     * @param projectId The ID of the project.
     * @param caller The address of the caller.
     */
    error NotProjectOwner(uint256 projectId, address caller);

    /**
     * @dev The lock period exceeds the maximum allowable period.
     * @param lockPeriod The lock period.
     */
    error LockPeriodExceedsMaximum(uint256 lockPeriod);

    /**
     * @dev The lock period is not set for the project.
     * @param projectId The ID of the project.
     */
    error DepositLockNotSetForProject(uint256 projectId);

    /**
     * @dev The requested shares to remove is not available.
     * @param requested The requested shares to remove.
     * @param remaining Remaining shares from requested amount.
     */
    error NotEnoughShares(uint256 requested, uint256 remaining);
}

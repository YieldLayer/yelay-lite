// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibErrors {
    // ===================== SelfOnly ================================
    error NotSelf();

    // ===================== OwnerFacet ================================
    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    error InvalidSelector(bytes4 selector);

    // ===================== ClientsFacet ================================

    error MinIsZero();
    error MaxLessThanMin();
    error MinLessThanNextProjectId();
    error NotClientOwner();
    error OutOfBoundProjectId();
    error ProjectInterceptorIsNone();
    error ProjectInterceptorIsSet();
    error ProjectInterceptorIsNotLock();
    error ProjectIsActive();
    error ClientNameEmpty();
    error ClientNameIsTaken();
    error UserLocked();

    // ===================== FundsFacet ================================

    error ProjectInactive();
    error NotEnoughAssets();
    error NotEnoughLiquidity();
    error OnlyView();
    error CompoundUnderlyingForbidden();
    error PositionMigrationForbidden();
}

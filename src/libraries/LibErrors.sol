// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// how come errors are defined in a library?
// instead of them being defined
// - on the facets themselves
// - or just in a file

library LibErrors {
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
    error MinLessThanLastProjectId();
    error NotClientOwner();
    error OutOfBoundProjectId();
    error ProjectActive();
    error ClientNameEmpty();
    error ClientNameTaken();

    // ===================== FundsFacet ================================

    error ProjectInactive();
    error OnlyView();
    error CompoundUnderlyingForbidden();
    error PositionMigrationForbidden();

    // ===================== SwapWrapper ================================

    error NotWeth();
    error NoEth();

    // ===================== ManagementFacet ================================

    error StrategyNotEmpty();
}

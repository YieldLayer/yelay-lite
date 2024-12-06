// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibErrors {
    // OwnerFacet
    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    error InvalidSelector(bytes4 selector);
}

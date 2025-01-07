// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {AccessFacet} from "src/facets/AccessFacet.sol";

/**
 * @title RoleCheck
 * @dev Abstract contract that provides a modifier to check if the caller has a specific role.
 */
abstract contract RoleCheck {
    using Address for address;

    /**
     * @dev Modifier to make a function callable only by accounts with a specific role.
     * @param role The role identifier.
     */
    modifier onlyRole(bytes32 role) {
        address(this).functionDelegateCall(abi.encodeWithSelector(AccessFacet.checkRole.selector, role));
        _;
    }
}

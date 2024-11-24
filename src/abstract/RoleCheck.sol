// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/utils/Address.sol";

import {AccessFacet} from "src/facets/AccessFacet.sol";

abstract contract RoleCheck {
    using Address for address;

    modifier onlyRole(bytes32 role) {
        address(this).functionDelegateCall(abi.encodeWithSelector(AccessFacet.checkRole.selector, role));
        _;
    }
}

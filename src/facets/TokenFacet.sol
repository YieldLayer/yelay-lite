// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20PermitUpgradeable} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import {SelfOnly} from "src/abstract/SelfOnly.sol";

// TODO: decimals always 18?
contract TokenFacet is ERC20PermitUpgradeable, SelfOnly {
    // TODO: decide how to support multiple initializers
    function initializeTokenFacet(string memory name_, string memory symbol_) external {
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
    }

    // TODO: remove hack
    function _checkInitializing() internal view override {}

    function mint(address account, uint256 value) external onlySelf {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlySelf {
        _burn(account, value);
    }
}

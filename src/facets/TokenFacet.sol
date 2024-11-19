// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {SelfOnly} from "src/abstract/SelfOnly.sol";

// TODO: decimals always 18?
contract TokenFacet is ERC20Upgradeable, SelfOnly {
    function mint(address account, uint256 value) external onlySelf {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlySelf {
        _burn(account, value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract Atomic is ERC20Upgradeable {
    function atomicInitialize(string memory name_, string memory symbol_) external initializer {
        __ERC20_init(name_, symbol_);
    }
}

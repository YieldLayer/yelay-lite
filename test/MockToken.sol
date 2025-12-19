// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {}
}

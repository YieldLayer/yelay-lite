// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";

contract MetamorphoStrategy is ERC4626Strategy {
    constructor(address erc4626Vault_) ERC4626Strategy(erc4626Vault_) {}
}

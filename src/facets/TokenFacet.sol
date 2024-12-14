// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155SupplyUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

import {SelfOnly} from "src/abstract/SelfOnly.sol";
import {LibToken} from "src/libraries/LibToken.sol";

import {ITokenFacet} from "src/interfaces/ITokenFacet.sol";

contract TokenFacet is ERC1155SupplyUpgradeable, SelfOnly, ITokenFacet {
    function mint(address to, uint256 id, uint256 value) external onlySelf {
        _mint(to, id, value, "");
    }

    function burn(address from, uint256 id, uint256 value) external onlySelf {
        _burn(from, id, value);
    }

    function migrate(address account, uint256 fromId, uint256 toId, uint256 value) external onlySelf {
        _burn(account, fromId, value);
        _mint(account, toId, value, "");
    }

    function totalSupply() public view override(ERC1155SupplyUpgradeable, ITokenFacet) returns (uint256) {
        return super.totalSupply();
    }

    function totalSupply(uint256 id) public view override(ERC1155SupplyUpgradeable, ITokenFacet) returns (uint256) {
        return super.totalSupply(id);
    }
}

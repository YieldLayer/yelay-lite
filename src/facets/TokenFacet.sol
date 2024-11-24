// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155Upgradeable} from "@openzeppelin-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

import {SelfOnly} from "src/abstract/SelfOnly.sol";
import {LibToken} from "src/libraries/LibToken.sol";

import {ITokenFacet} from "src/interfaces/ITokenFacet.sol";

// TODO: decimals always 18?
contract TokenFacet is ERC1155Upgradeable, SelfOnly, ITokenFacet {
    function mint(address to, uint256 id, uint256 value) external onlySelf {
        _mint(to, id, value, "");
    }

    function burn(address from, uint256 id, uint256 value) external onlySelf {
        _burn(from, id, value);
    }

    function totalSupply() external view returns (uint256) {
        return LibToken.totalSupply();
    }
}

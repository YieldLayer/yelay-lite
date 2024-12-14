// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

interface ITokenFacet is IERC1155, IERC1155MetadataURI {
    function totalSupply() external view returns (uint256);
    function totalSupply(uint256 id) external view returns (uint256);
}

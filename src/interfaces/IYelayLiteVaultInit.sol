// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISwapper} from "src/interfaces/ISwapper.sol";

interface IYelayLiteVaultInit {
    function init(ISwapper swapper, address underlyingAsset, address yieldExtractor, string memory uri) external;
}

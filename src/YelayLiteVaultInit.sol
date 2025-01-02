// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISwapper} from "src/interfaces/ISwapper.sol";
import {IYelayLiteVaultInit} from "src/interfaces/IYelayLiteVaultInit.sol";

import {LibFunds, ERC20} from "src/libraries/LibFunds.sol";
import {LibOwner} from "src/libraries/LibOwner.sol";

contract YelayLiteVaultInit is IYelayLiteVaultInit {
    function init(ISwapper swapper, address underlyingAsset, address yieldExtractor, string memory uri) public {
        LibOwner.onlyOwner();

        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        sF.underlyingAsset = ERC20(underlyingAsset);
        sF.yieldExtractor = yieldExtractor;
        sF.swapper = swapper;

        LibFunds.ERC1155Storage storage s = LibFunds._getERC1155Storage();
        s._uri = uri;
    }
}

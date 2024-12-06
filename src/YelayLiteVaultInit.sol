// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISwapper} from "src/interfaces/ISwapper.sol";
import {IYelayLiteVaultInit} from "src/interfaces/IYelayLiteVaultInit.sol";

import {LibFunds, ERC20} from "src/libraries/LibFunds.sol";
import {LibToken} from "src/libraries/LibToken.sol";
import {LibOwner} from "src/libraries/LibOwner.sol";

contract YelayLiteVaultInit is IYelayLiteVaultInit {
    function init(ISwapper swapper, address underlyingAsset, address yieldExtractor, string memory uri) public {
        LibOwner.onlyOwner();
        _initFunds(underlyingAsset, yieldExtractor, swapper);
        _initToken(uri);
    }

    function _initFunds(address underlyingAsset, address yieldExtractor, ISwapper swapper) internal {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();
        s.underlyingAsset = ERC20(underlyingAsset);
        s.yieldExtractor = yieldExtractor;
        s.swapper = swapper;
    }

    function _initToken(string memory uri) internal {
        LibToken.ERC1155Storage storage s = LibToken._getERC1155Storage();
        s._uri = uri;
    }
}

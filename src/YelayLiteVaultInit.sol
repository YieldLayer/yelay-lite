// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IERC173} from "@diamond/interfaces/IERC173.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";

import {LibFunds, ERC20} from "src/libraries/LibFunds.sol";
import {LibToken} from "src/libraries/LibToken.sol";

contract YelayLiteVaultInit {
    function init(address underlyingAsset, string memory name, string memory symbol) public {
        initDiamond();
        initFunds(underlyingAsset);
        initToken(name, symbol);
    }

    function initDiamond() public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }

    function initFunds(address underlyingAsset) public {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();
        s.underlyingAsset = ERC20(underlyingAsset);
    }

    function initToken(string memory name, string memory symbol) public {
        LibToken.ERC20Storage storage s = LibToken._getERC20Storage();
        s._name = name;
        s._symbol = symbol;
    }
}

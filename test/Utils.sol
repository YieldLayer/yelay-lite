// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {YelayLiteVaultInit} from "src/YelayLiteVaultInit.sol";
import {FundsFacet} from "src/facets/FundsFacet.sol";
import {TokenFacet, ERC20Upgradeable} from "src/facets/TokenFacet.sol";
import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

library Utils {
    function addTokenFacet(
        address diamond,
        YelayLiteVaultInit init,
        TokenFacet tokenFacet,
        string memory name,
        string memory symbol
    ) internal {
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](11);
        functionSelectors[0] = ERC20Upgradeable.name.selector;
        functionSelectors[1] = ERC20Upgradeable.symbol.selector;
        functionSelectors[2] = ERC20Upgradeable.decimals.selector;
        functionSelectors[3] = ERC20Upgradeable.transfer.selector;
        functionSelectors[4] = ERC20Upgradeable.transferFrom.selector;
        functionSelectors[5] = ERC20Upgradeable.approve.selector;
        functionSelectors[6] = ERC20Upgradeable.allowance.selector;
        functionSelectors[7] = ERC20Upgradeable.balanceOf.selector;
        functionSelectors[8] = ERC20Upgradeable.totalSupply.selector;
        functionSelectors[9] = TokenFacet.mint.selector;
        functionSelectors[10] = TokenFacet.burn.selector;

        diamondCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(tokenFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(diamond).diamondCut(
            diamondCut, address(init), abi.encodeWithSelector(YelayLiteVaultInit.initToken.selector, name, symbol)
        );
    }

    function addFundsFacet(address diamond, YelayLiteVaultInit init, FundsFacet fundsFacet, address underlyingAsset)
        internal
    {
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = FundsFacet.deposit.selector;
        functionSelectors[1] = FundsFacet.withdraw.selector;

        diamondCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(fundsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(diamond).diamondCut(
            diamondCut, address(init), abi.encodeWithSelector(YelayLiteVaultInit.initFunds.selector, underlyingAsset)
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FundsFacet} from "src/facets/FundsFacet.sol";
import {TokenFacet, ERC20PermitUpgradeable} from "src/facets/TokenFacet.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

library Utils {
    function addTokenFacet(address diamond, TokenFacet tokenFacet, string memory name, string memory symbol) internal {
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](15);
        functionSelectors[0] = TokenFacet.initializeTokenFacet.selector;
        functionSelectors[1] = ERC20Upgradeable.name.selector;
        functionSelectors[2] = ERC20Upgradeable.symbol.selector;
        functionSelectors[3] = ERC20Upgradeable.decimals.selector;
        functionSelectors[4] = ERC20Upgradeable.transfer.selector;
        functionSelectors[5] = ERC20Upgradeable.transferFrom.selector;
        functionSelectors[6] = ERC20Upgradeable.approve.selector;
        functionSelectors[7] = ERC20Upgradeable.allowance.selector;
        functionSelectors[8] = ERC20Upgradeable.balanceOf.selector;
        functionSelectors[9] = ERC20Upgradeable.totalSupply.selector;
        functionSelectors[10] = ERC20PermitUpgradeable.permit.selector;
        functionSelectors[11] = ERC20PermitUpgradeable.nonces.selector;
        functionSelectors[12] = ERC20PermitUpgradeable.DOMAIN_SEPARATOR.selector;
        functionSelectors[13] = TokenFacet.mint.selector;
        functionSelectors[14] = TokenFacet.burn.selector;

        diamondCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(tokenFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(diamond).diamondCut(
            diamondCut, diamond, abi.encodeWithSelector(TokenFacet.initializeTokenFacet.selector, name, symbol)
        );
    }

    function addFundsFacet(address diamond, FundsFacet fundsFacet, address underlyingAsset) internal {
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = FundsFacet.initializeFundsFacet.selector;
        functionSelectors[1] = FundsFacet.deposit.selector;
        functionSelectors[2] = FundsFacet.withdraw.selector;

        diamondCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(fundsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        DiamondCutFacet(diamond).diamondCut(
            diamondCut, diamond, abi.encodeWithSelector(FundsFacet.initializeFundsFacet.selector, underlyingAsset)
        );
    }
}

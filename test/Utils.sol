// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {YelayLiteVaultInit} from "src/YelayLiteVaultInit.sol";
import {FundsFacet} from "src/facets/FundsFacet.sol";
import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {AccessFacet} from "src/facets/AccessFacet.sol";
import {TokenFacet, ERC1155Upgradeable} from "src/facets/TokenFacet.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

library Utils {
    function deployDiamond(address owner, address underlyingAsset, address yieldExtractor, string memory uri)
        internal
        returns (IYelayLiteVault)
    {
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();

        address diamond = address(new YelayLiteVault(owner, address(diamondCutFacet)));

        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](4);
        diamondCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(new TokenFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _tokenFacetSelectors()
        });
        diamondCut[1] = IDiamondCut.FacetCut({
            facetAddress: address(new FundsFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _fundsFacetSelectors()
        });
        diamondCut[2] = IDiamondCut.FacetCut({
            facetAddress: address(new ManagementFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _managementFacetSelectors()
        });
        diamondCut[3] = IDiamondCut.FacetCut({
            facetAddress: address(new AccessFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _accessFacetSelectors()
        });
        DiamondCutFacet(diamond).diamondCut(
            diamondCut,
            address(new YelayLiteVaultInit()),
            abi.encodeWithSelector(YelayLiteVaultInit.init.selector, underlyingAsset, yieldExtractor, uri)
        );
        return IYelayLiteVault(diamond);
    }

    function _tokenFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory functionSelectors = new bytes4[](7);
        functionSelectors[0] = ERC1155Upgradeable.uri.selector;
        functionSelectors[1] = ERC1155Upgradeable.balanceOf.selector;
        functionSelectors[2] = ERC1155Upgradeable.safeTransferFrom.selector;
        functionSelectors[3] = ERC1155Upgradeable.setApprovalForAll.selector;
        functionSelectors[4] = TokenFacet.mint.selector;
        functionSelectors[5] = TokenFacet.burn.selector;
        functionSelectors[6] = TokenFacet.totalSupply.selector;
        return functionSelectors;
    }

    function _fundsFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory functionSelectors = new bytes4[](12);
        functionSelectors[0] = FundsFacet.deposit.selector;
        functionSelectors[1] = FundsFacet.redeem.selector;
        functionSelectors[2] = FundsFacet.totalAssets.selector;
        functionSelectors[3] = FundsFacet.managedDeposit.selector;
        functionSelectors[4] = FundsFacet.managedWithdraw.selector;
        functionSelectors[5] = FundsFacet.reallocate.selector;
        functionSelectors[6] = FundsFacet.strategyAssets.selector;
        functionSelectors[7] = FundsFacet.lastTotalAssets.selector;
        functionSelectors[8] = FundsFacet.underlyingBalance.selector;
        functionSelectors[9] = FundsFacet.underlyingAsset.selector;
        functionSelectors[10] = FundsFacet.yieldExtractor.selector;
        functionSelectors[11] = FundsFacet.accrueFee.selector;
        return functionSelectors;
    }

    function _managementFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory functionSelectors = new bytes4[](7);
        functionSelectors[0] = ManagementFacet.addStrategy.selector;
        functionSelectors[1] = ManagementFacet.removeStrategy.selector;
        functionSelectors[2] = ManagementFacet.updateDepositQueue.selector;
        functionSelectors[3] = ManagementFacet.updateWithdrawQueue.selector;
        functionSelectors[4] = ManagementFacet.getDepositQueue.selector;
        functionSelectors[5] = ManagementFacet.getWithdrawQueue.selector;
        functionSelectors[6] = ManagementFacet.getStrategies.selector;
        return functionSelectors;
    }

    function _accessFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory functionSelectors = new bytes4[](5);
        functionSelectors[0] = AccessFacet.grantRole.selector;
        functionSelectors[1] = AccessFacet.revokeRole.selector;
        functionSelectors[2] = AccessFacet.transferOwnership.selector;
        functionSelectors[3] = AccessFacet.checkRole.selector;
        functionSelectors[4] = AccessFacet.owner.selector;
        return functionSelectors;
    }
}

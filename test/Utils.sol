// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {YelayLiteVaultInit} from "src/YelayLiteVaultInit.sol";
import {Swapper} from "src/Swapper.sol";

import {FundsFacet} from "src/facets/FundsFacet.sol";
import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {AccessFacet} from "src/facets/AccessFacet.sol";
import {ClientsFacet} from "src/facets/ClientsFacet.sol";
import {TokenFacet, ERC1155Upgradeable} from "src/facets/TokenFacet.sol";
import {OwnerFacet} from "src/facets/OwnerFacet.sol";

import {SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";
import {ISwapper, ExchangeArgs} from "src/interfaces/ISwapper.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

library Utils {
    function deployDiamond(address owner, address underlyingAsset, address yieldExtractor, string memory uri)
        internal
        returns (IYelayLiteVault)
    {
        Swapper swapperImpl = new Swapper();
        ISwapper swapper = ISwapper(
            address(new ERC1967Proxy(address(swapperImpl), abi.encodeWithSelector(Swapper.initialize.selector, owner)))
        );

        OwnerFacet ownerFacet = new OwnerFacet();

        IYelayLiteVault yelayLiteVault = IYelayLiteVault(address(new YelayLiteVault(owner, address(ownerFacet))));

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](5);
        selectorsToFacets[0] = SelectorsToFacet({facet: address(new TokenFacet()), selectors: _tokenFacetSelectors()});
        selectorsToFacets[1] = SelectorsToFacet({facet: address(new FundsFacet()), selectors: _fundsFacetSelectors()});
        selectorsToFacets[2] =
            SelectorsToFacet({facet: address(new ManagementFacet()), selectors: _managementFacetSelectors()});
        selectorsToFacets[3] = SelectorsToFacet({facet: address(new AccessFacet()), selectors: _accessFacetSelectors()});
        selectorsToFacets[4] =
            SelectorsToFacet({facet: address(new ClientsFacet()), selectors: _projectsFacetSelectors()});
        yelayLiteVault.setSelectorToFacets(selectorsToFacets);

        yelayLiteVault.createClient(owner, 1, 100, "test");
        for (uint256 i = 1; i < 100; i++) {
            yelayLiteVault.activateProject(i);
        }
        _initialize(yelayLiteVault, swapper, underlyingAsset, yieldExtractor, uri);
        return yelayLiteVault;
    }

    function _initialize(
        IYelayLiteVault yelayLiteVault,
        ISwapper swapper,
        address underlyingAsset,
        address yieldExtractor,
        string memory uri
    ) private {
        bytes[] memory data = new bytes[](3);
        YelayLiteVaultInit yelayLiteVaultInit = new YelayLiteVaultInit();
        {
            SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](5);
            selectorsToFacets[0] = SelectorsToFacet({facet: address(yelayLiteVaultInit), selectors: _initSelectors()});
            data[0] = abi.encodeWithSelector(yelayLiteVault.setSelectorToFacets.selector, selectorsToFacets);
        }
        data[1] = abi.encodeWithSelector(yelayLiteVault.init.selector, swapper, underlyingAsset, yieldExtractor, uri);
        {
            SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](5);
            selectorsToFacets[0] = SelectorsToFacet({facet: address(0), selectors: _initSelectors()});
            data[2] = abi.encodeWithSelector(yelayLiteVault.setSelectorToFacets.selector, selectorsToFacets);
        }
        yelayLiteVault.multicall(data);
    }

    function _tokenFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = ERC1155Upgradeable.uri.selector;
        selectors[1] = ERC1155Upgradeable.balanceOf.selector;
        selectors[2] = ERC1155Upgradeable.safeTransferFrom.selector;
        selectors[3] = ERC1155Upgradeable.setApprovalForAll.selector;
        selectors[4] = TokenFacet.mint.selector;
        selectors[5] = TokenFacet.burn.selector;
        selectors[6] = TokenFacet.totalSupply.selector;
        selectors[7] = TokenFacet.migrate.selector;
        return selectors;
    }

    function _fundsFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](17);
        selectors[0] = FundsFacet.deposit.selector;
        selectors[1] = FundsFacet.redeem.selector;
        selectors[2] = FundsFacet.totalAssets.selector;
        selectors[3] = FundsFacet.managedDeposit.selector;
        selectors[4] = FundsFacet.managedWithdraw.selector;
        selectors[5] = FundsFacet.reallocate.selector;
        selectors[6] = FundsFacet.strategyAssets.selector;
        selectors[7] = FundsFacet.lastTotalAssets.selector;
        selectors[8] = FundsFacet.underlyingBalance.selector;
        selectors[9] = FundsFacet.underlyingAsset.selector;
        selectors[10] = FundsFacet.yieldExtractor.selector;
        selectors[11] = FundsFacet.accrueFee.selector;
        selectors[12] = FundsFacet.strategyRewards.selector;
        selectors[13] = FundsFacet.claimStrategyRewards.selector;
        selectors[14] = FundsFacet.swapper.selector;
        selectors[15] = FundsFacet.compound.selector;
        selectors[16] = FundsFacet.migratePosition.selector;
        return selectors;
    }

    function _managementFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = ManagementFacet.addStrategy.selector;
        selectors[1] = ManagementFacet.removeStrategy.selector;
        selectors[2] = ManagementFacet.updateDepositQueue.selector;
        selectors[3] = ManagementFacet.updateWithdrawQueue.selector;
        selectors[4] = ManagementFacet.getDepositQueue.selector;
        selectors[5] = ManagementFacet.getWithdrawQueue.selector;
        selectors[6] = ManagementFacet.getStrategies.selector;
        return selectors;
    }

    function _accessFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = AccessFacet.grantRole.selector;
        selectors[1] = AccessFacet.revokeRole.selector;
        selectors[2] = AccessFacet.checkRole.selector;
        return selectors;
    }

    function _projectsFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = ClientsFacet.createClient.selector;
        selectors[1] = ClientsFacet.transferClientOwnership.selector;
        selectors[2] = ClientsFacet.activateProject.selector;
        selectors[3] = ClientsFacet.setProjectInterceptor.selector;
        selectors[4] = ClientsFacet.setLockConfig.selector;
        selectors[5] = ClientsFacet.depositHook.selector;
        selectors[6] = ClientsFacet.redeemHook.selector;
        return selectors;
    }

    function _initSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = YelayLiteVaultInit.init.selector;
        return selectors;
    }

    function addExchange(IYelayLiteVault yelayLiteVault, address exchange) internal {
        ISwapper swapper = ISwapper(yelayLiteVault.swapper());
        ExchangeArgs[] memory exchangeArgs = new ExchangeArgs[](1);
        exchangeArgs[0] = ExchangeArgs({exchange: exchange, allowed: true});
        swapper.updateExchangeAllowlist(exchangeArgs);
    }
}

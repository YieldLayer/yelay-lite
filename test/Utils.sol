// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1155Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {
    IAccessControlEnumerable,
    IAccessControl
} from "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {Swapper} from "src/Swapper.sol";

import {FundsFacet} from "src/facets/FundsFacet.sol";
import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {AccessFacet} from "src/facets/AccessFacet.sol";
import {ClientsFacet} from "src/facets/ClientsFacet.sol";
import {OwnerFacet} from "src/facets/OwnerFacet.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";

import {SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";
import {ISwapper, ExchangeArgs} from "src/interfaces/ISwapper.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {IMerklDistributor} from "src/interfaces/external/merkl/IMerklDistributor.sol";

library Utils {
    function deployDiamond(address owner, address underlyingAsset, address yieldExtractor, string memory uri)
        internal
        returns (IYelayLiteVault)
    {
        return deployDiamond(owner, underlyingAsset, yieldExtractor, uri, address(0));
    }

    function deployDiamond(
        address owner,
        address underlyingAsset,
        address yieldExtractor,
        string memory uri,
        address merklDistributor
    ) internal returns (IYelayLiteVault) {
        Swapper swapperImpl = new Swapper();
        ISwapper swapper = ISwapper(
            address(new ERC1967Proxy(address(swapperImpl), abi.encodeWithSelector(Swapper.initialize.selector, owner)))
        );

        OwnerFacet ownerFacet = new OwnerFacet();

        YelayLiteVault vault = new YelayLiteVault();
        vault.initialize(
            owner, address(ownerFacet), underlyingAsset, yieldExtractor, uri, new address[](0), new bytes[](0)
        );
        IYelayLiteVault yelayLiteVault = IYelayLiteVault(address(vault));

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](4);
        selectorsToFacets[0] = SelectorsToFacet({
            facet: address(new FundsFacet(swapper, IMerklDistributor(merklDistributor))),
            selectors: fundsFacetSelectors()
        });
        selectorsToFacets[1] =
            SelectorsToFacet({facet: address(new ManagementFacet()), selectors: managementFacetSelectors()});
        selectorsToFacets[2] = SelectorsToFacet({facet: address(new AccessFacet()), selectors: _accessFacetSelectors()});
        selectorsToFacets[3] =
            SelectorsToFacet({facet: address(new ClientsFacet()), selectors: clientsFacetSelectors()});
        yelayLiteVault.addSelectors(selectorsToFacets);

        yelayLiteVault.grantRole(LibRoles.CLIENT_MANAGER, owner);
        yelayLiteVault.createClient(owner, 999, "test");
        for (uint256 i = 1; i < 50; i++) {
            yelayLiteVault.activateProject(i);
        }
        return yelayLiteVault;
    }

    function fundsFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](30);
        selectors[0] = bytes4(keccak256("totalSupply()"));
        selectors[1] = bytes4(keccak256("totalSupply(uint256)"));
        selectors[2] = FundsFacet.lastTotalAssets.selector;
        selectors[3] = FundsFacet.underlyingBalance.selector;
        selectors[4] = FundsFacet.underlyingAsset.selector;
        selectors[5] = FundsFacet.yieldExtractor.selector;
        selectors[6] = FundsFacet.setYieldExtractor.selector;
        selectors[7] = FundsFacet.swapper.selector;
        selectors[8] = FundsFacet.merklDistributor.selector;
        selectors[9] = FundsFacet.totalAssets.selector;
        selectors[10] = FundsFacet.strategyAssets.selector;
        selectors[11] = FundsFacet.strategyRewards.selector;
        selectors[12] = FundsFacet.deposit.selector;
        selectors[13] = FundsFacet.redeem.selector;
        selectors[14] = FundsFacet.migratePosition.selector;
        selectors[15] = FundsFacet.managedDeposit.selector;
        selectors[16] = FundsFacet.managedWithdraw.selector;
        selectors[17] = FundsFacet.reallocate.selector;
        selectors[18] = FundsFacet.swapRewards.selector;
        selectors[19] = FundsFacet.compoundUnderlyingReward.selector;
        selectors[20] = FundsFacet.accrueFee.selector;
        selectors[21] = FundsFacet.claimStrategyRewards.selector;
        selectors[22] = FundsFacet.claimMerklRewards.selector;
        selectors[23] = ERC1155Upgradeable.balanceOf.selector;
        selectors[24] = ERC1155Upgradeable.uri.selector;
        selectors[25] = FundsFacet.transformYieldShares.selector;
        selectors[26] = FundsFacet.convertToShares.selector;
        selectors[27] = FundsFacet.convertToAssets.selector;
        selectors[28] = FundsFacet.previewRedeem.selector;
        selectors[29] = FundsFacet.previewWithdraw.selector;
        return selectors;
    }

    function managementFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = ManagementFacet.addStrategy.selector;
        selectors[1] = ManagementFacet.removeStrategy.selector;
        selectors[2] = ManagementFacet.updateDepositQueue.selector;
        selectors[3] = ManagementFacet.updateWithdrawQueue.selector;
        selectors[4] = ManagementFacet.getDepositQueue.selector;
        selectors[5] = ManagementFacet.getWithdrawQueue.selector;
        selectors[6] = ManagementFacet.getStrategies.selector;
        selectors[7] = ManagementFacet.approveStrategy.selector;
        selectors[8] = ManagementFacet.activateStrategy.selector;
        selectors[9] = ManagementFacet.deactivateStrategy.selector;
        selectors[10] = ManagementFacet.getActiveStrategies.selector;
        return selectors;
    }

    function _accessFacetSelectors() private pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = AccessFacet.grantRole.selector;
        selectors[1] = AccessFacet.revokeRole.selector;
        selectors[2] = AccessFacet.checkRole.selector;
        selectors[3] = IAccessControlEnumerable.getRoleMember.selector;
        selectors[4] = IAccessControlEnumerable.getRoleMemberCount.selector;
        selectors[5] = IAccessControl.hasRole.selector;
        selectors[6] = AccessFacet.setPaused.selector;
        selectors[7] = AccessFacet.selectorToPaused.selector;
        return selectors;
    }

    function clientsFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = ClientsFacet.createClient.selector;
        selectors[1] = ClientsFacet.transferClientOwnership.selector;
        selectors[2] = ClientsFacet.activateProject.selector;
        selectors[3] = ClientsFacet.lastProjectId.selector;
        selectors[4] = ClientsFacet.isClientNameTaken.selector;
        selectors[5] = ClientsFacet.ownerToClientData.selector;
        selectors[6] = ClientsFacet.projectIdToClientName.selector;
        selectors[7] = ClientsFacet.projectIdActive.selector;
        selectors[8] = ClientsFacet.activateProjectByManager.selector;
        return selectors;
    }

    function addExchange(IYelayLiteVault yelayLiteVault, address exchange) internal {
        ISwapper swapper = ISwapper(yelayLiteVault.swapper());
        ExchangeArgs[] memory exchangeArgs = new ExchangeArgs[](1);
        exchangeArgs[0] = ExchangeArgs({exchange: exchange, allowed: true});
        swapper.updateExchangeAllowlist(exchangeArgs);
    }
}

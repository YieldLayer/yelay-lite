// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {MigrateToYieldExtractor} from "src/migration-helpers/MigrateToYieldExtractor.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";

import {SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

import {Test, console} from "forge-std/Test.sol";

abstract contract AbstractYieldExtractorMigration is Test {
    address owner = 0x9909eE4947Be39C208607D8d2473d68C05CeF8F9;

    MigrateToYieldExtractor migrator;
    YieldExtractor yieldExtractor;
    address testingDeployerAddress;

    IYelayLiteVault[] vaults;

    function _setupFork() internal virtual {}

    function setUp() external {
        _setupFork();

        migrator = new MigrateToYieldExtractor();
        YieldExtractor impl = new YieldExtractor();
        yieldExtractor = YieldExtractor(
            address(
                new ERC1967Proxy(
                    address(impl),
                    abi.encodeWithSelector(
                        YieldExtractor.initialize.selector, owner, owner, new YieldExtractor.ClaimedRequest[](0)
                    )
                )
            )
        );
    }

    function test_migration() external {
        vm.startPrank(owner);

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MigrateToYieldExtractor.transferYieldSharesToYieldExtractor.selector;

        for (uint256 i; i < vaults.length; i++) {
            selectorsToFacets[0] = SelectorsToFacet({facet: address(migrator), selectors: selectors});
            address oldYieldExtractor = vaults[i].yieldExtractor();

            uint256 yieldBalance = vaults[i].balanceOf(oldYieldExtractor, 0);
            uint256 yieldBalanceTestingDeployer = vaults[i].balanceOf(testingDeployerAddress, 0);
            assertEq(vaults[i].balanceOf(address(yieldExtractor), 0), 0);
            assertGt(yieldBalance, 0);

            // DO MIGRATION
            vaults[i].setSelectorToFacets(selectorsToFacets);
            MigrateToYieldExtractor(address(vaults[i])).transferYieldSharesToYieldExtractor(
                address(yieldExtractor), testingDeployerAddress
            );
            selectorsToFacets[0] = SelectorsToFacet({facet: address(0), selectors: selectors});
            vaults[i].setSelectorToFacets(selectorsToFacets);

            assertEq(vaults[i].balanceOf(address(yieldExtractor), 0), yieldBalance + yieldBalanceTestingDeployer);
            assertEq(vaults[i].balanceOf(oldYieldExtractor, 0), 0);
            assertEq(
                vaults[i].selectorToFacet(MigrateToYieldExtractor.transferYieldSharesToYieldExtractor.selector),
                address(0)
            );
        }
        vm.stopPrank();
    }
}

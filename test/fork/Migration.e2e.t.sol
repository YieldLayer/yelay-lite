// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {Utils} from "../Utils.sol";
import {AAVE_V3_POOL, USDC_ADDRESS} from "../Constants.sol";

import {IPool} from "@aave-v3-core/interfaces/IPool.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {StrategyData} from "src/interfaces/IManagementFacet.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {AaveV3Strategy} from "src/strategies/AaveV3Strategy.sol";
import {ManagementFacet} from "src/facets/ManagementFacet.sol";
import {FundsFacet} from "src/facets/FundsFacet.sol";
import {ClientsFacet} from "src/facets/ClientsFacet.sol";
import {SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {StrategyArgs} from "src/interfaces/IFundsFacet.sol";
import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";
import {IMerklDistributor} from "src/interfaces/external/merkl/IMerklDistributor.sol";

contract Migration is Test {
    using Utils for address;

    uint256 constant FORK_BLOCK_NUMBER = 22260000;
    address constant owner = address(0x9909eE4947Be39C208607D8d2473d68C05CeF8F9);
    address constant fundsOperator = address(0x76dBc2c72E5c8eF6816Af0F904621d091857fF80);
    IYelayLiteVault constant yelayLiteVault = IYelayLiteVault(0x39DAc87bE293DC855b60feDd89667364865378cc);
    ISwapper constant swapper = ISwapper(0xD49Dc240CE448BE0513803AB82B85F8484748871);
    IMerklDistributor constant merklDistributor = IMerklDistributor(0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_URL"), FORK_BLOCK_NUMBER);
        vm.deal(owner, 1 ether);
    }

    function test_update_strategies_adapters() external {
        vm.startPrank(owner);
        //1# Provider roles to owner QUEUES_OPERATOR, FUNDS_OPERATOR
        yelayLiteVault.grantRole(LibRoles.QUEUES_OPERATOR, owner);
        yelayLiteVault.grantRole(LibRoles.FUNDS_OPERATOR, owner);

        // 2. Set selectors for facets (Management, Funds, Clients)
        //No need to remove old facets, all are being replaced, there were no changes to function signatures
        SelectorsToFacet[] memory facets = new SelectorsToFacet[](3);
        facets[0] = SelectorsToFacet({
            facet: address(new FundsFacet(swapper, merklDistributor)),
            selectors: Utils.fundsFacetSelectors()
        });
        facets[1] =
            SelectorsToFacet({facet: address(new ManagementFacet()), selectors: Utils.managementFacetSelectors()});
        facets[2] = SelectorsToFacet({facet: address(new ClientsFacet()), selectors: Utils.clientsFacetSelectors()});
        yelayLiteVault.setSelectorToFacets(facets);

        // 3. Accrue fee
        yelayLiteVault.accrueFee();

        // 4. Withdraw all
        StrategyData[] memory activeStrategies = yelayLiteVault.getActiveStrategies();
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            yelayLiteVault.managedWithdraw(StrategyArgs({index: i, amount: type(uint256).max}));
        }

        // 5. Deactivate strategies
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            yelayLiteVault.deactivateStrategy(0, new uint256[](0), new uint256[](0));
        }

        // 6. Remove strategies
        StrategyData[] memory strategies = yelayLiteVault.getStrategies();
        for (uint256 i = 0; i < strategies.length; i++) {
            yelayLiteVault.removeStrategy(0);
        }
        assertEq(yelayLiteVault.getStrategies().length, 0);

        // 7. Add strategies
        ERC4626Strategy erc4626 = new ERC4626Strategy();
        yelayLiteVault.addStrategy(
            StrategyData({
                adapter: address(new AaveV3Strategy(AAVE_V3_POOL)),
                supplement: abi.encode(
                    address(USDC_ADDRESS), IPool(AAVE_V3_POOL).getReserveData(address(USDC_ADDRESS)).aTokenAddress
                ),
                name: "aave-v3"
            })
        );
        yelayLiteVault.addStrategy(
            StrategyData({
                adapter: address(erc4626),
                supplement: abi.encode(address(0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458)),
                name: "gauntlet-usdc-core"
            })
        );
        yelayLiteVault.addStrategy(
            StrategyData({
                adapter: address(erc4626),
                supplement: abi.encode(address(0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB)),
                name: "steakhouse-usdc"
            })
        );

        // 8. Activate strategy
        uint256[] memory depositQueue = new uint256[](1);
        uint256[] memory withdrawQueue = new uint256[](1);
        depositQueue[0] = 0;
        withdrawQueue[0] = 0;
        yelayLiteVault.activateStrategy(2, depositQueue, withdrawQueue);
        assertEq(yelayLiteVault.getActiveStrategies()[0].name, "steakhouse-usdc");

        // 9. Deposit
        assertGt(yelayLiteVault.underlyingBalance(), 0);
        yelayLiteVault.managedDeposit(StrategyArgs({index: 0, amount: yelayLiteVault.underlyingBalance()}));
        assertEq(yelayLiteVault.underlyingBalance(), 0);

        vm.stopPrank();
    }
}

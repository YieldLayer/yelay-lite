// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DiamondCutFacet, IDiamondCut} from "@diamond/facets/DiamondCutFacet.sol";

import {YelayLiteVault} from "src/YelayLiteVault.sol";
import {Atomic, ERC20Upgradeable} from "src/facets/Atomic.sol";

contract AtomicTest is Test {
    address owner = address(0x01);

    address yelayLiteVault;
    DiamondCutFacet diamondCutFacet;
    Atomic atomic;

    function setUp() external {
        vm.startPrank(owner);
        diamondCutFacet = new DiamondCutFacet();
        yelayLiteVault = address(new YelayLiteVault(owner, address(diamondCutFacet)));
        atomic = new Atomic();
        vm.stopPrank();
    }

    function test_cutDiamond_atomic() external {
        string memory name = "Yelay Lite USDC";
        string memory symbol = "Yelay Lite USDC";

        vm.startPrank(owner);
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = Atomic.atomicInitialize.selector;
        functionSelectors[1] = ERC20Upgradeable.name.selector;
        functionSelectors[2] = ERC20Upgradeable.symbol.selector;
        diamondCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(atomic),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        DiamondCutFacet(yelayLiteVault).diamondCut(
            diamondCut, yelayLiteVault, abi.encodeWithSelector(Atomic.atomicInitialize.selector, name, symbol)
        );

        assertEq(Atomic(yelayLiteVault).name(), name);
        assertEq(Atomic(yelayLiteVault).symbol(), symbol);
    }
}

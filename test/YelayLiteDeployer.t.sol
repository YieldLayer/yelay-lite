// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

import {YelayLiteDeployer} from "src/YelayLiteDeployer.sol";
import {AccessFacet} from "src/facets/AccessFacet.sol";
import {FundsFacet} from "src/facets/FundsFacet.sol";
import {OwnerFacet} from "src/facets/OwnerFacet.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {IOwnerFacet, SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {IMerklDistributor} from "src/interfaces/external/merkl/IMerklDistributor.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";

import {MockToken} from "./MockToken.sol";
import {Swapper} from "src/Swapper.sol";

contract YelayLiteDeployerTest is Test {
    YelayLiteDeployer private deployer;

    address private deployerOwner = makeAddr("deployerOwner");
    address private unauthorized = makeAddr("unauthorized");
    address private yieldExtractor = makeAddr("yieldExtractor");
    string private constant uri = "https://yelay-lite-vault/{id}.json";

    function setUp() external {
        deployer = new YelayLiteDeployer(deployerOwner);
    }

    function testDeployInitializesVaultAndEmitsEvent() external {
        address ownerFacetAddr = address(new OwnerFacet());
        address accessFacetAddr = address(new AccessFacet());
        ISwapper swapper = ISwapper(
            address(
                new ERC1967Proxy(
                    address(new Swapper()), abi.encodeWithSelector(Swapper.initialize.selector, deployerOwner)
                )
            )
        );
        address fundsFacetAddr = address(new FundsFacet(swapper, IMerklDistributor(address(0))));
        address underlying = address(new MockToken("Mock Token", "MCK", 18));

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](2);
        bytes4[] memory fundsSelectors = new bytes4[](3);
        fundsSelectors[0] = FundsFacet.underlyingAsset.selector;
        fundsSelectors[1] = FundsFacet.yieldExtractor.selector;
        fundsSelectors[2] = ERC1155Upgradeable.uri.selector;
        selectorsToFacets[0] = SelectorsToFacet({facet: fundsFacetAddr, selectors: fundsSelectors});

        bytes4[] memory accessSelectors = new bytes4[](4);
        accessSelectors[0] = AccessFacet.grantRole.selector;
        accessSelectors[1] = AccessFacet.revokeRole.selector;
        accessSelectors[2] = AccessFacet.checkRole.selector;
        accessSelectors[3] = IAccessControl.hasRole.selector;
        selectorsToFacets[1] = SelectorsToFacet({facet: accessFacetAddr, selectors: accessSelectors});

        address[] memory facets = new address[](4);
        bytes[] memory payloads = new bytes[](4);
        facets[0] = ownerFacetAddr;
        payloads[0] = abi.encodeWithSelector(OwnerFacet.addSelectors.selector, selectorsToFacets);
        facets[1] = accessFacetAddr;
        payloads[1] = abi.encodeWithSelector(AccessFacet.grantRole.selector, LibRoles.CLIENT_MANAGER, deployerOwner);
        facets[2] = accessFacetAddr;
        payloads[2] = abi.encodeWithSelector(AccessFacet.grantRole.selector, LibRoles.FUNDS_OPERATOR, yieldExtractor);
        facets[3] = accessFacetAddr;
        payloads[3] = abi.encodeWithSelector(AccessFacet.grantRole.selector, LibRoles.STRATEGY_AUTHORITY, deployerOwner);

        address expectedVault = deployer.computeAddress(keccak256("salt"));
        vm.expectEmit(false, false, false, true);
        emit LibEvents.YelayLiteVaultDeployed(expectedVault);

        vm.prank(deployerOwner);
        address vaultAddress =
            deployer.deploy(keccak256("salt"), ownerFacetAddr, underlying, yieldExtractor, uri, facets, payloads);

        assertEq(vaultAddress, expectedVault);

        IYelayLiteVault vault = IYelayLiteVault(vaultAddress);
        assertEq(vault.owner(), deployerOwner);
        assertEq(vault.underlyingAsset(), underlying);
        assertEq(vault.yieldExtractor(), yieldExtractor);
        assertEq(vault.uri(0), uri);
        assertEq(vault.selectorToFacet(IOwnerFacet.owner.selector), ownerFacetAddr);
        assertEq(vault.selectorToFacet(FundsFacet.underlyingAsset.selector), fundsFacetAddr);
        assertEq(vault.selectorToFacet(AccessFacet.grantRole.selector), accessFacetAddr);
        assertTrue(vault.hasRole(LibRoles.CLIENT_MANAGER, deployerOwner));
        assertTrue(vault.hasRole(LibRoles.FUNDS_OPERATOR, yieldExtractor));
        assertTrue(vault.hasRole(LibRoles.STRATEGY_AUTHORITY, deployerOwner));
    }

    function testDeployRevertsForNonOwner() external {
        OwnerFacet ownerFacet = new OwnerFacet();
        MockToken underlying = new MockToken("Mock Token", "MCK", 18);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, unauthorized));
        vm.prank(unauthorized);
        deployer.deploy(
            keccak256("salt"),
            address(ownerFacet),
            address(underlying),
            yieldExtractor,
            uri,
            new address[](0),
            new bytes[](0)
        );
    }

    function testDeployRevertsWhenInitDataMalformed() external {
        OwnerFacet ownerFacet = new OwnerFacet();
        MockToken underlying = new MockToken("Mock Token", "MCK", 18);

        address[] memory facets = new address[](1);
        facets[0] = address(ownerFacet);
        bytes[] memory payloads = new bytes[](0);

        vm.expectRevert(LibErrors.MalformedInitData.selector);
        vm.prank(deployerOwner);
        deployer.deploy(
            keccak256("salt"), address(ownerFacet), address(underlying), yieldExtractor, uri, facets, payloads
        );
    }
}

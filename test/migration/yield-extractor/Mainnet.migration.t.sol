// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AbstractYieldExtractorMigration} from "./AbstractYieldExtractorMigration.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";
import {SelectorsToFacet} from "src/interfaces/IOwnerFacet.sol";
import {MigrateToYieldExtractor} from "src/migration-helpers/MigrateToYieldExtractor.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

contract MainnetYieldExtractorMigrationTest is AbstractYieldExtractorMigration {
    IYelayLiteVault usdcVault;
    IYelayLiteVault wethVault;
    IYelayLiteVault wbtcVault;

    function _setupFork() internal override {
        vm.createSelectFork(vm.envString("MAINNET_URL"), 22331639);

        usdcVault = IYelayLiteVault(0x39DAc87bE293DC855b60feDd89667364865378cc);
        wethVault = IYelayLiteVault(0x4d95E929ABb21b6C6C0FF1ff0Ac69609e02BB368);
        wbtcVault = IYelayLiteVault(0x6545e81356CE709823EA8797E566A60934A9B110);
        vaults.push(usdcVault);
        vaults.push(wethVault);
        vaults.push(wbtcVault);

        vm.startPrank(owner);
        _setupUSDCClaimedLeafs();
        _setupWETHClaimedLeafs();
        _setupWBTCClaimedLeafs();
        vm.stopPrank();
    }

    function _setupUSDCClaimedLeafs() internal {
        YieldExtractor.Root memory root = YieldExtractor.Root({
            hash: 0x3058cbbee83f0bcac360becdda11ce12d978674af681d5157a12cd53a288a3be,
            blockNumber: 22437501
        });
        YieldExtractor.Root[] memory roots = new YieldExtractor.Root[](1);
        roots[0] = root;

        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = 0x16d02b6b44cc236889d746b3c024a85833a9fe94144a5d67230437a2d3602243;
        YieldExtractor.ClaimRequest memory claimRequest1 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(usdcVault),
            projectId: 10121,
            cycle: 1,
            yieldSharesTotal: 362182437,
            proof: proof1
        });

        bytes32[] memory proof2 = new bytes32[](2);
        proof2[0] = 0x7d41bd27e94822d8831231fa27f031f837aa56238e7f982770b624dd4412d8df;
        proof2[1] = 0xccffe22689bf496b69cea71ba860a8247d6205a9fb8ecead1513546afafd1990;
        YieldExtractor.ClaimRequest memory claimRequest2 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(usdcVault),
            projectId: 10122,
            cycle: 1,
            yieldSharesTotal: 3394081028,
            proof: proof2
        });

        YieldExtractor.ClaimedRequest[] memory claimedRequests = new YieldExtractor.ClaimedRequest[](2);
        claimedRequests[0] = YieldExtractor.ClaimedRequest({
            user: 0x98411E6D808208D3c349D766194492B376af7e49,
            claimRequest: claimRequest1
        });
        claimedRequests[1] = YieldExtractor.ClaimedRequest({
            user: 0x98411E6D808208D3c349D766194492B376af7e49,
            claimRequest: claimRequest2
        });

        yieldExtractor.initializeClaimedLeafs(roots, address(usdcVault), claimedRequests);
    }

    function _setupWETHClaimedLeafs() internal {
        YieldExtractor.Root memory root = YieldExtractor.Root({
            hash: 0x16b01767d0c1f0517d0f469ad9be5f436c4f22391e72f60dd22ff0a03e6a90b3,
            blockNumber: 22437505
        });
        YieldExtractor.Root[] memory roots = new YieldExtractor.Root[](1);
        roots[0] = root;

        bytes32[] memory proof1 = new bytes32[](2);
        proof1[0] = 0x6acda6be738ea423b160cc9ded3e735a0e599bbb0d745eb17382e22dd359de72;
        proof1[1] = 0x9ab06feb9577fe4cd6e3b0601e6b8fc34918d8190a30875519adb107f2421806;
        YieldExtractor.ClaimRequest memory claimRequest1 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(wethVault),
            projectId: 10121,
            cycle: 1,
            yieldSharesTotal: 95394077318189597,
            proof: proof1
        });

        bytes32[] memory proof2 = new bytes32[](2);
        proof2[0] = 0x7fac2549c09f7d996d6c297127f6267ccc91f98bdfb1ce89c34d57ba7fec74f2;
        proof2[1] = 0x9ab06feb9577fe4cd6e3b0601e6b8fc34918d8190a30875519adb107f2421806;
        YieldExtractor.ClaimRequest memory claimRequest2 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(wethVault),
            projectId: 10122,
            cycle: 1,
            yieldSharesTotal: 1604149652504918361,
            proof: proof2
        });

        YieldExtractor.ClaimedRequest[] memory claimedRequests = new YieldExtractor.ClaimedRequest[](2);
        claimedRequests[0] = YieldExtractor.ClaimedRequest({
            user: 0x98411E6D808208D3c349D766194492B376af7e49,
            claimRequest: claimRequest1
        });
        claimedRequests[1] = YieldExtractor.ClaimedRequest({
            user: 0x98411E6D808208D3c349D766194492B376af7e49,
            claimRequest: claimRequest2
        });

        yieldExtractor.initializeClaimedLeafs(roots, address(wethVault), claimedRequests);
    }

    function _setupWBTCClaimedLeafs() internal {
        YieldExtractor.Root memory root = YieldExtractor.Root({
            hash: 0xc26eeaaec0efe6a59da9284a98f7732af56d69e0ff2e2ad90bbd1605dffb2a69,
            blockNumber: 22437509
        });
        YieldExtractor.Root[] memory roots = new YieldExtractor.Root[](1);
        roots[0] = root;

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = 0x13e5b4591d96ba718c06f27fe9c0bc4d1e2ed2f264b2e748cc0c2cbcec9eda11;
        YieldExtractor.ClaimRequest memory claimRequest = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(wbtcVault),
            projectId: 10122,
            cycle: 1,
            yieldSharesTotal: 43909,
            proof: proof
        });

        YieldExtractor.ClaimedRequest[] memory claimedRequests = new YieldExtractor.ClaimedRequest[](1);
        claimedRequests[0] = YieldExtractor.ClaimedRequest({
            user: 0x98411E6D808208D3c349D766194492B376af7e49,
            claimRequest: claimRequest
        });

        yieldExtractor.initializeClaimedLeafs(roots, address(wbtcVault), claimedRequests);
    }

    function _migrate() internal {
        vm.startPrank(owner);

        SelectorsToFacet[] memory selectorsToFacets = new SelectorsToFacet[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MigrateToYieldExtractor.transferYieldSharesToYieldExtractor.selector;

        for (uint256 i; i < vaults.length; i++) {
            selectorsToFacets[0] = SelectorsToFacet({facet: address(migrator), selectors: selectors});
            vaults[i].setSelectorToFacets(selectorsToFacets);
            MigrateToYieldExtractor(address(vaults[i])).transferYieldSharesToYieldExtractor(
                address(yieldExtractor), testingDeployerAddress
            );
            selectorsToFacets[0] = SelectorsToFacet({facet: address(0), selectors: selectors});
            vaults[i].setSelectorToFacets(selectorsToFacets);
        }
        vm.stopPrank();
    }

    function test_claim_revertAlreadyClaimed() public {
        vm.prank(0x98411E6D808208D3c349D766194492B376af7e49);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = 0x13e5b4591d96ba718c06f27fe9c0bc4d1e2ed2f264b2e748cc0c2cbcec9eda11;
        YieldExtractor.ClaimRequest[] memory claimRequests = new YieldExtractor.ClaimRequest[](1);
        YieldExtractor.ClaimRequest memory claimRequest = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(wbtcVault),
            projectId: 10122,
            cycle: 1,
            yieldSharesTotal: 43909,
            proof: proof
        });
        claimRequests[0] = claimRequest;

        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProofAlreadyClaimed.selector, 0));
        yieldExtractor.claim(claimRequests);
        vm.stopPrank();
    }

    function test_claim_success() public {
        this._migrate();
        vm.prank(0xf8081dc0f15E6B6508139237a7E9Ed2480Dc7cdc);
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = 0x90355c6ad28600bcd5b3d9f79cd25c89305373580af344b676e649066c5277ea;
        YieldExtractor.ClaimRequest[] memory claimRequests = new YieldExtractor.ClaimRequest[](1);
        YieldExtractor.ClaimRequest memory claimRequest = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(wbtcVault),
            projectId: 1,
            cycle: 1,
            yieldSharesTotal: 27,
            proof: proof
        });
        claimRequests[0] = claimRequest;

        yieldExtractor.claim(claimRequests);
        vm.stopPrank();
    }

    function test_initializeClaimedLeafs_unauhorized() public {
        this._migrate();
        vm.startPrank(0x98411E6D808208D3c349D766194492B376af7e49);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(0x98411E6D808208D3c349D766194492B376af7e49),
                0x00
            )
        );
        yieldExtractor.initializeClaimedLeafs(
            new YieldExtractor.Root[](0), address(usdcVault), new YieldExtractor.ClaimedRequest[](0)
        );
        vm.stopPrank();
    }
}

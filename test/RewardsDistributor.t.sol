// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {RewardsDistributor} from "src/plugins/RewardsDistributor.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

/**
 * Tree data generated using openzeppelin/merkle-tree:
 *
 * import { StandardMerkleTree } from "openzeppelin/merkle-tree";
 *
 * // (1)
 * // user, cycle, vault, projectId, rewards
 * // cycle 1
 * const values1 = [
 *   ["0x1111111111111111111111111111111111111111", "1", "0xc7183455a4C133Ae270771860664b6B7ec320bB1", "1", "5000000000000000000"],
 *   ["0x2222222222222222222222222222222222222222", "1", "0xc7183455a4C133Ae270771860664b6B7ec320bB1", "1", "5000000000000000000"],
 * ];
 * // cycle 2
 * const values2 = [
 *   ["0x1111111111111111111111111111111111111111", "2", "0xc7183455a4C133Ae270771860664b6B7ec320bB1", "1", "5010000000000000000"],
 *   ["0x2222222222222222222222222222222222222222", "2", "0xc7183455a4C133Ae270771860664b6B7ec320bB1", "1", "5010000000000000000"],
 * ];
 *
 * let tree;
 * tree = StandardMerkleTree.of(values1, ["address", "uint256", "address", "uint256", "uint256"]);
 * console.log('Merkle Root (1):', tree.root);
 * console.log('Tree (1):', tree.dump());
 *
 * // (2)
 * tree = StandardMerkleTree.of(values2, ["address", "uint256", "address", "uint256", "uint256"]);
 * console.log('Merkle Root (2):', tree.root);
 * console.log('Tree(2):', tree.dump());
 */
contract RewardsDistributorTest is Test {
    event PoolRootAdded(uint256 indexed cycle, bytes32 root);
    event PoolRootUpdated(uint256 indexed cycle, bytes32 previousRoot, bytes32 newRoot);

    RewardsDistributor public rewardDistributor;
    IYelayLiteVault public mockVault;
    MockToken token;
    uint256 public projectId = 1;

    bytes32 constant treeRoot0 = 0x55ff69a9de890de6129f2d7964fbe15bc92eef5bfd82354c8c0543dd5e404887;
    bytes32 constant treeRoot1 = 0xd37cd0a4822f2d57834126e2ee0771aaee758d0e5e01da5a261badc9090b8005;

    bytes32 constant proof0 = 0x59c902ab746b3c70d11a56a13eb919ba8b5314cf92340820ada5cc0cce66fbdc;
    bytes32 constant proof1 = 0x640c6290894a69bd7a2722484cb9f49652069564ba46624abf311dbfa37e22e0;
    bytes32 constant proof_fail = bytes32(uint256(proof0) - 1);

    uint256 constant rewardsTotal0 = 5000000000000000000;
    uint256 constant rewardsTotal1 = 5010000000000000000;
    uint256 constant rewardsTotal_fail = rewardsTotal0 + 1;

    address alice = 0x1111111111111111111111111111111111111111;

    function setUp() public {
        uint256 toDeposit = 1000e18;

        // Deploy a mock underlying ERC20 and fund the user.
        token = new MockToken("Underlying", "UND", 18);
        deal(address(token), alice, toDeposit);

        mockVault = Utils.deployDiamond(address(this), address(token), address(this), "");
        assertEq(address(mockVault), 0xc7183455a4C133Ae270771860664b6B7ec320bB1);

        RewardsDistributor impl = new RewardsDistributor();
        rewardDistributor = RewardsDistributor(
            address(
                new ERC1967Proxy(
                    address(impl),
                    abi.encodeWithSelector(RewardsDistributor.initialize.selector, address(this), address(this))
                )
            )
        );

        // deposit into the vault, send shares to reward distributor
        vm.startPrank(alice);
        token.approve(address(mockVault), toDeposit);
        IFundsFacet(mockVault).deposit(toDeposit, projectId, address(rewardDistributor));
        vm.stopPrank();
    }

    function test_addRoot_success() public {
        uint256 cycleBefore = rewardDistributor.cycleCount();

        vm.expectEmit(true, true, true, true);
        emit PoolRootAdded(cycleBefore + 1, treeRoot0);

        rewardDistributor.addTreeRoot(treeRoot0);

        uint256 cycle = rewardDistributor.cycleCount();

        assertEq(cycle, cycleBefore + 1);
        assertEq(rewardDistributor.roots(cycle), treeRoot0);
    }

    function test_updateRoot_success() public {
        rewardDistributor.addTreeRoot(treeRoot0);

        uint256 cycle = rewardDistributor.cycleCount();

        vm.expectEmit(true, true, true, true);
        emit PoolRootUpdated(cycle, treeRoot0, treeRoot1);
        rewardDistributor.updateTreeRoot(treeRoot1, 1);

        assertEq(rewardDistributor.roots(1), treeRoot1);
    }

    function test_updateRoot_revertInvalidCycle() public {
        rewardDistributor.addTreeRoot(treeRoot0);
        vm.expectRevert(abi.encodeWithSelector(RewardsDistributor.InvalidCycle.selector));
        rewardDistributor.updateTreeRoot(treeRoot0, 10);
    }

    function test_verifyProof_success() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);
        assertTrue(rewardDistributor.verify(data, alice));
    }

    function test_verifyProof_invalidProof() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof_fail;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);
        assertFalse(rewardDistributor.verify(data, alice));
    }

    function test_verifyProof_invalidYelayLiteVault() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        // Replace with an invalid vault address
        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: 0x0000000000000000000000000000000000000001,
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);
        assertFalse(rewardDistributor.verify(data, alice));
    }

    function test_verifyProof_invalidUser() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);
        // Using a different user than alice
        assertFalse(rewardDistributor.verify(data, 0x1111111111111111111111111111111111111112));
    }

    function test_verifyProof_invalidAmount() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal_fail,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);
        assertFalse(rewardDistributor.verify(data, alice));
    }

    function test_verifyProof_invalidCycle() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 2,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);
        assertFalse(rewardDistributor.verify(data, alice));
    }

    function test_claim_success() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);

        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);
        payload[0] = data;
        vm.prank(alice);
        rewardDistributor.claim(payload);

        assertEq(token.balanceOf(alice), rewardsTotal0);
    }

    function test_claim_twoCycles() public {
        bytes32[] memory proof = new bytes32[](1);
        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);

        // Do cycle 1
        rewardDistributor.addTreeRoot(treeRoot0);
        proof[0] = proof0;
        RewardsDistributor.ClaimRequest memory data1 = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        payload[0] = data1;

        vm.prank(alice);
        rewardDistributor.claim(payload);
        assertEq(token.balanceOf(alice), rewardsTotal0);
        assertEq(rewardDistributor.yieldSharesClaimed(alice, address(mockVault), 1), rewardsTotal0);

        // Do cycle 2
        rewardDistributor.addTreeRoot(treeRoot1);
        proof[0] = proof1;
        RewardsDistributor.ClaimRequest memory data2 = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 2,
            yieldSharesTotal: rewardsTotal1,
            proof: proof
        });
        payload[0] = data2;

        vm.prank(alice);
        rewardDistributor.claim(payload);
        //assertEq(token.balanceOf(alice), rewardsTotal0 + rewardsTotal1);
        //assertEq(rewardDistributor.yieldSharesClaimed(alice, address(mockVault), 2), rewardsTotal1);
    }

    function test_claim_revertAlreadyClaimed() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);

        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(alice);
        rewardDistributor.claim(payload);
        vm.expectRevert(abi.encodeWithSelector(RewardsDistributor.ProofAlreadyClaimed.selector, 0));
        rewardDistributor.claim(payload);
        vm.stopPrank();
    }

    function test_claim_revertInvalidProof() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = proof0;
        proof[1] = proof1;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);

        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(RewardsDistributor.InvalidProof.selector, 0));
        rewardDistributor.claim(payload);
        vm.stopPrank();
    }

    function test_claim_revertSystemPaused() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = proof0;
        proof[1] = proof1;

        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        rewardDistributor.addTreeRoot(treeRoot0);

        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);
        payload[0] = data;

        rewardDistributor.pause();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        rewardDistributor.claim(payload);
    }
}

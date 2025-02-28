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
 *   ["0x1111111111111111111111111111111111111111", "1", "0x1d1499e622D69689cdf9004d05Ec547d650Ff211", "1", "5000000000000000000"],
 *   ["0x2222222222222222222222222222222222222222", "1", "0x1d1499e622D69689cdf9004d05Ec547d650Ff211", "1", "5000000000000000000"],
 * ];
 * // cycle 2
 * const values2 = [
 *   ["0x1111111111111111111111111111111111111111", "2", "0x1d1499e622D69689cdf9004d05Ec547d650Ff211", "1", "5010000000000000000"],
 *   ["0x2222222222222222222222222222222222222222", "2", "0x1d1499e622D69689cdf9004d05Ec547d650Ff211", "1", "5010000000000000000"],
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
    event PoolRootAdded(uint256 indexed cycle, RewardsDistributor.Root root);
    event PoolRootUpdated(uint256 indexed cycle, RewardsDistributor.Root previousRoot, RewardsDistributor.Root newRoot);

    RewardsDistributor public rewardsDistributor;
    IYelayLiteVault public mockVault;
    MockToken token;
    uint256 public projectId = 1;

    bytes32 constant treeRoot0 = 0xd819a32ef83898d5bc2e494eb5a09e040b01a3fbe329d2e8e3c7dcfa57531a86;
    bytes32 constant treeRoot1 = 0x2bd53706981cbb6fc2a65f578277d28393d9a653790cce73af2fe0820967a38d;

    bytes32 constant proof0 = 0xfecb0b85efc37879e10a6b092546938f20c056b2db5b624b73bdd7fdf1574124;
    bytes32 constant proof1 = 0xa12f215bcd1b483809cca5b2a7ed0a99cb6682da7589961c20dea5e0d1acb6f4;
    bytes32 constant proof_fail = bytes32(uint256(proof0) - 1);

    uint256 constant rewardsTotal0 = 5000000000000000000;
    uint256 constant rewardsTotal1 = 5010000000000000000;
    uint256 constant rewardsTotal_fail = rewardsTotal0 + 1;

    address user = 0x1111111111111111111111111111111111111111;
    address user_fail = address(bytes20(uint160(user) + 1));

    address vault = 0x1d1499e622D69689cdf9004d05Ec547d650Ff211;
    address vault_fail = address(bytes20(uint160(vault) + 1));

    function setUp() public {
        token = new MockToken("Underlying", "UND", 18);

        RewardsDistributor impl = new RewardsDistributor();
        rewardsDistributor = RewardsDistributor(
            address(
                new ERC1967Proxy(
                    address(impl),
                    abi.encodeWithSelector(RewardsDistributor.initialize.selector, address(this), address(this))
                )
            )
        );

        mockVault = Utils.deployDiamond(address(this), address(token), address(rewardsDistributor), "");
        assertEq(address(mockVault), vault);

        mockVault.grantRole(LibRoles.QUEUES_OPERATOR, address(this));
        mockVault.grantRole(LibRoles.STRATEGY_AUTHORITY, address(this));
        mockVault.grantRole(LibRoles.FUNDS_OPERATOR, address(this));

        mintYieldShares(rewardsTotal1);
    }

    function mintYieldShares(uint256 amount) internal {
        // 1. modify mockVault.underlyingBalance storage with 'amount'
        vm.record();
        mockVault.underlyingBalance();
        (bytes32[] memory reads,) = vm.accesses(address(mockVault));
        vm.store(address(mockVault), reads[1], bytes32(amount));

        // 2. mint 'amount' of token to mockVault
        deal(address(token), address(mockVault), amount);

        // 3. mockVault.accrueFee: rewardsDistributor now has 'amount' shares of project 0
        mockVault.accrueFee();
    }

    function addTreeRoot(bytes32 hash) internal returns (RewardsDistributor.Root memory root) {
        root = RewardsDistributor.Root({hash: hash, blockNumber: block.number});
        uint256 cycleBefore = rewardsDistributor.cycleCount();
        vm.expectEmit(true, true, true, true);
        emit PoolRootAdded(cycleBefore + 1, root);
        rewardsDistributor.addTreeRoot(root);

        uint256 cycle = rewardsDistributor.cycleCount();
        assertEq(cycle, cycleBefore + 1);
        assertEq(getTreeRoot(cycle), hash);
    }

    function getTreeRoot(uint256 cycle) internal view returns (bytes32 hash) {
        (hash,) = rewardsDistributor.roots(cycle);
    }

    function test_addRoot_success() public {
        addTreeRoot(treeRoot0);
    }

    function test_updateRoot_success() public {
        RewardsDistributor.Root memory root0 = addTreeRoot(treeRoot0);

        uint256 cycle = rewardsDistributor.cycleCount();

        RewardsDistributor.Root memory root1 = addTreeRoot(treeRoot1);

        vm.expectEmit(true, true, true, true);
        emit PoolRootUpdated(cycle, root0, root1);
        rewardsDistributor.updateTreeRoot(root1, 1);

        assertEq(getTreeRoot(1), treeRoot1);
    }

    function test_updateRoot_revertInvalidCycle() public {
        RewardsDistributor.Root memory root0 = addTreeRoot(treeRoot0);
        vm.expectRevert(abi.encodeWithSelector(RewardsDistributor.InvalidCycle.selector));
        rewardsDistributor.updateTreeRoot(root0, 10);
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
        addTreeRoot(treeRoot0);
        assertTrue(rewardsDistributor.verify(data, user));
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
        addTreeRoot(treeRoot0);
        assertFalse(rewardsDistributor.verify(data, user));
    }

    function test_verifyProof_invalidYelayLiteVault() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        // Replace with an invalid vault address
        RewardsDistributor.ClaimRequest memory data = RewardsDistributor.ClaimRequest({
            yelayLiteVault: vault_fail,
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        addTreeRoot(treeRoot0);
        assertFalse(rewardsDistributor.verify(data, user));
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
        addTreeRoot(treeRoot0);
        // Using a different user than user
        assertFalse(rewardsDistributor.verify(data, user_fail));
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
        addTreeRoot(treeRoot0);
        assertFalse(rewardsDistributor.verify(data, user));
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
        addTreeRoot(treeRoot0);
        assertFalse(rewardsDistributor.verify(data, user));
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
        addTreeRoot(treeRoot0);

        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);
        payload[0] = data;
        vm.prank(user);
        rewardsDistributor.claim(payload);

        assertEq(token.balanceOf(user), rewardsTotal0);
    }

    function test_claim_twoCycles() public {
        bytes32[] memory proof = new bytes32[](1);
        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);

        // Do cycle 1 - user has 5 shares to claim
        addTreeRoot(treeRoot0);
        proof[0] = proof0;
        RewardsDistributor.ClaimRequest memory data1 = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: rewardsTotal0,
            proof: proof
        });
        payload[0] = data1;

        vm.prank(user);
        rewardsDistributor.claim(payload);
        assertEq(token.balanceOf(user), rewardsTotal0);
        assertEq(rewardsDistributor.yieldSharesClaimed(user, address(mockVault), 1), rewardsTotal0);

        // Do cycle 2 - user has another .01 shares to claim, for a total of 5.01
        addTreeRoot(treeRoot1);
        proof[0] = proof1;
        RewardsDistributor.ClaimRequest memory data2 = RewardsDistributor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 2,
            yieldSharesTotal: rewardsTotal1,
            proof: proof
        });
        payload[0] = data2;

        vm.prank(user);
        rewardsDistributor.claim(payload);
        assertEq(token.balanceOf(user), rewardsTotal1);
        assertEq(rewardsDistributor.yieldSharesClaimed(user, address(mockVault), 1), rewardsTotal1);
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
        addTreeRoot(treeRoot0);

        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(user);
        rewardsDistributor.claim(payload);
        vm.expectRevert(abi.encodeWithSelector(RewardsDistributor.ProofAlreadyClaimed.selector, 0));
        rewardsDistributor.claim(payload);
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
        addTreeRoot(treeRoot0);

        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(RewardsDistributor.InvalidProof.selector, 0));
        rewardsDistributor.claim(payload);
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
        addTreeRoot(treeRoot0);

        RewardsDistributor.ClaimRequest[] memory payload = new RewardsDistributor.ClaimRequest[](1);
        payload[0] = data;

        rewardsDistributor.pause();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        rewardsDistributor.claim(payload);
    }
}

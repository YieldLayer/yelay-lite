// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";
import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

/**
 * Tree data generated using openzeppelin/merkle-tree:
 *
 * import { StandardMerkleTree } from "openzeppelin/merkle-tree";
 *
 * // (1)
 * // user, cycle, vault, projectId, yield
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
 * // 2nd vault
 * const values3 = [
 *   ["0x1111111111111111111111111111111111111111", "1", "0xD16d567549A2a2a2005aEACf7fB193851603dd70", "1", "5000000000000000000"],
 *   ["0x2222222222222222222222222222222222222222", "1", "0xD16d567549A2a2a2005aEACf7fB193851603dd70", "1", "5000000000000000000"],
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
 * // (3)
 * tree = StandardMerkleTree.of(values3, ["address", "uint256", "address", "uint256", "uint256"]);
 * console.log('Merkle Root (3):', tree.root);
 * console.log('Tree(3):', tree.dump());
 */
contract YieldExtractorTest is Test {
    YieldExtractor public yieldExtractor;
    IYelayLiteVault public mockVault0;
    IYelayLiteVault public mockVault1;
    MockToken token;
    uint256 public projectId = 1;

    bytes32 constant treeRootZero = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant treeRoot0 = 0xd819a32ef83898d5bc2e494eb5a09e040b01a3fbe329d2e8e3c7dcfa57531a86;
    bytes32 constant treeRoot1 = 0x2bd53706981cbb6fc2a65f578277d28393d9a653790cce73af2fe0820967a38d;
    bytes32 constant treeRoot2 = 0x458e69c92a655a7cd3bf07e89d34cdf8a59e5374351808b19618f3fc698df01b;

    bytes32 constant proof0 = 0xfecb0b85efc37879e10a6b092546938f20c056b2db5b624b73bdd7fdf1574124;
    bytes32 constant proof1 = 0xa12f215bcd1b483809cca5b2a7ed0a99cb6682da7589961c20dea5e0d1acb6f4;
    bytes32 constant proof2 = 0xa755219ea9b789ff7d4957c854b2a199f5141888b5a2bd1c183e44f72b55419e;
    bytes32 constant proof_fail = bytes32(uint256(proof0) - 1);

    uint256 constant yieldTotal0 = 5000000000000000000;
    uint256 constant yieldTotal1 = 5010000000000000000;
    uint256 constant yieldTotal2 = 5000000000000000000;
    uint256 constant yieldTotal_fail = yieldTotal0 + 1;

    address owner = address(0x01);
    address yieldPublisher = address(0x02);
    address pauser = address(0x03);
    address unpauser = address(0x04);

    address user = 0x1111111111111111111111111111111111111111;
    address user_fail = address(bytes20(uint160(user) + 1));

    address vault0 = 0x1d1499e622D69689cdf9004d05Ec547d650Ff211;
    address vault1 = 0xD16d567549A2a2a2005aEACf7fB193851603dd70;
    address vault_fail = address(bytes20(uint160(vault0) + 1));

    function setUp() public {
        token = new MockToken("Underlying", "UND", 18);

        YieldExtractor impl = new YieldExtractor();
        yieldExtractor = YieldExtractor(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeWithSelector(YieldExtractor.initialize.selector, owner, yieldPublisher)
                )
            )
        );

        mockVault0 = setupMockVault(vault0, yieldTotal1);
        mockVault1 = setupMockVault(vault1, yieldTotal1);
    }

    function setupMockVault(address vaultAddress, uint256 yieldTotal) internal returns (IYelayLiteVault) {
        // 1. deploy mockVault
        IYelayLiteVault mockVault = Utils.deployDiamond(address(this), address(token), address(yieldExtractor), "");
        assertEq(address(mockVault), vaultAddress);

        // 2. grant roles
        mockVault.grantRole(LibRoles.QUEUES_OPERATOR, address(this));
        mockVault.grantRole(LibRoles.STRATEGY_AUTHORITY, address(this));
        mockVault.grantRole(LibRoles.FUNDS_OPERATOR, address(this));

        // 3. modify mockVault.underlyingBalance storage with 'yieldTotal'
        vm.record();
        mockVault.underlyingBalance();
        (bytes32[] memory reads,) = vm.accesses(address(mockVault));
        vm.store(address(mockVault), reads[1], bytes32(yieldTotal));

        // 4. mint 'yieldTotal' of token to mockVault
        deal(address(token), address(mockVault), yieldTotal);

        // 5. mockVault.accrueFee: yieldExtractor now has 'yieldTotal' shares of project 0
        mockVault.accrueFee();
        return mockVault;
    }

    function getTreeRoot(uint256 cycle, address yelayLiteVault) internal view returns (bytes32 hash) {
        (hash,) = yieldExtractor.roots(yelayLiteVault, cycle);
    }

    function test_addRoot_success() public {
        uint256 cycleBefore = yieldExtractor.cycleCount(address(mockVault0));

        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        vm.expectEmit(true, true, true, true);
        emit LibEvents.PoolRootAdded(address(mockVault0), cycleBefore + 1, root.hash, root.blockNumber);
        yieldExtractor.addTreeRoot(root, address(mockVault0));
        vm.stopPrank();

        uint256 cycle = yieldExtractor.cycleCount(address(mockVault0));
        assertEq(cycle, cycleBefore + 1);
        assertEq(getTreeRoot(cycle, address(mockVault0)), treeRoot0);
    }

    function test_addRoot_twoVaults() public {
        uint256 cycleVault0 = yieldExtractor.cycleCount(address(mockVault0));
        uint256 cycleVault1 = yieldExtractor.cycleCount(address(mockVault1));

        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        vm.expectEmit(true, true, true, true);
        emit LibEvents.PoolRootAdded(address(mockVault0), cycleVault0 + 1, root.hash, root.blockNumber);
        yieldExtractor.addTreeRoot(root, address(mockVault0));
        vm.stopPrank();

        assertEq(cycleVault0 + 1, yieldExtractor.cycleCount(address(mockVault0)));
        cycleVault0 = yieldExtractor.cycleCount(address(mockVault0));
        assertEq(getTreeRoot(cycleVault0, address(mockVault0)), treeRoot0);
        assertEq(getTreeRoot(cycleVault1, address(mockVault1)), treeRootZero);

        vm.startPrank(yieldPublisher);
        root = YieldExtractor.Root({hash: treeRoot2, blockNumber: block.number});
        vm.expectEmit(true, true, true, true);
        emit LibEvents.PoolRootAdded(address(mockVault1), cycleVault1 + 1, root.hash, root.blockNumber);
        yieldExtractor.addTreeRoot(root, address(mockVault1));
        vm.stopPrank();

        assertEq(cycleVault1 + 1, yieldExtractor.cycleCount(address(mockVault1)));
        cycleVault1 = yieldExtractor.cycleCount(address(mockVault1));
        assertEq(cycleVault1, cycleVault0);
        assertEq(getTreeRoot(cycleVault0, address(mockVault0)), treeRoot0);
        assertEq(getTreeRoot(cycleVault1, address(mockVault1)), treeRoot2);
    }

    function test_addRoot_failure() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), LibRoles.YIELD_PUBLISHER
            )
        );
        YieldExtractor.Root memory root = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root, address(mockVault0));
    }

    function test_updateRoot_success() public {
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        YieldExtractor.Root memory root2 = YieldExtractor.Root({hash: treeRoot2, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root2, address(mockVault1));
        vm.stopPrank();

        uint256 cycle = yieldExtractor.cycleCount(address(mockVault0));

        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root1 = YieldExtractor.Root({hash: treeRoot1, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root1, address(mockVault0));
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), LibRoles.YIELD_PUBLISHER
            )
        );
        yieldExtractor.updateTreeRoot(root1, 1, address(mockVault0));

        assertEq(getTreeRoot(1, address(mockVault0)), treeRoot0);
        assertEq(getTreeRoot(2, address(mockVault0)), treeRoot1);
        assertEq(getTreeRoot(1, address(mockVault1)), treeRoot2);

        vm.startPrank(yieldPublisher);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.PoolRootUpdated(address(mockVault0), cycle, root0.hash, root1.hash, root1.blockNumber);
        yieldExtractor.updateTreeRoot(root1, 1, address(mockVault0));
        vm.stopPrank();

        assertEq(getTreeRoot(1, address(mockVault0)), treeRoot1);
        assertEq(getTreeRoot(2, address(mockVault0)), treeRoot1);
        assertEq(getTreeRoot(1, address(mockVault1)), treeRoot2);
    }

    function test_updateRoot_revertInvalidCycle() public {
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));

        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidCycle.selector));
        yieldExtractor.updateTreeRoot(root0, 10, address(mockVault0));
        vm.stopPrank();
    }

    function test_verifyProof_success() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();
        assertTrue(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_invalidProof() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof_fail;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_invalidYelayLiteVault() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        // Replace with an invalid vault address
        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: vault_fail, projectId: projectId, cycle: 1, yieldSharesTotal: yieldTotal0, proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_differentYelayLiteVault() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});

        // Added to different vault
        yieldExtractor.addTreeRoot(root0, address(mockVault1));
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_invalidUser() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();
        // Using a different user than user
        assertFalse(yieldExtractor.verify(data, user_fail));
    }

    function test_verifyProof_invalidAmount() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal_fail,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_invalidCycle() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 2,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_claim_success() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();

        YieldExtractor.ClaimRequest[] memory payload = new YieldExtractor.ClaimRequest[](1);
        payload[0] = data;
        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.YieldClaimed(user, data.yelayLiteVault, data.projectId, data.cycle, data.yieldSharesTotal);
        yieldExtractor.claim(payload);

        assertEq(token.balanceOf(user), yieldTotal0);
    }

    function test_claim_twoCycles() public {
        bytes32[] memory proof = new bytes32[](1);
        YieldExtractor.ClaimRequest[] memory payload = new YieldExtractor.ClaimRequest[](1);

        // Do cycle 1 - user has 5 shares to claim
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();
        proof[0] = proof0;
        YieldExtractor.ClaimRequest memory data1 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        payload[0] = data1;

        vm.prank(user);
        yieldExtractor.claim(payload);
        assertEq(token.balanceOf(user), yieldTotal0);
        assertEq(yieldExtractor.yieldSharesClaimed(user, address(mockVault0), 1), yieldTotal0);

        // Do cycle 2 - user has another .01 shares to claim, for a total of 5.01
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root1 = YieldExtractor.Root({hash: treeRoot1, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root1, address(mockVault0));
        vm.stopPrank();
        proof[0] = proof1;
        YieldExtractor.ClaimRequest memory data2 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 2,
            yieldSharesTotal: yieldTotal1,
            proof: proof
        });
        payload[0] = data2;

        vm.prank(user);
        yieldExtractor.claim(payload);
        assertEq(token.balanceOf(user), yieldTotal1);
        assertEq(yieldExtractor.yieldSharesClaimed(user, address(mockVault0), 1), yieldTotal1);
    }

    function test_claim_twoVaults() public {
        bytes32[] memory proof_1 = new bytes32[](1);
        proof_1[0] = proof0;
        YieldExtractor.ClaimRequest memory data1 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof_1
        });

        bytes32[] memory proof_2 = new bytes32[](1);
        proof_2[0] = proof2;
        YieldExtractor.ClaimRequest memory data2 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault1),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal2,
            proof: proof_2
        });

        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        YieldExtractor.Root memory root1 = YieldExtractor.Root({hash: treeRoot2, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root1, address(mockVault1));
        vm.stopPrank();

        // Claim from vault 0
        YieldExtractor.ClaimRequest[] memory payload = new YieldExtractor.ClaimRequest[](1);
        payload[0] = data1;
        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.YieldClaimed(user, data1.yelayLiteVault, data1.projectId, data1.cycle, data1.yieldSharesTotal);
        yieldExtractor.claim(payload);

        assertEq(token.balanceOf(user), yieldTotal0);
        assertEq(yieldExtractor.yieldSharesClaimed(user, address(mockVault0), 1), yieldTotal0);
        assertEq(yieldExtractor.yieldSharesClaimed(user, address(mockVault1), 1), 0);

        // Claim from vault 1
        payload[0] = data2;
        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.YieldClaimed(user, data2.yelayLiteVault, data2.projectId, data2.cycle, data2.yieldSharesTotal);
        yieldExtractor.claim(payload);

        assertEq(token.balanceOf(user), yieldTotal0 + yieldTotal2);
        assertEq(yieldExtractor.yieldSharesClaimed(user, address(mockVault0), 1), yieldTotal0);
        assertEq(yieldExtractor.yieldSharesClaimed(user, address(mockVault1), 1), yieldTotal2);
    }

    function test_claim_revertAlreadyClaimed() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();

        YieldExtractor.ClaimRequest[] memory payload = new YieldExtractor.ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(user);
        yieldExtractor.claim(payload);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ProofAlreadyClaimed.selector, 0));
        yieldExtractor.claim(payload);
        vm.stopPrank();
    }

    function test_claim_revertInvalidProof() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = proof0;
        proof[1] = proof1;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();

        YieldExtractor.ClaimRequest[] memory payload = new YieldExtractor.ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidProof.selector, 0));
        yieldExtractor.claim(payload);
        vm.stopPrank();
    }

    function test_roles_pausing() public {
        vm.startPrank(pauser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, pauser, LibRoles.PAUSER)
        );
        yieldExtractor.pause();
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), 0x00)
        );
        yieldExtractor.grantRole(LibRoles.PAUSER, pauser);

        vm.startPrank(owner);
        yieldExtractor.grantRole(LibRoles.PAUSER, pauser);
        vm.stopPrank();

        assertTrue(yieldExtractor.hasRole(LibRoles.PAUSER, pauser));

        assertFalse(yieldExtractor.paused());

        vm.startPrank(pauser);
        yieldExtractor.pause();
        vm.stopPrank();

        assertTrue(yieldExtractor.paused());

        vm.startPrank(unpauser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unpauser, LibRoles.UNPAUSER
            )
        );
        yieldExtractor.unpause();
        vm.stopPrank();

        vm.startPrank(owner);
        yieldExtractor.grantRole(LibRoles.UNPAUSER, unpauser);
        vm.stopPrank();

        vm.startPrank(unpauser);
        yieldExtractor.unpause();
        assertFalse(yieldExtractor.paused());
        vm.stopPrank();
    }

    function test_roles_upgrade() public {
        address newImpl = address(new YieldExtractor());
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), 0x00)
        );
        yieldExtractor.upgradeToAndCall(newImpl, "");

        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        {
            bytes32 implBytes = vm.load(address(yieldExtractor), implSlot);
            address impl = address(uint160(uint256(implBytes)));
            console.log(impl);
            assertNotEq(impl, newImpl);
        }

        vm.startPrank(owner);
        yieldExtractor.upgradeToAndCall(newImpl, "");
        vm.stopPrank();

        {
            bytes32 implBytes = vm.load(address(yieldExtractor), implSlot);
            address impl = address(uint160(uint256(implBytes)));
            assertEq(impl, newImpl);
        }
    }

    function test_claim_revertSystemPaused() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = proof0;
        proof[1] = proof1;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault0),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0, address(mockVault0));
        vm.stopPrank();

        YieldExtractor.ClaimRequest[] memory payload = new YieldExtractor.ClaimRequest[](1);
        payload[0] = data;

        vm.startPrank(owner);
        yieldExtractor.grantRole(LibRoles.PAUSER, pauser);
        vm.stopPrank();
        vm.startPrank(pauser);
        yieldExtractor.pause();
        vm.stopPrank();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        yieldExtractor.claim(payload);
    }

    function test_ownership_transfer() public {
        assertEq(owner, yieldExtractor.owner());

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminRules.selector)
        );
        yieldExtractor.grantRole(0x00, yieldPublisher);

        yieldExtractor.beginDefaultAdminTransfer(yieldPublisher);
        vm.stopPrank();

        assertEq(owner, yieldExtractor.owner());
        {
            (address newOwner,) = yieldExtractor.pendingDefaultAdmin();
            assertEq(newOwner, yieldPublisher);
        }

        vm.warp(block.timestamp + 1);

        vm.startPrank(yieldPublisher);
        yieldExtractor.acceptDefaultAdminTransfer();
        vm.stopPrank();

        assertEq(yieldPublisher, yieldExtractor.owner());
        {
            (address newOwner,) = yieldExtractor.pendingDefaultAdmin();
            assertEq(newOwner, address(0));
        }
    }
}

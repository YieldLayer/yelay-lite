// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
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
contract YieldExtractorTest is Test {
    YieldExtractor public yieldExtractor;
    IYelayLiteVault public mockVault;
    MockToken token;
    uint256 public projectId = 1;

    bytes32 constant treeRoot0 = 0xd819a32ef83898d5bc2e494eb5a09e040b01a3fbe329d2e8e3c7dcfa57531a86;
    bytes32 constant treeRoot1 = 0x2bd53706981cbb6fc2a65f578277d28393d9a653790cce73af2fe0820967a38d;

    bytes32 constant proof0 = 0xfecb0b85efc37879e10a6b092546938f20c056b2db5b624b73bdd7fdf1574124;
    bytes32 constant proof1 = 0xa12f215bcd1b483809cca5b2a7ed0a99cb6682da7589961c20dea5e0d1acb6f4;
    bytes32 constant proof_fail = bytes32(uint256(proof0) - 1);

    uint256 constant yieldTotal0 = 5000000000000000000;
    uint256 constant yieldTotal1 = 5010000000000000000;
    uint256 constant yieldTotal_fail = yieldTotal0 + 1;

    address owner = address(0x01);
    address yieldPublisher = address(0x02);
    address pauser = address(0x03);
    address unpauser = address(0x04);

    address user = 0x1111111111111111111111111111111111111111;
    address user_fail = address(bytes20(uint160(user) + 1));

    address vault = 0x1d1499e622D69689cdf9004d05Ec547d650Ff211;
    address vault_fail = address(bytes20(uint160(vault) + 1));

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

        mockVault = Utils.deployDiamond(address(this), address(token), address(yieldExtractor), "");
        assertEq(address(mockVault), vault);

        mockVault.grantRole(LibRoles.QUEUES_OPERATOR, address(this));
        mockVault.grantRole(LibRoles.STRATEGY_AUTHORITY, address(this));
        mockVault.grantRole(LibRoles.FUNDS_OPERATOR, address(this));

        mintYieldShares(yieldTotal1);
    }

    function mintYieldShares(uint256 amount) internal {
        // 1. modify mockVault.underlyingBalance storage with 'amount'
        vm.record();
        mockVault.underlyingBalance();
        (bytes32[] memory reads,) = vm.accesses(address(mockVault));
        vm.store(address(mockVault), reads[1], bytes32(amount));

        // 2. mint 'amount' of token to mockVault
        deal(address(token), address(mockVault), amount);

        // 3. mockVault.accrueFee: yieldExtractor now has 'amount' shares of project 0
        mockVault.accrueFee();
    }

    function getTreeRoot(uint256 cycle) internal view returns (bytes32 hash) {
        (hash,) = yieldExtractor.roots(cycle);
    }

    function test_addRoot_success() public {
        uint256 cycleBefore = yieldExtractor.cycleCount();

        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        vm.expectEmit(true, true, true, true);
        emit LibEvents.PoolRootAdded(cycleBefore + 1, root.hash, root.blockNumber);
        yieldExtractor.addTreeRoot(root);
        vm.stopPrank();

        uint256 cycle = yieldExtractor.cycleCount();
        assertEq(cycle, cycleBefore + 1);
        assertEq(getTreeRoot(cycle), treeRoot0);
    }

    function test_addRoot_failure() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), LibRoles.YIELD_PUBLISHER
            )
        );
        YieldExtractor.Root memory root = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root);
    }

    function test_updateRoot_success() public {
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
        vm.stopPrank();

        uint256 cycle = yieldExtractor.cycleCount();

        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root1 = YieldExtractor.Root({hash: treeRoot1, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root1);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), LibRoles.YIELD_PUBLISHER
            )
        );
        yieldExtractor.updateTreeRoot(root1, 1);

        assertEq(getTreeRoot(1), treeRoot0);
        assertEq(getTreeRoot(2), treeRoot1);

        vm.startPrank(yieldPublisher);
        vm.expectEmit(true, true, true, true);
        emit LibEvents.PoolRootUpdated(cycle, root0.hash, root1.hash, root1.blockNumber);
        yieldExtractor.updateTreeRoot(root1, 1);
        vm.stopPrank();

        assertEq(getTreeRoot(1), treeRoot1);
        assertEq(getTreeRoot(2), treeRoot1);
    }

    function test_updateRoot_revertInvalidCycle() public {
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidCycle.selector));
        yieldExtractor.updateTreeRoot(root0, 10);
        vm.stopPrank();
    }

    function test_verifyProof_success() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
        vm.stopPrank();
        assertTrue(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_invalidProof() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof_fail;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_invalidYelayLiteVault() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        // Replace with an invalid vault address
        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: vault_fail,
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_invalidUser() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
        vm.stopPrank();
        // Using a different user than user
        assertFalse(yieldExtractor.verify(data, user_fail));
    }

    function test_verifyProof_invalidAmount() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal_fail,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_verifyProof_invalidCycle() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 2,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
        vm.stopPrank();
        assertFalse(yieldExtractor.verify(data, user));
    }

    function test_claim_success() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
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
        yieldExtractor.addTreeRoot(root0);
        vm.stopPrank();
        proof[0] = proof0;
        YieldExtractor.ClaimRequest memory data1 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        payload[0] = data1;

        vm.prank(user);
        yieldExtractor.claim(payload);
        assertEq(token.balanceOf(user), yieldTotal0);
        assertEq(yieldExtractor.yieldSharesClaimed(user, address(mockVault), 1), yieldTotal0);

        // Do cycle 2 - user has another .01 shares to claim, for a total of 5.01
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root1 = YieldExtractor.Root({hash: treeRoot1, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root1);
        vm.stopPrank();
        proof[0] = proof1;
        YieldExtractor.ClaimRequest memory data2 = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 2,
            yieldSharesTotal: yieldTotal1,
            proof: proof
        });
        payload[0] = data2;

        vm.prank(user);
        yieldExtractor.claim(payload);
        assertEq(token.balanceOf(user), yieldTotal1);
        assertEq(yieldExtractor.yieldSharesClaimed(user, address(mockVault), 1), yieldTotal1);
    }

    function test_claim_revertAlreadyClaimed() public {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proof0;

        YieldExtractor.ClaimRequest memory data = YieldExtractor.ClaimRequest({
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
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
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
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
            yelayLiteVault: address(mockVault),
            projectId: projectId,
            cycle: 1,
            yieldSharesTotal: yieldTotal0,
            proof: proof
        });
        vm.startPrank(yieldPublisher);
        YieldExtractor.Root memory root0 = YieldExtractor.Root({hash: treeRoot0, blockNumber: block.number});
        yieldExtractor.addTreeRoot(root0);
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
}

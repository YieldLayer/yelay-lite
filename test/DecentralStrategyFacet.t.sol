// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

import {MockToken} from "./MockToken.sol";
import {Utils} from "./Utils.sol";

/*//////////////////////////////////////////////////////////////
                    Facet interface via the diamond
//////////////////////////////////////////////////////////////*/
interface IDecentralStrategyFacet {
    function decentralDeposit(uint256 projectId, uint256 amount) external;
    function requestDecentralYield(uint256 projectId) external;
    function finalizeDecentralYield(uint256 projectId) external returns (uint256 received);
    function requestDecentralPrincipal(uint256 projectId) external;
    function finalizeDecentralPrincipal(uint256 projectId) external returns (uint256 received);

    function decentralPosition(uint256 projectId)
        external
        view
        returns (
            uint256 tokenId,
            uint256 principal,
            bool yieldRequested,
            bool principalRequested,
            bool closed
        );
}

/*//////////////////////////////////////////////////////////////
                        Mock Decentral Pool
- Designed to be etched onto the real pool address used by the facet.
- Minimal semantics needed by the facet.
//////////////////////////////////////////////////////////////*/
contract MockDecentralPool {
    MockToken public stable;
    uint256 public principalDelay;

    uint256 public nextTokenId;

    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => uint256) public principalOf;

    struct YieldReq {
        uint256 amount;
        bool exists;
        bool approved;
    }

    struct PrincipalReq {
        uint256 amount;
        uint256 availableTs;
        bool exists;
        bool approved;
    }

    mapping(uint256 => YieldReq) public yieldReq;
    mapping(uint256 => PrincipalReq) public principalReq;

    function initialize(address stable_, uint256 principalDelay_) external {
        stable = MockToken(stable_);
        principalDelay = principalDelay_;
        if (nextTokenId == 0) nextTokenId = 1;
    }

    function stablecoinAddress() external view returns (address) {
        return address(stable);
    }

    function deposit(uint256 amount) external returns (uint256 tokenId) {
        require(amount > 0, "amount=0");

        tokenId = nextTokenId++;
        ownerOf[tokenId] = msg.sender;
        principalOf[tokenId] = amount;

        // Pull stable from depositor (the vault/diamond)
        stable.transferFrom(msg.sender, address(this), amount);
    }

    function requestYieldWithdrawal(uint256 tokenId) external {
        require(ownerOf[tokenId] == msg.sender, "not owner");
        YieldReq storage r = yieldReq[tokenId];
        require(!r.exists, "exists");

        // for tests we just make it deterministic
        r.amount = 123;
        r.exists = true;
        r.approved = false;
    }

    function approveYieldWithdrawal(uint256 tokenId) external {
        YieldReq storage r = yieldReq[tokenId];
        require(r.exists, "no req");
        r.approved = true;
    }

    function getYieldWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256 amount, uint256 requestTimestamp, bool exists, bool approved)
    {
        YieldReq storage r = yieldReq[tokenId];
        return (r.amount, 0, r.exists, r.approved);
    }

    function executeYieldWithdrawal(uint256 tokenId) external {
        require(ownerOf[tokenId] == msg.sender, "not owner");
        YieldReq storage r = yieldReq[tokenId];
        require(r.exists && r.approved, "not approved");

        uint256 amt = r.amount;
        delete yieldReq[tokenId];

        stable.transfer(msg.sender, amt);
    }

    function requestPrincipalWithdrawal(uint256 tokenId) external {
        require(ownerOf[tokenId] == msg.sender, "not owner");
        PrincipalReq storage r = principalReq[tokenId];
        require(!r.exists, "exists");

        uint256 amt = principalOf[tokenId];
        r.amount = amt;
        r.availableTs = block.timestamp + principalDelay;
        r.exists = true;
        r.approved = false;
    }

    function approvePrincipalWithdrawal(uint256 tokenId) external {
        PrincipalReq storage r = principalReq[tokenId];
        require(r.exists, "no req");
        r.approved = true;
    }

    function getPrincipalWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256 amount, uint256 requestTimestamp, uint256 availableTimestamp, bool exists, bool approved)
    {
        PrincipalReq storage r = principalReq[tokenId];
        return (r.amount, 0, r.availableTs, r.exists, r.approved);
    }

    function executePrincipalWithdrawal(uint256 tokenId) external {
        require(ownerOf[tokenId] == msg.sender, "not owner");
        PrincipalReq storage r = principalReq[tokenId];
        require(r.exists && r.approved, "not approved");
        require(block.timestamp >= r.availableTs, "too early");

        uint256 amt = r.amount;
        delete principalReq[tokenId];

        // Simulate principal redemption
        principalOf[tokenId] = 0;
        stable.transfer(msg.sender, amt);
    }
}

contract DecentralStrategyFacetTest is Test {
    using Utils for address;

    address constant OWNER = address(0x01);
    address constant USER = address(0x02);
    address constant YIELD_EXTRACTOR = address(0x04);
    address constant FUNDS_OPERATOR = address(0x05);
    uint256 constant PROJECT_ID = 1;

    // Must match the constant in DecentralStrategyFacet
    address constant DECENTRAL_POOL_ADDR = 0x6fC42888f157A772968CaB5B95A4e42a38C07fD0;

    IYelayLiteVault vault;
    IDecentralStrategyFacet decentralFacet;
    MockToken underlying;

    function setUp() external {
        vm.startPrank(OWNER);

        // Underlying asset doubles as "stablecoin" in our mock pool
        underlying = new MockToken("Y-Test", "Y-T", 18);

        vault = Utils.deployDiamond(
            OWNER,
            address(underlying),
            YIELD_EXTRACTOR,
            "https://yelay-lite-vault/{id}.json"
        );

        // IMPORTANT: add DecentralStrategyFacet via upgrade helper (so legacy tests remain deterministic)
        Utils.upgradeToDecentralStrategyFacet(vault);

        decentralFacet = IDecentralStrategyFacet(address(vault));

        // Roles
        vault.grantRole(LibRoles.FUNDS_OPERATOR, FUNDS_OPERATOR);

        vm.stopPrank();

        // ---- install mock pool code at the exact address the facet calls ----
        MockDecentralPool impl = new MockDecentralPool();
        vm.etch(DECENTRAL_POOL_ADDR, address(impl).code);

        // init pool storage at the etched address
        MockDecentralPool(DECENTRAL_POOL_ADDR).initialize(address(underlying), 2 days);

        // Give the diamond approval to move its own underlying not needed; facet approves pool.
        // We just need the vault to have tokens when depositing.
    }

    function test_decentralDeposit_revert_unauthorized() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                USER,
                LibRoles.FUNDS_OPERATOR
            )
        );
        vm.prank(USER);
        decentralFacet.decentralDeposit(PROJECT_ID, 1e18);
    }

    function test_decentralDeposit_success_storesPosition() external {
        uint256 amount = 1000e18;

        // Vault needs underlying to deposit into pool
        deal(address(underlying), address(vault), amount);

        vm.prank(FUNDS_OPERATOR);
        decentralFacet.decentralDeposit(PROJECT_ID, amount);

        (uint256 tokenId, uint256 principal, bool yieldRequested, bool principalRequested, bool closed) =
            decentralFacet.decentralPosition(PROJECT_ID);

        assertGt(tokenId, 0);
        assertEq(principal, amount);
        assertEq(yieldRequested, false);
        assertEq(principalRequested, false);
        assertEq(closed, false);

        // Funds moved to pool
        assertEq(underlying.balanceOf(address(vault)), 0);
        assertEq(underlying.balanceOf(DECENTRAL_POOL_ADDR), amount);
    }

    function test_yieldFlow_request_then_finalize_requiresApproval() external {
        uint256 amount = 1000e18;
        deal(address(underlying), address(vault), amount);

        vm.prank(FUNDS_OPERATOR);
        decentralFacet.decentralDeposit(PROJECT_ID, amount);

        (uint256 tokenId,,,,) = decentralFacet.decentralPosition(PROJECT_ID);

        // request
        vm.prank(FUNDS_OPERATOR);
        decentralFacet.requestDecentralYield(PROJECT_ID);

        // finalize should revert until approved
        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("DECENTRAL_NOT_READY"));
        decentralFacet.finalizeDecentralYield(PROJECT_ID);

        // approve inside mock pool + fund pool with yield
        MockDecentralPool(DECENTRAL_POOL_ADDR).approveYieldWithdrawal(tokenId);
        deal(address(underlying), DECENTRAL_POOL_ADDR, underlying.balanceOf(DECENTRAL_POOL_ADDR) + 123);

        uint256 vaultBalBefore = underlying.balanceOf(address(vault));

        vm.prank(FUNDS_OPERATOR);
        uint256 received = decentralFacet.finalizeDecentralYield(PROJECT_ID);

        assertEq(received, 123);
        assertEq(underlying.balanceOf(address(vault)), vaultBalBefore + 123);

        // yieldRequested flag cleared
        (, , bool yieldRequested,,) = decentralFacet.decentralPosition(PROJECT_ID);
        assertEq(yieldRequested, false);
    }

    function test_principalFlow_request_then_finalize_requiresApprovalAndDelay() external {
        uint256 amount = 500e18;
        deal(address(underlying), address(vault), amount);

        vm.prank(FUNDS_OPERATOR);
        decentralFacet.decentralDeposit(PROJECT_ID, amount);

        (uint256 tokenId,,,,) = decentralFacet.decentralPosition(PROJECT_ID);

        // request principal
        vm.prank(FUNDS_OPERATOR);
        decentralFacet.requestDecentralPrincipal(PROJECT_ID);

        // not approved => not ready
        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("DECENTRAL_NOT_READY"));
        decentralFacet.finalizeDecentralPrincipal(PROJECT_ID);

        // approve but not delayed => still not ready
        MockDecentralPool(DECENTRAL_POOL_ADDR).approvePrincipalWithdrawal(tokenId);

        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("DECENTRAL_NOT_READY"));
        decentralFacet.finalizeDecentralPrincipal(PROJECT_ID);

        // warp past delay
        vm.warp(block.timestamp + 2 days + 1);

        uint256 vaultBalBefore = underlying.balanceOf(address(vault));

        vm.prank(FUNDS_OPERATOR);
        uint256 received = decentralFacet.finalizeDecentralPrincipal(PROJECT_ID);

        assertEq(received, amount);
        assertEq(underlying.balanceOf(address(vault)), vaultBalBefore + amount);

        // Position should be closed
        (, uint256 principal, , bool principalRequested, bool closed) =
            decentralFacet.decentralPosition(PROJECT_ID);

        assertEq(principal, 0);
        assertEq(principalRequested, false);
        assertEq(closed, true);
    }

    function test_decentralDeposit_revert_zeroAmount() external {
        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.ZeroAmount.selector));
        decentralFacet.decentralDeposit(PROJECT_ID, 0);
    }

}

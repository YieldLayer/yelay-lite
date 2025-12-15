// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {IYelayLiteVaultAsync} from "src/interfaces/IYelayLiteVaultAsync.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";

import {Utils} from "../Utils.sol";
import {BASE_USDC, USDC_DECIMALS} from "../Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IDecentralStrategyFacet {
    function decentralDeposit(uint256 projectId, uint256 amount) external;
    function requestDecentralYield(uint256 projectId) external;
    function finalizeDecentralYield(uint256 projectId) external returns (uint256);
    function requestDecentralPrincipal(uint256 projectId) external;
    function finalizeDecentralPrincipal(uint256 projectId) external returns (uint256);

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

interface IDecentralPoolLike {
    function minimumInvestmentAmount() external view returns (uint256);
    function maximumInvestmentAmount() external view returns (uint256);
    function paymentFrequencySeconds() external view returns (uint256);
    function minimumInvestmentPeriodSeconds() external view returns (uint256);

    function getYieldWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256, uint256, bool, bool);

    function getPrincipalWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256, uint256, uint256, bool, bool);

    function pendingRewards(uint256 tokenId) external view returns (uint256);
}

contract DecentralStrategyFacetBaseForkTest is Test {
    using Utils for address;

    address constant DECENTRAL_POOL =
        0x6fC42888f157A772968CaB5B95A4e42a38C07fD0;

    address constant OWNER = address(0x01);
    address constant YIELD_EXTRACTOR = address(0x04);
    address constant FUNDS_OPERATOR = address(0x05);

    uint256 constant PROJECT_ID = 1;

    IYelayLiteVault vault;
    IYelayLiteVaultAsync asyncVault;
    IDecentralStrategyFacet facet;
    IDecentralPoolLike pool;

    function setUp() external {
        string memory rpc = vm.envString("BASE_URL");
        require(bytes(rpc).length > 0, "set BASE_URL");
        vm.createSelectFork(rpc);

        pool = IDecentralPoolLike(DECENTRAL_POOL);

        vm.startPrank(OWNER);

        vault = Utils.deployDiamond(
                OWNER,
                BASE_USDC,
                YIELD_EXTRACTOR,
                "https://yelay-lite-vault/{id}.json"
            );

        Utils.upgradeToAsyncFundsFacet(vault);
        Utils.upgradeToDecentralStrategyFacet(vault);

        asyncVault = IYelayLiteVaultAsync(address(vault));        
        facet = IDecentralStrategyFacet(address(vault));

        asyncVault.grantRole(LibRoles.FUNDS_OPERATOR, FUNDS_OPERATOR);

        vm.stopPrank();
    }

function test_fork_decentralDeposit_USDC_success() external {
    uint256 minAmt = pool.minimumInvestmentAmount();
    uint256 maxAmt = pool.maximumInvestmentAmount();

    // Use pool minimum, fallback to 100 USDC
    uint256 amount =
        minAmt > 0 ? minAmt : 100 * 10 ** USDC_DECIMALS;

    if (amount > maxAmt) {
        amount = maxAmt;
    }

    // ------------------------------------------------------------
    // 1. USER deposits into the ASYNC VAULT (shares minted)
    // ------------------------------------------------------------
    address user = address(0xBEEF);
    deal(BASE_USDC, user, amount);

    vm.startPrank(user);
    IERC20(BASE_USDC).approve(address(asyncVault), amount);
    uint256 shares = asyncVault.deposit(amount, PROJECT_ID, user);
    vm.stopPrank();

    // Sanity checks: vault accounting
    assertGt(shares, 0);
    assertEq(asyncVault.balanceOf(user, PROJECT_ID), shares);
    assertApproxEqAbs(asyncVault.totalAssets(), amount, 1);
    assertEq(IERC20(BASE_USDC).balanceOf(address(asyncVault)), amount);

    // ------------------------------------------------------------
    // 2. FUNDS_OPERATOR allocates vault funds into Decentral
    // ------------------------------------------------------------
    vm.prank(FUNDS_OPERATOR);
    facet.decentralDeposit(PROJECT_ID, amount);

    // ------------------------------------------------------------
    // 3. Verify Decentral position was created
    // ------------------------------------------------------------
    (
        uint256 tokenId,
        uint256 principal,
        bool yieldRequested,
        bool principalRequested,
        bool closed
    ) = facet.decentralPosition(PROJECT_ID);

    assertGt(tokenId, 0);
    assertEq(principal, amount);
    assertFalse(yieldRequested);
    assertFalse(principalRequested);
    assertFalse(closed);

    // ------------------------------------------------------------
    // 4. Vault funds should now be allocated (not sitting idle)
    // ------------------------------------------------------------
    assertEq(IERC20(BASE_USDC).balanceOf(address(asyncVault)), 0);
}


// Flow for this test
// User deposits into async vault → gets shares
// Operator allocates funds from vault into Decentral
// User requests async withdrawal from vault (requestAsyncFunds)
// Operator requests principal withdrawal on Decentral
// Assert:
// - withdrawal request exists
// - not approved
// Operator tries to finalize on strategy → revert

    function test_fork_principalRequest_USDC_reverts_without_approval() external {
        uint256 minAmt = pool.minimumInvestmentAmount();
        uint256 maxAmt = pool.maximumInvestmentAmount();

        uint256 amount =
            minAmt > 0 ? minAmt : 100 * 10 ** USDC_DECIMALS;

        if (amount > maxAmt) {
            amount = maxAmt;
        }

        // ------------------------------------------------------------
        // 1. USER deposits into ASYNC VAULT (shares minted)
        // ------------------------------------------------------------
        address user = address(0xBEEF);
        deal(BASE_USDC, user, amount);

        vm.startPrank(user);
        IERC20(BASE_USDC).approve(address(asyncVault), amount);
        uint256 shares = asyncVault.deposit(amount, PROJECT_ID, user);
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(asyncVault.balanceOf(user, PROJECT_ID), shares);

        // ------------------------------------------------------------
        // 2. FUNDS_OPERATOR allocates vault funds into Decentral
        // ------------------------------------------------------------
        vm.prank(FUNDS_OPERATOR);
        facet.decentralDeposit(PROJECT_ID, amount);

        (uint256 tokenId,,,,) = facet.decentralPosition(PROJECT_ID);
        assertGt(tokenId, 0);

        // ------------------------------------------------------------
        // 3. USER requests async withdrawal from VAULT
        // ------------------------------------------------------------
        vm.startPrank(user);
        asyncVault.requestAsyncFunds(shares, PROJECT_ID, user);
        vm.stopPrank();

        // ------------------------------------------------------------
        // 4. Advance time beyond minimum investment period
        // ------------------------------------------------------------
        uint256 minPeriod = pool.minimumInvestmentPeriodSeconds();
        vm.warp(block.timestamp + minPeriod + 1);

        // ------------------------------------------------------------
        // 5. FUNDS_OPERATOR requests PRINCIPAL withdrawal on Decentral
        // ------------------------------------------------------------
        vm.prank(FUNDS_OPERATOR);
        facet.requestDecentralPrincipal(PROJECT_ID);

        (
            uint256 withdrawalAmount,
            uint256 requestTs,
            uint256 availableTs,
            bool exists,
            bool approved
        ) = pool.getPrincipalWithdrawalRequest(tokenId);

        assertTrue(exists);
        assertFalse(approved);
        assertGt(withdrawalAmount, 0);
        assertGt(requestTs, 0);
        assertGt(availableTs, 0);

        // ------------------------------------------------------------
        // 6. Finalizing on strategy must REVERT (not approved)
        // ------------------------------------------------------------
        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("PRINCIPAL WITHDRAWAL IS NOT READY"));
        facet.finalizeDecentralPrincipal(PROJECT_ID);

        // ------------------------------------------------------------
        // 7. Vault async request is still pending (NOT fulfilled)
        // ------------------------------------------------------------
        // Shares are still held by the vault
        assertEq(
            asyncVault.balanceOf(address(asyncVault), PROJECT_ID),
            shares
        );
    }


    function test_fork_yieldRequest_USDC_reverts_without_approval() external {
        uint256 amount = pool.minimumInvestmentAmount();

        // fund vault
        deal(BASE_USDC, address(vault), amount);

        // deposit into Decentral
        vm.prank(FUNDS_OPERATOR);
        facet.decentralDeposit(PROJECT_ID, amount);

        (uint256 tokenId,,,,) = facet.decentralPosition(PROJECT_ID);
        assertTrue(tokenId != 0);

        // move forward at least one full payment cycle
        uint256 freq = pool.paymentFrequencySeconds();
        vm.warp(block.timestamp + freq + 1);

        // --- IMPORTANT: assert real accrued yield ---
        uint256 pendingYield = pool.pendingRewards(tokenId);
        assertGt(pendingYield, 0, "yield should be accrued");

        // request yield withdrawal (creates request, but NOT approved)
        vm.prank(FUNDS_OPERATOR);
        facet.requestDecentralYield(PROJECT_ID);

        (
            uint256 withdrawalAmount,
            uint256 requestTs,
            bool exists,
            bool approved
        ) = pool.getYieldWithdrawalRequest(tokenId);

        assertTrue(exists);
        assertFalse(approved);
        assertEq(withdrawalAmount, pendingYield);

        // finalize should revert because NOT approved
        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("DECENTRAL_NOT_READY"));
        facet.finalizeDecentralYield(PROJECT_ID);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {IYelayLiteVaultAsync} from "src/interfaces/IYelayLiteVaultAsync.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {IDecentralPool} from "src/interfaces/external/decentral/IDecentralPool.sol";

import {Utils} from "../Utils.sol";
import {BASE_USDC, USDC_DECIMALS} from "../Constants.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StrategyArgs} from "src/interfaces/IFundsFacetBase.sol";

interface IDecentralStrategyFacet {

    function decentralDeposit(uint256 amount) external;
    function requestDecentralYield(uint256 index) external;
    function finalizeDecentralYield(uint256 index) external returns (uint256);
    function requestDecentralPrincipal(uint256 index) external;
    function finalizeDecentralPrincipal(uint256 index) external returns (uint256);

    function decentralPositions()
        external
        view
        returns (
            uint256[] memory tokenIds,
            bool[] memory yieldRequested,
            bool[] memory principalRequested,
            bool[] memory closed
        );

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
    IDecentralPool pool;

    function setUp() external {
        string memory rpc = vm.envString("BASE_URL");
        require(bytes(rpc).length > 0, "set BASE_URL");
        vm.createSelectFork(rpc);

        pool = IDecentralPool(DECENTRAL_POOL);

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
    assertEq(IERC20(BASE_USDC).balanceOf(address(asyncVault)), amount);


    // ------------------------------------------------------------
    // 2. FUNDS_OPERATOR allocates vault funds into Decentral
    // ------------------------------------------------------------
    vm.prank(FUNDS_OPERATOR);
    facet.decentralDeposit(amount);

    // ------------------------------------------------------------
    // 3. Verify Decentral position was created
    // ------------------------------------------------------------

    (
        uint256[] memory tokenIds,
        bool[] memory yieldRequested,
        bool[] memory principalRequested,
        bool[] memory closed
    ) = facet.decentralPositions();

    assertEq(tokenIds.length, 1);
    assertGt(tokenIds[0], 0);
    assertFalse(yieldRequested[0]);
    assertFalse(principalRequested[0]);
    assertFalse(closed[0]);


    // ------------------------------------------------------------
    // 4. Vault funds should now be allocated (not sitting idle)
    // ------------------------------------------------------------
    assertApproxEqAbs(asyncVault.totalAssets(), amount, 1);
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
        uint256 amount = pool.minimumInvestmentAmount();

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
        facet.decentralDeposit(amount);

        (
            uint256[] memory tokenIds,
            ,
            ,
            bool[] memory closed
        ) = facet.decentralPositions();

        uint256 tokenId = tokenIds[0];
        assertFalse(closed[0]);


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
        facet.requestDecentralPrincipal(0);

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

        vm.prank(0x2333Aa052610012C27E4fC176bc27095651DcBc6); // this is Decentral's admin address
        pool.approvePrincipalWithdrawal(tokenId);

        facet.finalizeDecentralPrincipal(0);

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

        deal(BASE_USDC, address(vault), amount);

        vm.prank(FUNDS_OPERATOR);
        facet.decentralDeposit(amount);

        (
            uint256[] memory tokenIds,
            ,
            ,
            bool[] memory closed
        ) = facet.decentralPositions();

        uint256 tokenId = tokenIds[0];
        assertFalse(closed[0]);

        vm.warp(block.timestamp + pool.paymentFrequencySeconds() + 1);
        uint256 pendingYield = pool.pendingRewards(tokenId);
        assertGt(pendingYield, 0);

        vm.prank(FUNDS_OPERATOR);
        facet.requestDecentralYield(0);

        (
            uint256 withdrawalAmount,
            ,
            bool exists,
            bool approved
        ) = pool.getYieldWithdrawalRequest(tokenId);

        assertTrue(exists);
        assertFalse(approved);
        assertEq(withdrawalAmount, pendingYield);

        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("DECENTRAL_NOT_READY"));
        facet.finalizeDecentralYield(0);
    }
}

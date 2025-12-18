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

import "forge-std/console2.sol";


interface IDecentralStrategyFacet {
    /// @notice Mirrors LibAsyncDecentral.NFTPosition
    struct NFTPosition {
        uint256 tokenId;
        bool yieldRequested;
        bool principalRequested;
        bool closed;
    }

    /// @notice Constant getter is exposed as a view function in the ABI
    function DECENTRAL_POOL() external view returns (address);

    // -------------------------
    // Write functions
    // -------------------------
    function decentralDeposit(uint256 amount) external;

    function requestDecentralYieldWithdrawal(uint256 index) external;

    function finalizeDecentralYieldWithdrawal(uint256 index)
        external
        returns (uint256 received);

    function requestDecentralPrincipalWithdrawal(uint256 index) external;

    function finalizeDecentralPrincipalWithdrawal(uint256 index)
        external
        returns (uint256 received);

    // -------------------------
    // Views
    // -------------------------
    function decentralPositions()
        external
        view
        returns (NFTPosition[] memory);

    function totalAssets() external view returns (uint256 assets);
}


contract DecentralStrategyFacetBaseForkTest is Test {
    using Utils for address;

    address constant DECENTRAL_POOL =
        0x6fC42888f157A772968CaB5B95A4e42a38C07fD0;

    address constant OWNER = address(0x01);
    address constant YIELD_EXTRACTOR = address(0x04);
    address constant FUNDS_OPERATOR = address(0x05);
    address constant DECENTRAL_APPROVER = address(0x2333Aa052610012C27E4fC176bc27095651DcBc6);

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
    console2.log("=== test_fork_decentralDeposit_USDC_success ===");

    uint256 minAmt = pool.minimumInvestmentAmount();
    uint256 maxAmt = pool.maximumInvestmentAmount();

    console2.log("pool.minimumInvestmentAmount:", minAmt);
    console2.log("pool.maximumInvestmentAmount:", maxAmt);

    // Use pool minimum, fallback to 100 USDC
    uint256 amount =
        minAmt > 0 ? minAmt : 100 * 10 ** USDC_DECIMALS;

    console2.log("initial chosen amount:", amount);

    if (amount > maxAmt) {
        console2.log("amount > maxAmt, clamping to maxAmt");
        amount = maxAmt;
    }

    console2.log("final deposit amount:", amount);

    // ------------------------------------------------------------
    // 1. USER deposits into the ASYNC VAULT (shares minted)
    // ------------------------------------------------------------
    address user = address(0x2345);
    console2.log("user:", user);

    deal(BASE_USDC, user, amount);
    console2.log(
        "user USDC balance after deal:",
        IERC20(BASE_USDC).balanceOf(user)
    );

    vm.startPrank(user);

    IERC20(BASE_USDC).approve(address(asyncVault), amount);
    console2.log("user approved asyncVault for amount:", amount);

    uint256 shares = asyncVault.deposit(amount, PROJECT_ID, user);
    console2.log("shares minted:", shares);

    vm.stopPrank();

    // Sanity checks: vault accounting
    console2.log("vault balanceOf(user, PROJECT_ID):",
    asyncVault.balanceOf(user, PROJECT_ID));
    console2.log("vault USDC balance:", IERC20(BASE_USDC).balanceOf(address(asyncVault))
    );

    IDecentralStrategyFacet.NFTPosition[] memory positions =
        facet.decentralPositions();

    console2.log("Before deposit to Decentral. decentralPositions.length:", positions.length);

    if (positions.length > 0) {
        console2.log("tokenId:", positions[0].tokenId);
        console2.log("yieldRequested:", positions[0].yieldRequested);
        console2.log("principalRequested:", positions[0].principalRequested);
        console2.log("closed:", positions[0].closed);
    }

    assertGt(shares, 0);
    assertEq(asyncVault.balanceOf(user, PROJECT_ID), shares);
    assertEq(IERC20(BASE_USDC).balanceOf(address(asyncVault)), amount);

    // ------------------------------------------------------------
    // 2. FUNDS_OPERATOR allocates vault funds into Decentral
    // ------------------------------------------------------------
    console2.log("FUNDS_OPERATOR:", FUNDS_OPERATOR);
    console2.log("calling decentralDeposit with amount:", amount);

    vm.prank(FUNDS_OPERATOR);
    facet.decentralDeposit(amount);

    console2.log("decentralDeposit executed");

    // ------------------------------------------------------------
    // 3. Verify Decentral position was created
    // ------------------------------------------------------------
    positions = facet.decentralPositions();

    console2.log("After deposit to Decentral. decentralPositions.length:", positions.length);

    if (positions.length > 0) {
        console2.log("tokenId:", positions[0].tokenId);
        console2.log("yieldRequested:", positions[0].yieldRequested);
        console2.log("principalRequested:", positions[0].principalRequested);
        console2.log("closed:", positions[0].closed);
    }

    assertEq(positions.length, 1);
    assertGt(positions[0].tokenId, 0);
    assertFalse(positions[0].yieldRequested);
    assertFalse(positions[0].principalRequested);
    assertFalse(positions[0].closed);

    console2.log("decentralPositions.length:", positions.length);

    if (positions.length > 0) {
        console2.log("tokenIds[0]:", positions[0].tokenId);
        console2.log("yieldRequested[0]:", positions[0].yieldRequested);
        console2.log("principalRequested[0]:", positions[0].principalRequested);
        console2.log("closed[0]:", positions[0].closed);
    }

    assertEq(positions.length, 1);
    assertGt(positions[0].tokenId, 0);
    assertFalse(positions[0].yieldRequested);
    assertFalse(positions[0].principalRequested);
    assertFalse(positions[0].closed);

    // ------------------------------------------------------------
    // 4. Vault funds should now be allocated (not sitting idle)
    // ------------------------------------------------------------
    uint256 totalAssets = asyncVault.totalAssets();
    uint256 newVaultBalance = IERC20(BASE_USDC).balanceOf(address(asyncVault));

    console2.log("asyncVault.totalAssets():", totalAssets);
    console2.log("vault USDC balance after allocation:", newVaultBalance);

    assertApproxEqAbs(totalAssets, amount, 1);
    assertEq(newVaultBalance, 0);

    console2.log("=== test completed successfully ===");
}



// User deposits into async vault → gets shares
// Operator allocates funds from vault into Decentral
// User requests async withdrawal from vault (requestAsyncFunds)
// Operator requests principal withdrawal on Decentral
// Approver approves principal withdrawal
// Operator tries to finalize on strategy → success


function test_fork_principal_request_finalization_success() external {
    console2.log("=== test_fork_principal_request_finalization_success ===");

    uint256 amount = pool.minimumInvestmentAmount();
    console2.log("deposit amount:", amount);

    // ------------------------------------------------------------
    // 1. USER deposits into ASYNC VAULT (shares minted)
    // ------------------------------------------------------------
    address user = address(0xFEED);
    console2.log("user:", user);

    deal(BASE_USDC, user, amount);
    console2.log(
        "user USDC balance after deal:",
        IERC20(BASE_USDC).balanceOf(user)
    );

    vm.startPrank(user);
    IERC20(BASE_USDC).approve(address(asyncVault), amount);
    uint256 shares = asyncVault.deposit(amount, PROJECT_ID, user);
    vm.stopPrank();

    console2.log("shares minted:", shares);
    console2.log(
        "vault balanceOf(user, PROJECT_ID):",
        asyncVault.balanceOf(user, PROJECT_ID)
    );

    assertGt(shares, 0);
    assertEq(asyncVault.balanceOf(user, PROJECT_ID), shares);

    // ------------------------------------------------------------
    // 2. FUNDS_OPERATOR allocates vault funds into Decentral
    // ------------------------------------------------------------
    console2.log("FUNDS_OPERATOR:", FUNDS_OPERATOR);

    vm.prank(FUNDS_OPERATOR);
    facet.decentralDeposit(amount);

    console2.log("decentralDeposit executed");

    IDecentralStrategyFacet.NFTPosition[] memory positions =
        facet.decentralPositions();

    console2.log("decentralPositions.length:", positions.length);
    assertEq(positions.length, 1);

    uint256 tokenId = positions[0].tokenId;

    console2.log("tokenId:", tokenId);
    console2.log("closed:", positions[0].closed);
    console2.log("principalRequested:", positions[0].principalRequested);

    assertFalse(positions[0].closed);
    assertFalse(positions[0].principalRequested);

    // ------------------------------------------------------------
    // 3. Advance time beyond minimum investment period
    // ------------------------------------------------------------
    uint256 minPeriod = pool.minimumInvestmentPeriodSeconds();
    console2.log("minimumInvestmentPeriodSeconds:", minPeriod);

    // move 120 days from now to be sure that request will be approved. 
    vm.warp(block.timestamp + (minPeriod * 2 ));
    console2.log("time warped to:", block.timestamp);


    // ------------------------------------------------------------
    // 4. USER requests async withdrawal from VAULT
    // ------------------------------------------------------------
    console2.log("user requests async withdrawal from vault");

    vm.startPrank(user);
    asyncVault.requestAsyncFunds(shares, PROJECT_ID, user);
    vm.stopPrank();


    // ------------------------------------------------------------
    // 5. FUNDS_OPERATOR requests PRINCIPAL withdrawal on Decentral
    // ------------------------------------------------------------
    console2.log("requesting principal withdrawal on Decentral");

    vm.prank(FUNDS_OPERATOR);
    // pass position nr to withdraw. the logic to calculate which exactly position to withdraw and in what amount should be on the FE/SDK side.
    facet.requestDecentralPrincipalWithdrawal(0);

    // ------------------------------------------------------------
    // 6. Approver approves & FUNDS_OPERATOR finalizes withdrawal
    // ------------------------------------------------------------

    console2.log("approving principal withdrawal");

    vm.prank(DECENTRAL_APPROVER); // Approval by Decentral admin
    pool.approvePrincipalWithdrawal(tokenId);

    positions = facet.decentralPositions();
    console2.log(
        "principalRequested flag after request:",
        positions[0].principalRequested
    );

    assertTrue(positions[0].principalRequested);

    (
        uint256 withdrawalAmount,
        uint256 requestTs,
        uint256 availableTs,
        bool exists,
        bool approved
    ) = pool.getPrincipalWithdrawalRequest(tokenId);

    console2.log("withdrawalAmount:", withdrawalAmount);
    console2.log("requestTs:", requestTs);
    console2.log("availableTs:", availableTs);
    console2.log("exists:", exists);
    console2.log("approved:", approved);

    assertTrue(exists);
    assertTrue(approved);
 
    // ------------------------------------------------------------
    // 7. FUNDS_OPERATOR finalizes withdrawal
    // ------------------------------------------------------------

    console2.log("finalizing principal withdrawal via strategy");

    // move 2 hours ahead in order to pass withdrawal delay
    vm.warp(block.timestamp + (60 * 2 * 60));

    vm.prank(FUNDS_OPERATOR);
    uint256 received = facet.finalizeDecentralPrincipalWithdrawal(0);

    console2.log("principal received:", received);
    assertGt(received, 0);

    // ------------------------------------------------------------
    // 8. Position + vault post-conditions
    // ------------------------------------------------------------


    positions = facet.decentralPositions();

    console2.log("position.closed:", positions[0].closed);
    console2.log(
        "position.principalRequested:",
        positions[0].principalRequested
    );

    assertFalse(positions[0].principalRequested);
    // closed may be true or false depending on partial vs full redemption

    console2.log(
        "vault USDC balance after finalize:",
        IERC20(BASE_USDC).balanceOf(address(asyncVault))
    );

    console2.log(
        "vault async shares still escrowed:",
        asyncVault.balanceOf(address(asyncVault), PROJECT_ID)
    );

    assertEq(
        asyncVault.balanceOf(address(asyncVault), PROJECT_ID),
        shares
    );

    console2.log("=== test completed successfully ===");

    // Money is now back in the vault. The last step is to execute withdrawal from the vault
}


/*
    function test_fork_yield_request_finalization_success() external {
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
        facet.requestDecentralYieldWithdrawal(0);

        (
            uint256 withdrawalAmount,
            ,
            bool exists,
            bool approved
        ) = pool.getYieldWithdrawalRequest(0);

        assertTrue(exists);
        assertFalse(approved);
        assertEq(withdrawalAmount, pendingYield);

        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("DECENTRAL_NOT_READY"));
        facet.finalizeDecentralYieldWithdrawal(0);
    } */
}

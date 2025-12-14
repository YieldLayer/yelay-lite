// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";

import {Utils} from "../Utils.sol";
import {BASE_USDC, USDC_DECIMALS} from "../Constants.sol";

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

        Utils.upgradeToDecentralStrategyFacet(vault);
        facet = IDecentralStrategyFacet(address(vault));

        vault.grantRole(LibRoles.FUNDS_OPERATOR, FUNDS_OPERATOR);

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

        deal(BASE_USDC, address(vault), amount);

        vm.prank(FUNDS_OPERATOR);
        facet.decentralDeposit(PROJECT_ID, amount);

        (uint256 tokenId, uint256 principal,,,) =
            facet.decentralPosition(PROJECT_ID);

        assertGt(tokenId, 0);
        assertEq(principal, amount);
    }

    function test_fork_yieldRequest_USDC_reverts_without_approval() external {
        uint256 amount = pool.minimumInvestmentAmount();
        deal(BASE_USDC, address(vault), amount);

        vm.prank(FUNDS_OPERATOR);
        facet.decentralDeposit(PROJECT_ID, amount);

        (uint256 tokenId,,,,) = facet.decentralPosition(PROJECT_ID);

        uint256 freq = pool.paymentFrequencySeconds();
        vm.warp(block.timestamp + freq + 7 days);

        vm.prank(FUNDS_OPERATOR);
        facet.requestDecentralYield(PROJECT_ID);

        (,, bool exists, bool approved) =
            pool.getYieldWithdrawalRequest(tokenId);

        assertTrue(exists);
        assertEq(approved, false);

        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("DECENTRAL_NOT_READY"));
        facet.finalizeDecentralYield(PROJECT_ID);
    }

    function test_fork_principalRequest_USDC_reverts_without_approval() external {
        uint256 amount = pool.minimumInvestmentAmount();
        deal(BASE_USDC, address(vault), amount);

        vm.prank(FUNDS_OPERATOR);
        facet.decentralDeposit(PROJECT_ID, amount);

        (uint256 tokenId,,,,) = facet.decentralPosition(PROJECT_ID);

        uint256 minPeriod = pool.minimumInvestmentPeriodSeconds();
        vm.warp(block.timestamp + minPeriod + 1);

        vm.prank(FUNDS_OPERATOR);
        facet.requestDecentralPrincipal(PROJECT_ID);

        vm.prank(FUNDS_OPERATOR);
        vm.expectRevert(bytes("DECENTRAL_NOT_READY"));
        facet.finalizeDecentralPrincipal(PROJECT_ID);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockDecentralPool {
    ERC20 public immutable stable;

    uint256 public nextTokenId = 1;

    struct Position {
        uint256 principal;
        uint256 yieldAccrued;
        bool principalRequested;
        bool yieldRequested;
        bool principalApproved;
        bool yieldApproved;
    }

    mapping(uint256 => Position) public positions;

    constructor(address stable_) {
        stable = ERC20(stable_);
    }

    function deposit(uint256 amount) external returns (uint256 tokenId) {
        stable.transferFrom(msg.sender, address(this), amount);

        tokenId = nextTokenId++;
        positions[tokenId].principal = amount;
        positions[tokenId].yieldAccrued = amount / 10; // 10% yield
    }

    /* ===================== YIELD ===================== */

    function requestYieldWithdrawal(uint256 tokenId) external {
        positions[tokenId].yieldRequested = true;
        positions[tokenId].yieldApproved = true;
    }

    function executeYieldWithdrawal(uint256 tokenId) external {
        Position storage p = positions[tokenId];
        uint256 amt = p.yieldAccrued;
        p.yieldAccrued = 0;
        stable.transfer(msg.sender, amt);
    }

    function getYieldWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256 amount, uint256, bool exists, bool approved)
    {
        Position storage p = positions[tokenId];
        return (p.yieldAccrued, block.timestamp, p.yieldRequested, p.yieldApproved);
    }

    function pendingRewards(uint256 tokenId) external view returns (uint256) {
        return positions[tokenId].yieldAccrued;
    }

    /* =================== PRINCIPAL =================== */

    function requestPrincipalWithdrawal(uint256 tokenId) external {
        positions[tokenId].principalRequested = true;
        positions[tokenId].principalApproved = true;
    }

    function executePrincipalWithdrawal(uint256 tokenId) external {
        Position storage p = positions[tokenId];
        uint256 amt = p.principal;
        p.principal = 0;
        stable.transfer(msg.sender, amt);
    }

    function getPrincipalWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256 amount, uint256, uint256, bool exists, bool approved)
    {
        Position storage p = positions[tokenId];
        return (p.principal, block.timestamp, block.timestamp, p.principalRequested, p.principalApproved);
    }

    function stablecoinAddress() external view returns (address) {
        return address(stable);
    }
}

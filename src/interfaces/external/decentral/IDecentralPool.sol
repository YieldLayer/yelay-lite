// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IDecentralPool {
    function deposit(uint256 amount) external returns (uint256 tokenId);

    function requestYieldWithdrawal(uint256 tokenId) external;
    function executeYieldWithdrawal(uint256 tokenId) external;

    function requestPrincipalWithdrawal(uint256 tokenId) external;
    function executePrincipalWithdrawal(uint256 tokenId) external;

    function getYieldWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256 amount, uint256 requestTimestamp, bool exists, bool approved);

    function getPrincipalWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256 amount, uint256 requestTimestamp, uint256 availableTimestamp, bool exists, bool approved);

    function stablecoinAddress() external view returns (address);

    function pendingRewards(uint256 tokenId) external view returns (uint256);

    function poolToken() external view returns (address);

    function approveYieldWithdrawal(uint256 tokenId) external;
    function batchApproveYieldWithdrawals(uint256[] calldata tokenIds) external;
    function approvePrincipalWithdrawal(uint256 tokenId) external;
    function batchApprovePrincipalWithdrawals(uint256[] calldata tokenIds) external;

    function minimumInvestmentAmount() external view returns (uint256);
    function maximumInvestmentAmount() external view returns (uint256);
    function paymentFrequencySeconds() external view returns (uint256);
    function minimumInvestmentPeriodSeconds() external view returns (uint256);
}

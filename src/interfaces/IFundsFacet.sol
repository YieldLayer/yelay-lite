// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

struct StrategyArgs {
    uint256 index;
    uint256 amount;
}

interface IFundsFacet {
    function accrueFee() external;
    function deposit(uint256 assets, uint256 projectId, address receiver) external returns (uint256 shares);
    function lastTotalAssets() external view returns (uint256);
    function managedDeposit(StrategyArgs memory strategyArgs) external;
    function managedWithdraw(StrategyArgs memory strategyArgs) external;
    function reallocate(StrategyArgs[] memory withdrawals, StrategyArgs[] memory deposits) external;
    function redeem(uint256 shares, uint256 projectId, address receiver) external;
    function strategyAssets(uint256 index) external view returns (uint256);
    function totalAssets() external view returns (uint256 assets);
    function underlyingAsset() external view returns (address);
    function underlyingBalance() external view returns (uint256);
    function yieldExtractor() external view returns (address);
}

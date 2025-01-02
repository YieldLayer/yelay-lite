// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {Reward} from "./IStrategyBase.sol";
import {SwapArgs} from "./ISwapper.sol";

struct StrategyArgs {
    uint256 index;
    uint256 amount;
}

interface IFundsFacet is IERC1155, IERC1155MetadataURI {
    function accrueFee() external;
    function deposit(uint256 assets, uint256 projectId, address receiver) external returns (uint256 shares);
    function lastTotalAssets() external view returns (uint256);
    function managedDeposit(StrategyArgs memory strategyArgs) external;
    function managedWithdraw(StrategyArgs memory strategyArgs) external;
    function reallocate(StrategyArgs[] memory withdrawals, StrategyArgs[] memory deposits) external;
    function redeem(uint256 shares, uint256 projectId, address receiver) external returns (uint256 assets);
    function strategyAssets(uint256 index) external view returns (uint256);
    function totalAssets() external view returns (uint256 assets);
    function underlyingAsset() external view returns (address);
    function underlyingBalance() external view returns (uint256);
    function yieldExtractor() external view returns (address);
    function strategyRewards(uint256 index) external returns (Reward[] memory rewards);
    function claimStrategyRewards(uint256 index) external;
    function swapper() external view returns (address);
    function compound(SwapArgs[] memory swapArgs) external returns (uint256 compounded);
    function migratePosition(uint256 fromProjectId, uint256 toProjectId, uint256 amount) external;
    function totalSupply() external view returns (uint256);
    function totalSupply(uint256 id) external view returns (uint256);
    function lastTotalAssetsTimestamp() external view returns (uint64);
    function lastTotalAssetsUpdateInterval() external view returns (uint64);
    function setLastTotalAssetsUpdateInterval(uint64 interval) external;
}

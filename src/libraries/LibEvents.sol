// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibEvents {
    // FundsFacet
    event Deposit(
        uint256 indexed projectId, address indexed sender, address indexed receiver, uint256 assets, uint256 shares
    );
    event Redeem(
        uint256 indexed projectId, address indexed sender, address indexed receiver, uint256 assets, uint256 shares
    );
    event ManagedDeposit(address indexed strategy, uint256 amount);
    event ManagedWithdraw(address indexed strategy, uint256 amount);
    event AccrueInterest(uint256 newTotalAssets, uint256 interest, uint256 feeShares);
    event UpdateLastTotalAssets(uint256 lastTotalAssets);
    event Compounded(uint256 amount);
    event PositionMigrated(address account, uint256 fromProjectId, uint256 toProjectId, uint256 shares);

    // ManagementFacet
    event UpdateDepositQueue();
    event UpdateWithdrawQueue();
    event AddStrategy(address strategy, bytes supplement);
    event RemoveStrategy(address strategy, bytes supplement);

    // ProjectsFacet
    event NewProjectIds(address owner, uint256 min, uint256 max);
    event OwnershipTransferProjectIds(address owner, uint256 min, uint256 max);
    event ProjectActivated(uint256 project);
    event ProjectOptionSet(uint256 projectId, uint256 option);
    event LockConfigSet(uint256 projectId, uint256 duration);
}

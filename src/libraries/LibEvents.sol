// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// how come events are defined in a library?
// instead of them being defined
// - on the facets themselves
// - or just in a file

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
    event PositionMigrated(address indexed account, uint256 indexed fromProjectId, uint256 indexed toProjectId, uint256 shares);

    // ManagementFacet
    event UpdateDepositQueue();
    event UpdateWithdrawQueue();
    event AddStrategy(address indexed strategy, bytes supplement);
    event RemoveStrategy(address indexed strategy, bytes supplement);

    // ClientsFacet
    event NewProjectIds(address indexed owner, uint256 minProjectId, uint256 maxProjectId);
    event OwnershipTransferProjectIds(address indexed oldOwner, address indexed newOwner, uint256 minProjectId, uint256 maxProjectId);
    event ProjectActivated(uint256 indexed project, bytes32 indexed clientName);

    // OwnerFacet
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event SelectorToFacetSet(bytes4 indexed selector, address indexed facet);
}

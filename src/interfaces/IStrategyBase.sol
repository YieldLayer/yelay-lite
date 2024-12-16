// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

struct Reward {
    address token;
    uint256 amount;
}

interface IStrategyBase {
    function protocol() external returns (address);
    function deposit(uint256 amount, bytes calldata supplement) external;
    function withdraw(uint256 amount, bytes calldata supplement) external;
    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view returns (uint256);
    function onAdd(bytes calldata supplement) external;
    function onRemove(bytes calldata supplement) external;
    function viewRewards(address yelayLiteVault, bytes calldata supplement)
        external
        view
        returns (Reward[] memory rewards);
    function claimRewards(bytes calldata supplement) external;
}

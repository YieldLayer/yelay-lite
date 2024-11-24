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

    // TODO: support rewards
    // function viewRewards(address asset, bytes calldata  supplement) external returns (Reward[] memory rewards);
    // function claimRewards(address asset, Reward[] memory rewards, bytes calldata  supplement) external;
}

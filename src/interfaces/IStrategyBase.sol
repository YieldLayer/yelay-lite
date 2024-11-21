// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IStrategyBase {
    function strategy() external returns (address);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function assetBalance(address vault) external view returns (uint256);

    function viewRewards() external returns (address[] memory tokens, uint256[] memory amounts);
    function claimRewards() external;

    function onAdd() external;
    function onRemove() external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

struct StrategyData {
    address adapter;
    // for instance Morpho requires bytes32 market id
    // aave3 aToken address
    bytes supplement;
}

interface IManagementFacet {
    function addStrategy(StrategyData memory strategy) external;
    function getDepositQueue() external view returns (uint256[] memory);
    function getStrategies() external view returns (StrategyData[] memory);
    function getWithdrawQueue() external view returns (uint256[] memory);
    function removeStrategy(uint256 index) external;
    function updateDepositQueue(uint256[] memory depositQueue_) external;
    function updateWithdrawQueue(uint256[] memory withdrawQueue_) external;
}

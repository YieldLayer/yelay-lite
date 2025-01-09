// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct StrategyData {
    address adapter;
    // for instance Morpho requires bytes32 market id
    // aave3 aToken address
    bytes supplement;
}

interface IManagementFacet {
    /**
     * @dev Returns the list of strategies.
     * @return The list of strategies.
     */
    function getStrategies() external view returns (StrategyData[] memory);

    /**
     * @dev Returns the deposit queue.
     * @return The deposit queue.
     */
    function getDepositQueue() external view returns (uint256[] memory);

    /**
     * @dev Returns the withdraw queue.
     * @return The withdraw queue.
     */
    function getWithdrawQueue() external view returns (uint256[] memory);

    /**
     * @dev Updates the deposit queue.
     * @param depositQueue_ The new deposit queue.
     */
    function updateDepositQueue(uint256[] calldata depositQueue_) external;

    /**
     * @dev Updates the withdraw queue.
     * @param withdrawQueue_ The new withdraw queue.
     */
    function updateWithdrawQueue(uint256[] calldata withdrawQueue_) external;

    /**
     * @dev Adds a new strategy.
     * @param strategy The strategy data.
     */
    function addStrategy(
        StrategyData calldata strategy,
        uint256[] calldata depositQueue_,
        uint256[] calldata withdrawQueue_
    ) external;

    /**
     * @dev Removes a strategy.
     * @param index The index of the strategy to remove.
     */
    function removeStrategy(uint256 index, uint256[] calldata depositQueue_, uint256[] calldata withdrawQueue_)
        external;

    /**
     * @dev Function to approve spending of underlying asset by the strategy.
     * @param index The index of the strategy.
     * @param amount The amount to approve.
     */
    function approveStrategy(uint256 index, uint256 amount) external;
}

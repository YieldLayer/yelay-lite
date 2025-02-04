// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct StrategyData {
    // the address of the strategy adapter
    address adapter;
    // the name of the strategy
    bytes32 name;
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
     * @dev Returns the list of active strategies used for investment.
     * @return The list of active strategies.
     */
    function getActiveStrategies() external view returns (StrategyData[] memory);

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
     * @dev Callable by QUEUES_OPERATOR.
     * @param depositQueue_ The new deposit queue.
     */
    function updateDepositQueue(uint256[] calldata depositQueue_) external;

    /**
     * @dev Updates the withdraw queue.
     * @dev Callable by QUEUES_OPERATOR.
     * @param withdrawQueue_ The new withdraw queue.
     */
    function updateWithdrawQueue(uint256[] calldata withdrawQueue_) external;

    /**
     * @dev Adds a new strategy.
     * @dev Callable by STRATEGY_AUTHORITY.
     * @param strategy The strategy data.
     */
    function addStrategy(StrategyData calldata strategy) external;

    /**
     * @dev Removes a strategy.
     * @dev Callable by STRATEGY_AUTHORITY.
     * @param index The index of the strategy to remove.
     */
    function removeStrategy(uint256 index) external;

    /**
     * @dev Activate strategy for active investing.
     * @dev Callable by QUEUES_OPERATOR.
     * @param index The index of registered strategy.
     * @param depositQueue_ The new deposit queue.
     * @param withdrawQueue_ The new withdraw queue.
     */
    function activateStrategy(uint256 index, uint256[] calldata depositQueue_, uint256[] calldata withdrawQueue_)
        external;

    /**
     * @dev Deactivate strategy, stop investing in it.
     * @dev Callable by QUEUES_OPERATOR.
     * @param index The index of active strategy.
     * @param depositQueue_ The new deposit queue.
     * @param withdrawQueue_ The new withdraw queue.
     */
    function deactivateStrategy(uint256 index, uint256[] calldata depositQueue_, uint256[] calldata withdrawQueue_)
        external;

    /**
     * @dev Function to approve spending of underlying asset by the strategy.
     * @dev Callable by STRATEGY_AUTHORITY.
     * @param index The index of the strategy.
     * @param amount The amount to approve.
     */
    function approveStrategy(uint256 index, uint256 amount) external;
}

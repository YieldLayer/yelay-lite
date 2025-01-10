// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

struct Reward {
    address token;
    uint256 amount;
}

interface IStrategyBase {
    /**
     * @dev Returns the address of the protocol.
     * @return The address of the protocol.
     */
    function protocol() external returns (address);

    /**
     * @dev Deposits the specified amount into the strategy.
     * @param amount The amount to deposit.
     * @param supplement Additional data required for the deposit.
     */
    function deposit(uint256 amount, bytes calldata supplement) external;

    /**
     * @dev Withdraws the specified amount from the strategy.
     * @param amount The amount to withdraw.
     * @param supplement Additional data required for the withdrawal.
     * @return withdrawn The actual amount withdrawn.
     */
    function withdraw(uint256 amount, bytes calldata supplement) external returns (uint256 withdrawn);

    /**
     * @dev Returns the asset balance of the strategy for the specified vault.
     * @param yelayLiteVault The address of the vault.
     * @param supplement Additional data required for the balance calculation.
     * @return The asset balance of the strategy.
     */
    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view returns (uint256);

    /**
     * @dev Called when the strategy is added.
     * @param supplement Additional data required for the addition.
     */
    function onAdd(bytes calldata supplement) external;

    /**
     * @dev Called when the strategy is removed.
     * @param supplement Additional data required for the removal.
     */
    function onRemove(bytes calldata supplement) external;

    /**
     * @dev Returns the rewards available for the specified vault.
     * @param yelayLiteVault The address of the vault.
     * @param supplement Additional data required for the rewards calculation.
     * @return rewards The rewards available for the vault.
     */
    function viewRewards(address yelayLiteVault, bytes calldata supplement)
        external
        view
        returns (Reward[] memory rewards);

    /**
     * @dev Claims the rewards for the strategy.
     * @param supplement Additional data required for claiming the rewards.
     */
    function claimRewards(bytes calldata supplement) external;
}

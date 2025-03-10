// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFarmingPool is IERC20 {
    event DistributorChanged(address oldDistributor, address newDistributor);
    event RewardUpdated(uint256 reward, uint256 duration);

    // View functions
    function distributor() external view returns (address);
    function stakingToken() external view returns (address);
    function rewardsToken() external view returns (address);
    function farmed(address account) external view returns (uint256);

    // User functions
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claim() external;
    function exit() external;

    // Owner functions
    function setDistributor(address distributor_) external;

    // Distributor functions
    function startFarming(uint256 amount, uint256 period) external;
    function rescueFunds(IERC20 token, uint256 amount) external;
}

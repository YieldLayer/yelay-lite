// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";

contract MockStrategy is IStrategyBase {
    address mockProtocol;

    constructor(address mockProtocol_) {
        mockProtocol = mockProtocol_;
    }

    function protocol() external view returns (address) {
        return mockProtocol;
    }

    function deposit(uint256 amount) external {}

    function withdraw(uint256 amount) external {}

    function assetBalance(address vault) external view returns (uint256) {}

    function onAdd() external {}

    function onRemove() external {}

    function claimRewards() external {}

    function viewRewards() external returns (address[] memory tokens, uint256[] memory amounts) {}
}

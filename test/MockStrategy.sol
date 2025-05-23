// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";

contract MockStrategy is IStrategyBase {
    address mockProtocol;

    constructor(address mockProtocol_) {
        mockProtocol = mockProtocol_;
    }

    function protocol(bytes calldata) external view returns (address) {
        return mockProtocol;
    }

    function deposit(uint256 amount, bytes calldata supplement) external {}
    function withdraw(uint256 amount, bytes calldata supplement) external returns (uint256) {}
    function withdrawAll(bytes calldata supplement) external returns (uint256) {}
    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view returns (uint256) {}
    function onAdd(bytes calldata supplement) external {}
    function onRemove(bytes calldata supplement) external {}
    function viewRewards(address, bytes calldata supplement) external view returns (Reward[] memory rewards) {}
    function claimRewards(bytes calldata supplement) external {}
}

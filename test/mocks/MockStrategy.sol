// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";

contract MockStrategy is IStrategyBase {
    address mockProtocol;
    IERC20 asset;

    uint256 _assetBalance;
    uint256 _toWithdraw;

    constructor(address mockProtocol_, address asset_) {
        mockProtocol = mockProtocol_;
        asset = IERC20(asset_);
    }

    function setAssetBalance(uint256 value) external {
        _assetBalance = value;
    }

    function setWithdraw(uint256 value) external {
        _toWithdraw = value;
    }

    function protocol(bytes calldata) external view returns (address) {
        return mockProtocol;
    }

    function deposit(uint256 amount, bytes calldata supplement) external {}

    function withdraw(uint256 amount, bytes calldata supplement) external returns (uint256) {
        asset.transfer(msg.sender, _toWithdraw);
        return _toWithdraw;
    }

    function withdrawAll(bytes calldata supplement) external returns (uint256) {
        asset.transfer(msg.sender, _toWithdraw);
        return _toWithdraw;
    }

    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view returns (uint256) {
        return _assetBalance;
    }

    function onAdd(bytes calldata supplement) external {}
    function onRemove(bytes calldata supplement) external {}
    function viewRewards(address, bytes calldata supplement) external view returns (Reward[] memory rewards) {}
    function claimRewards(bytes calldata supplement) external {}
}

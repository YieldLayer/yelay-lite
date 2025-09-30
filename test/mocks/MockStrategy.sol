// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";

contract MockProtocol {
    address public asset;
    uint256 public assetBalance;
    uint256 public toWithdraw;

    constructor(address asset_) {
        asset = asset_;
    }

    function setAssetBalance(uint256 value) external {
        assetBalance = value;
    }

    function setWithdraw(uint256 value) external {
        toWithdraw = value;
    }

    function deposit(uint256 amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external returns (uint256) {
        IERC20(asset).transfer(msg.sender, toWithdraw > 0 ? toWithdraw : amount);
        return toWithdraw;
    }
}

contract MockStrategy is IStrategyBase {
    MockProtocol mockProtocol;

    constructor(address mockProtocol_) {
        mockProtocol = MockProtocol(mockProtocol_);
    }

    function protocol(bytes calldata) external view returns (address) {
        return address(mockProtocol);
    }

    function deposit(uint256 amount, bytes calldata) external {
        mockProtocol.deposit(amount);
    }

    function withdraw(uint256 amount, bytes calldata) external returns (uint256) {
        return mockProtocol.withdraw(amount);
    }

    function withdrawAll(bytes calldata) external returns (uint256) {}

    function assetBalance(address, bytes calldata) external view returns (uint256) {
        return mockProtocol.assetBalance();
    }

    function onAdd(bytes calldata) external {}
    function onRemove(bytes calldata) external {}
    function viewRewards(address, bytes calldata) external view returns (Reward[] memory rewards) {}
    function claimRewards(bytes calldata) external {}
}

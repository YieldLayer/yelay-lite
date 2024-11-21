// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IPool} from "src/interfaces/external/aave/v3/IPool.sol";
import {IAToken} from "src/interfaces/external/aave/v3/IAToken.sol";
import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";

contract AaveV3Strategy is IStrategyBase {
    IPool immutable pool;
    address public immutable asset;
    IAToken public immutable aToken;

    constructor(address pool_, address asset_, address aToken_) {
        pool = IPool(pool_);
        asset = asset_;
        aToken = IAToken(aToken_);
    }

    function strategy() external view returns (address) {
        return address(pool);
    }

    function deposit(uint256 amount) external {
        pool.supply(asset, amount, address(this), 0);
    }

    function withdraw(uint256 amount) external {
        pool.withdraw(asset, amount, address(this));
    }

    function assetBalance(address vault) external view returns (uint256) {
        return aToken.balanceOf(address(vault));
    }

    function onAdd() external {}
    function onRemove() external {}
    function claimRewards() external {}
    function viewRewards() external returns (address[] memory tokens, uint256[] memory amounts) {}
}

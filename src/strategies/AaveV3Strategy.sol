// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";

import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";

contract AaveV3Strategy is IStrategyBase {
    IPool immutable pool;

    constructor(address pool_) {
        pool = IPool(pool_);
    }

    function _decodeSupplement(bytes calldata supplement) internal pure returns (address token, IAToken aToken) {
        return abi.decode(supplement, (address, IAToken));
    }

    function protocol() external view returns (address) {
        return address(pool);
    }

    function deposit(uint256 amount, bytes calldata supplement) external {
        (address asset,) = _decodeSupplement(supplement);
        pool.supply(asset, amount, address(this), 0);
    }

    function withdraw(uint256 amount, bytes calldata supplement) external {
        (address asset,) = _decodeSupplement(supplement);
        pool.withdraw(asset, amount, address(this));
    }

    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view returns (uint256) {
        (, IAToken aToken) = _decodeSupplement(supplement);
        return aToken.balanceOf(address(yelayLiteVault));
    }

    function onAdd(bytes calldata supplement) external {
        (address asset, IAToken aToken) = _decodeSupplement(supplement);
        IERC20(asset).approve(address(pool), type(uint256).max);
        aToken.approve(address(pool), type(uint256).max);
    }

    function onRemove(bytes calldata supplement) external {
        (address asset, IAToken aToken) = _decodeSupplement(supplement);
        IERC20(asset).approve(address(pool), 0);
        aToken.approve(address(pool), 0);
    }

    // function claimRewards() external {}
    // function viewRewards() external returns (address[] memory tokens, uint256[] memory amounts) {}
}

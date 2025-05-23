// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IAToken} from "@aave-v3-core/interfaces/IAToken.sol";

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";

contract AaveV3Strategy is IStrategyBase {
    IPool immutable pool;

    constructor(address pool_) {
        pool = IPool(pool_);
    }

    function _decodeSupplement(bytes calldata supplement) internal pure returns (address token, IAToken aToken) {
        return abi.decode(supplement, (address, IAToken));
    }

    function protocol(bytes calldata) external view returns (address) {
        return address(pool);
    }

    function deposit(uint256 amount, bytes calldata supplement) external {
        (address asset,) = _decodeSupplement(supplement);
        pool.supply(asset, amount, address(this), 0);
    }

    function withdraw(uint256 amount, bytes calldata supplement) external returns (uint256 withdrawn) {
        (address asset,) = _decodeSupplement(supplement);
        withdrawn = pool.withdraw(asset, amount, address(this));
    }

    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view returns (uint256) {
        (, IAToken aToken) = _decodeSupplement(supplement);
        return aToken.balanceOf(address(yelayLiteVault));
    }

    function withdrawAll(bytes calldata supplement) external returns (uint256 withdrawn) {
        (address asset, IAToken aToken) = _decodeSupplement(supplement);
        withdrawn = pool.withdraw(asset, aToken.balanceOf(address(this)), address(this));
    }

    function onAdd(bytes calldata supplement) external {}
    function onRemove(bytes calldata supplement) external {}
    function viewRewards(address, bytes calldata) external view returns (Reward[] memory rewards) {}
    function claimRewards(bytes calldata) external {}
}

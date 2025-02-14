// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {Id, IMorpho, MarketParams, Position} from "@morpho-blue/interfaces/IMorpho.sol";

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MorphoBlueStrategy is IStrategyBase {
    IMorpho immutable morpho;

    constructor(address morpho_) {
        morpho = IMorpho(morpho_);
    }

    function _decodeSupplement(bytes calldata supplement) internal pure returns (Id id) {
        return abi.decode(supplement, (Id));
    }

    function protocol() external view returns (address) {
        return address(morpho);
    }

    function deposit(uint256 amount, bytes calldata supplement) external {
        Id id = _decodeSupplement(supplement);
        MarketParams memory marketParams = morpho.idToMarketParams(id);
        morpho.supply(marketParams, amount, 0, address(this), "");
    }

    function withdraw(uint256 amount, bytes calldata supplement) external returns (uint256 withdrawn) {
        Id id = _decodeSupplement(supplement);
        MarketParams memory marketParams = morpho.idToMarketParams(id);
        (withdrawn,) = morpho.withdraw(marketParams, amount, 0, address(this), address(this));
    }

    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view returns (uint256) {
        Id id = _decodeSupplement(supplement);
        MarketParams memory marketParams = morpho.idToMarketParams(id);
        return MorphoBalancesLib.expectedSupplyAssets(morpho, marketParams, yelayLiteVault);
    }

    function withdrawAll(bytes calldata supplement) external returns (uint256 withdrawn) {
        Id id = _decodeSupplement(supplement);
        Position memory position = morpho.position(id, address(this));
        (withdrawn,) =
            morpho.withdraw(morpho.idToMarketParams(id), 0, position.supplyShares, address(this), address(this));
    }

    function onAdd(bytes calldata supplement) external {}
    function onRemove(bytes calldata supplement) external {}
    function viewRewards(address, bytes calldata) external view returns (Reward[] memory rewards) {}
    function claimRewards(bytes calldata) external {}
}

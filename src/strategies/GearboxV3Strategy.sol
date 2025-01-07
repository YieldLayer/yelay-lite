// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC4626Strategy, Reward} from "src/strategies/ERC4626Strategy.sol";
import {IFarmingPool} from "src/interfaces/external/gearbox/v3/IFarmingPool.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GearboxV3Strategy is ERC4626Strategy {
    constructor(address dToken_) ERC4626Strategy(dToken_) {}

    function _decodeSupplement(bytes calldata supplement)
        internal
        pure
        returns (IFarmingPool sdToken, IERC20 gearToken)
    {
        return abi.decode(supplement, (IFarmingPool, IERC20));
    }

    function deposit(uint256 amount, bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        uint256 shares = super._deposit(amount);
        sdToken.deposit(shares);
    }

    function withdraw(uint256 amount, bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        uint256 shares = vault.previewWithdraw(amount);
        sdToken.withdraw(shares);
        super._withdraw(amount);
    }

    function assetBalance(address spoolLiteVault, bytes calldata supplement) external view override returns (uint256) {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        // dToken and sdToken are equivalent in value
        return vault.previewRedeem(sdToken.balanceOf(address(spoolLiteVault)));
    }

    function viewRewards(address spoolLiteVault, bytes calldata supplement)
        external
        view
        override
        returns (Reward[] memory)
    {
        (IFarmingPool sdToken, IERC20 gearToken) = _decodeSupplement(supplement);
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = Reward({token: address(gearToken), amount: sdToken.farmed(spoolLiteVault)});
        return rewards;
    }

    function claimRewards(bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        sdToken.claim();
    }

    function onAdd(bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        vault.approve(address(sdToken), type(uint256).max);
    }

    function onRemove(bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        vault.approve(address(sdToken), 0);
    }
}

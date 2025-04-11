// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";
import {IFarmingPool} from "src/interfaces/external/gearbox/v3/IFarmingPool.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GearboxV3Strategy is IStrategyBase {
    IERC4626 immutable vault;

    constructor(address vault_) {
        vault = IERC4626(vault_);
    }

    function _decodeSupplement(bytes calldata supplement)
        internal
        pure
        returns (IFarmingPool sdToken, IERC20 gearToken)
    {
        return abi.decode(supplement, (IFarmingPool, IERC20));
    }

    function protocol(bytes calldata) external view virtual returns (address) {
        return address(vault);
    }

    function deposit(uint256 amount, bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        uint256 shares = vault.deposit(amount, address(this));
        sdToken.deposit(shares);
    }

    function withdraw(uint256 amount, bytes calldata supplement) external override returns (uint256 withdrawn) {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        uint256 shares = vault.previewWithdraw(amount);
        sdToken.withdraw(shares);
        withdrawn = vault.redeem(shares, address(this), address(this));
    }

    function withdrawAll(bytes calldata supplement) external override returns (uint256 withdrawn) {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        sdToken.withdraw(sdToken.balanceOf(address(this)));
        withdrawn = vault.redeem(vault.balanceOf(address(this)), address(this), address(this));
    }

    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view override returns (uint256) {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        // dToken and sdToken are equivalent in value
        return vault.previewRedeem(sdToken.balanceOf(address(yelayLiteVault)));
    }

    function onAdd(bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        vault.approve(address(sdToken), type(uint256).max);
    }

    function onRemove(bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        vault.approve(address(sdToken), 0);
    }

    function viewRewards(address yelayLiteVault, bytes calldata supplement)
        external
        view
        override
        returns (Reward[] memory)
    {
        (IFarmingPool sdToken, IERC20 gearToken) = _decodeSupplement(supplement);
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = Reward({token: address(gearToken), amount: sdToken.farmed(yelayLiteVault)});
        return rewards;
    }

    function claimRewards(bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        sdToken.claim();
    }
}

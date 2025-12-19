// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";
import {IFarmingPool} from "src/interfaces/external/gearbox/v3/IFarmingPool.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GearboxV3Strategy is IStrategyBase {
    address immutable gearToken;

    constructor(address gearToken_) {
        gearToken = gearToken_;
    }

    function _decodeSupplement(bytes calldata supplement)
        internal
        pure
        returns (IERC4626 vault, IFarmingPool sdToken)
    {
        return abi.decode(supplement, (IERC4626, IFarmingPool));
    }

    function protocol(bytes calldata supplement) external view virtual returns (address) {
        (IERC4626 vault,) = _decodeSupplement(supplement);
        return address(vault);
    }

    function deposit(uint256 amount, bytes calldata supplement) external override {
        (IERC4626 vault, IFarmingPool sdToken) = _decodeSupplement(supplement);
        uint256 shares = vault.deposit(amount, address(this));
        sdToken.deposit(shares);
    }

    function withdraw(uint256 amount, bytes calldata supplement) external override returns (uint256 withdrawn) {
        (IERC4626 vault, IFarmingPool sdToken) = _decodeSupplement(supplement);
        uint256 shares = vault.previewWithdraw(amount);
        withdrawn = _withdraw(vault, sdToken, shares);
    }

    function withdrawAll(bytes calldata supplement) external override returns (uint256 withdrawn) {
        (IERC4626 vault, IFarmingPool sdToken) = _decodeSupplement(supplement);
        uint256 amount = sdToken.balanceOf(address(this));
        withdrawn = _withdraw(vault, sdToken, amount);
    }

    function _withdraw(IERC4626 vault, IFarmingPool sdToken, uint256 amount) internal returns (uint256 withdrawn) {
        sdToken.withdraw(amount);
        withdrawn = vault.redeem(amount, address(this), address(this));
    }

    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view override returns (uint256) {
        (IERC4626 vault, IFarmingPool sdToken) = _decodeSupplement(supplement);
        // dToken and sdToken are equivalent in value
        return vault.previewRedeem(sdToken.balanceOf(address(yelayLiteVault)));
    }

    function onAdd(bytes calldata supplement) external override {
        (IERC4626 vault, IFarmingPool sdToken) = _decodeSupplement(supplement);
        vault.approve(address(sdToken), type(uint256).max);
    }

    function onRemove(bytes calldata supplement) external override {
        (IERC4626 vault, IFarmingPool sdToken) = _decodeSupplement(supplement);
        vault.approve(address(sdToken), 0);
    }

    function viewRewards(address yelayLiteVault, bytes calldata supplement)
        external
        view
        override
        returns (Reward[] memory)
    {
        (, IFarmingPool sdToken) = _decodeSupplement(supplement);
        Reward[] memory rewards = new Reward[](1);
        rewards[0] = Reward({token: gearToken, amount: sdToken.farmed(yelayLiteVault)});
        return rewards;
    }

    function claimRewards(bytes calldata supplement) external override {
        (, IFarmingPool sdToken) = _decodeSupplement(supplement);
        sdToken.claim();
    }
}

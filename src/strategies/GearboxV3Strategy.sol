// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";
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
        // TODO: double check this logic is correct
        // dToken and sdToken are equivalent in value
        uint256 shares = vault.previewWithdraw(amount);
        sdToken.withdraw(shares);
        super._withdraw(amount);
    }

    function assetBalance(address spoolLiteVault, bytes calldata supplement) external view override returns (uint256) {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        // dToken and sdToken are equivalent in value
        return vault.previewRedeem(sdToken.balanceOf(address(spoolLiteVault)));
    }

    // function viewRewards() external override returns (address[] memory tokens, uint256[] memory amounts) {
    //     tokens = new address[](1);
    //     amounts = new uint256[](1);
    //     tokens[0] = address(gearToken);
    //     claimRewards();
    //     amounts[0] = gearToken.balanceOf(address(this));
    //     return (tokens, amounts);
    // }

    // function claimRewards() public override {
    //     sdToken.claim();
    // }

    function onAdd(bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        vault.approve(address(sdToken), type(uint256).max);
    }

    function onRemove(bytes calldata supplement) external override {
        (IFarmingPool sdToken,) = _decodeSupplement(supplement);
        vault.approve(address(sdToken), 0);
    }
}

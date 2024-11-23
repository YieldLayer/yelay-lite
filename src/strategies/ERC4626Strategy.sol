// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";

contract ERC4626Strategy is IStrategyBase {
    IERC4626 immutable vault;

    constructor(address vault_) {
        vault = IERC4626(vault_);
    }

    function protocol() external view virtual returns (address) {
        return address(vault);
    }

    function deposit(uint256 amount, bytes calldata) external virtual {
        _deposit(amount);
    }

    function _deposit(uint256 amount) internal returns (uint256 shares) {
        return vault.deposit(amount, address(this));
    }

    function withdraw(uint256 amount, bytes calldata) external virtual {
        _withdraw(amount);
    }

    function _withdraw(uint256 amount) internal returns (uint256 shares) {
        return vault.withdraw(amount, address(this), address(this));
    }

    function assetBalance(address spoolLiteVault, bytes calldata) external view virtual returns (uint256) {
        return vault.previewRedeem(vault.balanceOf(address(spoolLiteVault)));
    }

    function onAdd(bytes calldata) external virtual {}
    function onRemove(bytes calldata) external virtual {}
}

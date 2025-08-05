// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";
import {ITranche} from "src/interfaces/external/arcadia/ITranche.sol";

contract ArcadiaStrategy is IStrategyBase {
    function _decodeSupplement(bytes calldata supplement) internal pure returns (IERC4626 vault) {
        return abi.decode(supplement, (IERC4626));
    }

    function protocol(bytes calldata supplement) external virtual returns (address) {
        IERC4626 vault = _decodeSupplement(supplement);
        return ITranche(address(vault)).LENDING_POOL();
    }

    function deposit(uint256 amount, bytes calldata supplement) external virtual {
        IERC4626 vault = _decodeSupplement(supplement);
        vault.deposit(amount, address(this));
    }

    function withdraw(uint256 amount, bytes calldata supplement) external virtual returns (uint256 withdrawn) {
        IERC4626 vault = _decodeSupplement(supplement);
        uint256 shares = vault.previewWithdraw(amount);
        withdrawn = vault.redeem(shares, address(this), address(this));
    }

    function assetBalance(address yelayLiteVault, bytes calldata supplement) external view virtual returns (uint256) {
        IERC4626 vault = _decodeSupplement(supplement);
        return vault.previewRedeem(vault.balanceOf(address(yelayLiteVault)));
    }

    function withdrawAll(bytes calldata supplement) external virtual returns (uint256 withdrawn) {
        IERC4626 vault = _decodeSupplement(supplement);
        withdrawn = vault.redeem(vault.balanceOf(address(this)), address(this), address(this));
    }

    function onAdd(bytes calldata) external virtual {}
    function onRemove(bytes calldata) external virtual {}
    function viewRewards(address, bytes calldata) external view virtual returns (Reward[] memory rewards) {}
    function claimRewards(bytes calldata) external virtual {}
}

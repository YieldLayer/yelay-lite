// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AbstractYieldExtractorMigration} from "./AbstractYieldExtractorMigration.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

contract MainnetYieldExtractorMigrationTest is AbstractYieldExtractorMigration {

    function _setupFork() internal override {
        vm.createSelectFork(vm.envString("MAINNET_URL"), 22331639);

        IYelayLiteVault usdcVault = IYelayLiteVault(0x39DAc87bE293DC855b60feDd89667364865378cc);
        IYelayLiteVault wethVault = IYelayLiteVault(0x4d95E929ABb21b6C6C0FF1ff0Ac69609e02BB368);
        IYelayLiteVault wbtcVault = IYelayLiteVault(0x6545e81356CE709823EA8797E566A60934A9B110);
        vaults.push(usdcVault);
        vaults.push(wethVault);
        vaults.push(wbtcVault);
    }
}

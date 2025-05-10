// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AbstractYieldExtractorMigration} from "./AbstractYieldExtractorMigration.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

contract BaseTestingYieldExtractorMigrationTest is AbstractYieldExtractorMigration {
    function _setupFork() internal override {
        vm.createSelectFork(vm.envString("BASE_URL"), 29312933);

        testingDeployerAddress = 0x1892e547F4E1bA76F82a09C16C9F774744De1ff3;

        IYelayLiteVault usdcVault = IYelayLiteVault(0x7b3D25c37c6ADf650F1f7696be2278cCFa2b638F);
        IYelayLiteVault wethVault = IYelayLiteVault(0x1f463353feA78e38568499Cf117437493d334eCf);
        vaults.push(usdcVault);
        vaults.push(wethVault);
    }
}

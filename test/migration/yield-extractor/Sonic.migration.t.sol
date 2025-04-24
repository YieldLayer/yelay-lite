// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AbstractYieldExtractorMigration} from "./AbstractYieldExtractorMigration.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

contract SonicYieldExtractorMigrationTest is AbstractYieldExtractorMigration {
    function _setupFork() internal override {
        vm.createSelectFork(vm.envString("SONIC_URL"), 21772669);

        IYelayLiteVault usdcVault = IYelayLiteVault(0x56b0c5C989C65e712463278976ED26D6e07592ab);
        IYelayLiteVault wethVault = IYelayLiteVault(0xAB865D95A574511a6c893C38A4D892275ca70570);
        IYelayLiteVault wsVault = IYelayLiteVault(0x6880bb001417f123f824c573A07a991e0cD00daC);
        vaults.push(usdcVault);
        vaults.push(wethVault);
        vaults.push(wsVault);
    }
}

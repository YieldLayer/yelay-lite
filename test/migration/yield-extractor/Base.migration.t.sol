// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import {AbstractYieldExtractorMigration} from "./AbstractYieldExtractorMigration.sol";
// import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";

// contract BaseYieldExtractorMigrationTest is AbstractYieldExtractorMigration {
//     function _setupFork() internal override {
//         vm.createSelectFork(vm.envString("BASE_URL"), 29312933);

//         IYelayLiteVault usdcVault = IYelayLiteVault(0x0c6dAf9B4e0EB49A0c80c325da82EC028Cb8118B);
//         IYelayLiteVault wethVault = IYelayLiteVault(0xf0533A9eb11b144aC3B9BbE134728D0F7F547c52);
//         vaults.push(usdcVault);
//         vaults.push(wethVault);
//     }
// }

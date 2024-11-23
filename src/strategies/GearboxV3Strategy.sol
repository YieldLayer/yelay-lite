// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.28;

// import {ERC4626Strategy} from "src/strategies/ERC4626Strategy.sol";
// import {IFarmingPool} from "src/interfaces/external/gearbox/v3/IFarmingPool.sol";

// import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// contract GearboxV3Strategy is ERC4626Strategy {
//     using Address for address;

//     IFarmingPool immutable sdToken;
//     IERC20 immutable gearToken;

//     constructor(address dToken_, address sdToken_, address gearToken_) ERC4626Strategy(dToken_) {
//         sdToken = IFarmingPool(sdToken_);
//         gearToken = IERC20(gearToken_);
//     }

//     function deposit(uint256 amount) external override {
//         uint256 shares = super._deposit(amount);
//         sdToken.deposit(shares);
//     }

//     function withdraw(uint256 amount) external override {
//         // TODO: double check this logic is correct
//         uint256 shares = vault.previewWithdraw(amount);
//         // dToken and sdToken are equivalent in value
//         sdToken.withdraw(shares);
//         super._withdraw(amount);
//     }

//     function assetBalance(address spoolLiteVault) external view override returns (uint256) {
//         // dToken and sdToken are equivalent in value
//         return vault.previewRedeem(sdToken.balanceOf(address(spoolLiteVault)));
//     }

//     function viewRewards() external override returns (address[] memory tokens, uint256[] memory amounts) {
//         tokens = new address[](1);
//         amounts = new uint256[](1);
//         tokens[0] = address(gearToken);
//         claimRewards();
//         amounts[0] = gearToken.balanceOf(address(this));
//         return (tokens, amounts);
//     }

//     function claimRewards() public override {
//         sdToken.claim();
//     }

//     function onAdd() external override {
//         vault.approve(address(sdToken), type(uint256).max);
//     }

//     function onRemove() external override {
//         vault.approve(address(sdToken), 0);
//     }
// }

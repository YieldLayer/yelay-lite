// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {IMerklDistributor} from "src/interfaces/external/merkl/IMerklDistributor.sol";

import {FundsFacetBase} from "src/facets/FundsFacetBase.sol";
import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {IFundsFacetBase} from "src/interfaces/IFundsFacetBase.sol";
import {LibFunds} from "src/libraries/LibFunds.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

/**
 * @title FundsFacet
 * @dev Contract that manages funds, including deposits, withdrawals, reallocation, compounding etc.
 */
contract FundsFacet is FundsFacetBase, IFundsFacet {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    constructor(ISwapper swapper_, IMerklDistributor merklDistributor_) FundsFacetBase(swapper_, merklDistributor_) {}

    /// @inheritdoc IFundsFacet
    function redeem(uint256 shares, uint256 projectId, address receiver) external notPaused returns (uint256 assets) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        uint256 newTotalAssets = _mintFee(sF);

        assets = _convertToAssets(shares, totalSupply(), newTotalAssets);
        require(assets > WITHDRAW_MARGIN, LibErrors.MinRedeem());

        _updateLastTotalAssets(sF, newTotalAssets.zeroFloorSub(assets));

        uint256 withdrawn;
        for (uint256 i; i < sM.withdrawQueue.length; i++) {
            uint256 toWithdraw = assets - withdrawn;
            if (toWithdraw <= WITHDRAW_MARGIN) break;
            uint256 assetBalance = IStrategyBase(sM.activeStrategies[sM.withdrawQueue[i]].adapter).assetBalance(
                address(this), sM.activeStrategies[sM.withdrawQueue[i]].supplement
            );
            if (assetBalance == 0) continue;
            uint256 availableToWithdraw = FixedPointMathLib.min(assetBalance, toWithdraw);
            (bool success, bytes memory result) = sM.activeStrategies[sM.withdrawQueue[i]].adapter.delegatecall(
                abi.encodeWithSelector(
                    IStrategyBase.withdraw.selector,
                    availableToWithdraw,
                    sM.activeStrategies[sM.withdrawQueue[i]].supplement
                )
            );
            if (success) {
                withdrawn += SafeCast.toUint192(abi.decode(result, (uint256)));
            }
        }
        sF.underlyingBalance += SafeCast.toUint192(withdrawn);
        uint256 lack = assets.zeroFloorSub(withdrawn);
        // if withdrawal is almost covered by strategies (except WITHDRAW_MARGIN difference) - use what is withdrawn
        // otherwise what is calculated in _convertToAssets
        assets = lack > WITHDRAW_MARGIN ? assets : assets - lack;
        // ensure we have enough funds in vault
        require(sF.underlyingBalance + WITHDRAW_MARGIN >= assets, LibErrors.NotEnoughInternalFunds());
        // normalize for the last withdrawal - we already know that they are close together
        assets = FixedPointMathLib.min(sF.underlyingBalance, assets);
        sF.underlyingBalance -= SafeCast.toUint192(assets);
        sF.underlyingAsset.safeTransfer(receiver, assets);
        _burn(msg.sender, projectId, shares);

        emit LibEvents.Redeem(projectId, msg.sender, receiver, assets, shares);
    }

    function totalSupply() public view override(FundsFacetBase, IFundsFacetBase) returns (uint256) {
        return super.totalSupply();
    }

    function totalSupply(uint256 id) public view override(FundsFacetBase, IFundsFacetBase) returns (uint256) {
        return super.totalSupply(id);
    }
}

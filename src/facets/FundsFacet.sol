// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/utils/Address.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";

import {TokenFacet} from "src/facets/TokenFacet.sol";
import {SelfOnly} from "src/abstract/SelfOnly.sol";
import {LibFunds} from "src/libraries/LibFunds.sol";
import {LibToken} from "src/libraries/LibToken.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";

import {console} from "forge-std/console.sol";

// TODO: add access control
contract FundsFacet is SelfOnly {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    error NotEnoughAssets();
    error NotEnoughLiquidity();
    // error CapReached();
    // error InconsistentLength();
    // error InconsistentReallocation();
    // error StrategyExists();
    // error OnlyView();
    // error CompoundFailure();

    function deposit(uint256 assets, uint256 projectId, address receiver) external allowSelf returns (uint256 shares) {
        LibFunds.FundsStorage storage sF = LibFunds.getStorage();
        LibManagement.ManagementStorage memory sM = LibManagement.getStorage();

        uint256 newTotalAssets = totalAssets();
        _accrueFee(sF, newTotalAssets);

        shares = _convertToSharesWithTotals(assets, LibToken.totalSupply(), newTotalAssets);

        sF.underlyingAsset.safeTransferFrom(msg.sender, address(this), assets);
        address(this).functionDelegateCall(
            abi.encodeWithSelector(TokenFacet.mint.selector, receiver, projectId, shares)
        );
        for (uint256 i; i < sM.depositQueue.length; i++) {
            (bool success,) = sM.strategies[sM.depositQueue[i]].adapter.delegatecall(
                abi.encodeWithSelector(
                    IStrategyBase.deposit.selector, assets, sM.strategies[sM.depositQueue[i]].supplement
                )
            );
            if (success) {
                break;
            }
        }
        _updateLastTotalAssets(sF, newTotalAssets + assets);
    }

    function redeem(uint256 shares, uint256 projectId, address receiver) external allowSelf {
        LibFunds.FundsStorage storage sF = LibFunds.getStorage();
        LibManagement.ManagementStorage memory sM = LibManagement.getStorage();

        uint256 newTotalAssets = totalAssets();
        _accrueFee(sF, newTotalAssets);

        uint256 assets = _convertToAssetsWithTotals(shares, LibToken.totalSupply(), newTotalAssets);

        _updateLastTotalAssets(sF, newTotalAssets.zeroFloorSub(assets));

        uint256 _assets = assets;
        for (uint256 i; i < sM.withdrawQueue.length; i++) {
            if (_assets == 0) break;
            address adapter = sM.strategies[sM.withdrawQueue[i]].adapter;
            bytes memory supplement = sM.strategies[sM.withdrawQueue[i]].supplement;
            // TODO: create smarter method to get precise amount able to be withdrawn
            uint256 assetBalance = IStrategyBase(adapter).assetBalance(address(this), supplement);
            if (assetBalance == 0) continue;
            uint256 availableToWithdraw = FixedPointMathLib.min(assetBalance, _assets);
            (bool success,) = adapter.delegatecall(
                abi.encodeWithSelector(IStrategyBase.withdraw.selector, availableToWithdraw, supplement)
            );
            if (success) {
                _assets -= availableToWithdraw;
            }
        }
        sF.underlyingAsset.safeTransfer(receiver, assets);
        address(this).functionDelegateCall(
            abi.encodeWithSelector(TokenFacet.burn.selector, msg.sender, projectId, shares)
        );
    }

    function totalAssets() public view returns (uint256 assets) {
        LibFunds.FundsStorage memory sF = LibFunds.getStorage();
        LibManagement.ManagementStorage memory sM = LibManagement.getStorage();

        assets = sF.underlyingAsset.balanceOf(address(this));
        // TODO: we need to use strategies storage
        for (uint256 i; i < sM.strategies.length; ++i) {
            assets += IStrategyBase(sM.strategies[i].adapter).assetBalance(address(this), sM.strategies[i].supplement);
        }
    }

    function _accrueFee(LibFunds.FundsStorage memory sF, uint256 newTotalAssets) internal {
        uint256 totalInterest = newTotalAssets.zeroFloorSub(sF.lastTotalAssets);
        if (totalInterest > 0) {
            uint256 feeShares = _convertToSharesWithTotals(totalInterest, LibToken.totalSupply(), sF.lastTotalAssets);
            if (feeShares > 0) {
                address(this).functionDelegateCall(
                    // TODO: yield with projectId 0 ?
                    abi.encodeWithSelector(TokenFacet.mint.selector, sF.yieldExtractor, 0, feeShares)
                );
            }
        }

        // TODO: events
        // emit EventsLib.AccrueInterest(newTotalAssets, feeShares);
    }

    /// @dev Updates `lastTotalAssets` to `updatedTotalAssets`.
    function _updateLastTotalAssets(LibFunds.FundsStorage storage sF, uint256 updatedTotalAssets) internal {
        sF.lastTotalAssets = updatedTotalAssets;

        // TODO: add event
        // emit EventsLib.UpdateLastTotalAssets(updatedTotalAssets);
    }

    function _convertToSharesWithTotals(uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        // TODO: support _decimalOffset => prevent inflation attack
        return newTotalSupply == 0 ? assets : assets.mulDiv(newTotalSupply, newTotalAssets);
    }

    function _convertToAssetsWithTotals(uint256 shares, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        // TODO: support _decimalOffset => prevent inflation attack
        return shares.mulDiv(newTotalAssets, newTotalSupply);
    }
}

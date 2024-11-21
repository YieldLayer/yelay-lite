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

contract FundsFacet is SelfOnly {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    error NotEnoughAssets();
    // error CapReached();
    // error InconsistentLength();
    // error InconsistentReallocation();
    // error StrategyExists();
    // error OnlyView();
    // error CompoundFailure();

    function deposit(uint256 assets, address receiver) external allowSelf returns (uint256 shares) {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();
        uint256 newTotalAssets = _accrueFee(s);

        shares = _convertToSharesWithTotals(assets, LibToken.totalSupply(), newTotalAssets);

        s.underlyingAsset.safeTransferFrom(msg.sender, address(this), assets);
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.mint.selector, receiver, shares));
        for (uint256 i; i < s.depositQueue.length; i++) {
            (bool success,) = s.depositQueue[i].delegatecall(abi.encodeCall(IStrategyBase.deposit, (assets)));
            if (success) {
                break;
            }
        }
        _updateLastTotalAssets(s, s.lastTotalAssets + assets);
    }

    function redeem(uint256 shares, address receiver) external allowSelf {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();
        uint256 newTotalAssets = _accrueFee(s);

        uint256 assets = _convertToAssetsWithTotals(shares, LibToken.totalSupply(), newTotalAssets);

        _updateLastTotalAssets(s, newTotalAssets.zeroFloorSub(assets));

        for (uint256 i; i < s.withdrawQueue.length; i++) {
            if (assets == 0) break;
            // TODO: create smarter method to get precise amount able to be withdrawn
            uint256 assetBalance = IStrategyBase(s.withdrawQueue[i]).assetBalance(address(this));
            if (assetBalance == 0) continue;
            uint256 availableToWithdraw = FixedPointMathLib.min(assetBalance, assets);
            assets -= availableToWithdraw;
            s.withdrawQueue[i].functionDelegateCall(abi.encodeCall(IStrategyBase.withdraw, (assets)));
        }
        if (assets > 0) revert NotEnoughAssets();
        s.underlyingAsset.safeTransfer(receiver, assets);
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.burn.selector, msg.sender, shares));
    }

    function totalAssets() public view returns (uint256 assets) {
        LibFunds.FundsStorage memory s = LibFunds._getFundsStorage();
        assets = s.underlyingAsset.balanceOf(address(this));
        for (uint256 i; i < s.strategies.length; ++i) {
            assets += IStrategyBase(s.strategies[i]).assetBalance(address(this));
        }
    }

    function _accrueFee(LibFunds.FundsStorage memory s) internal returns (uint256 newTotalAssets) {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares(s);

        if (feeShares != 0) {
            address(this).functionDelegateCall(
                abi.encodeWithSelector(TokenFacet.mint.selector, s.yieldExtractor, feeShares)
            );
        }
        // TODO: events
        // emit EventsLib.AccrueInterest(newTotalAssets, feeShares);
    }

    function _accruedFeeShares(LibFunds.FundsStorage memory s)
        internal
        view
        returns (uint256 feeShares, uint256 newTotalAssets)
    {
        newTotalAssets = totalAssets();
        uint256 totalInterest = newTotalAssets.zeroFloorSub(s.lastTotalAssets);
        if (totalInterest != 0) {
            feeShares =
                _convertToSharesWithTotals(totalInterest, LibToken.totalSupply(), newTotalAssets - totalInterest);
        }
    }

    /// @dev Updates `lastTotalAssets` to `updatedTotalAssets`.
    function _updateLastTotalAssets(LibFunds.FundsStorage storage s, uint256 updatedTotalAssets) internal {
        s.lastTotalAssets = updatedTotalAssets;

        // TODO: add event
        // emit EventsLib.UpdateLastTotalAssets(updatedTotalAssets);
    }

    function _convertToSharesWithTotals(uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        // TODO: support _decimalOffset
        return assets.mulDiv(newTotalSupply + 1, newTotalAssets + 1);
    }

    function _convertToAssetsWithTotals(uint256 shares, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        view
        returns (uint256)
    {
        // TODO: support _decimalOffset
        return shares.mulDiv(newTotalAssets + 1, newTotalSupply + 1);
    }
}

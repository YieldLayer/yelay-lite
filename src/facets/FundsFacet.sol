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

import {console} from "forge-std/console.sol";

// TODO: add access control
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

    function getDepositQueue() external view returns (address[] memory) {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();
        return s.depositQueue;
    }

    function updateDepositQueue(address[] calldata depositQueue_) external {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();
        // TODO: improve
        for (uint256 i; i < s.depositQueue.length; i++) {
            IStrategyBase(s.depositQueue[i]).onRemove();
            s.depositQueue[i].functionDelegateCall(abi.encodeWithSelector(IStrategyBase.onRemove.selector));
        }
        s.depositQueue = depositQueue_;
        // TODO: improve
        for (uint256 i; i < s.depositQueue.length; i++) {
            s.depositQueue[i].functionDelegateCall(abi.encodeWithSelector(IStrategyBase.onAdd.selector));
        }
    }

    function getWithdrawQueue() external view returns (address[] memory) {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();
        return s.withdrawQueue;
    }

    function updateWithdrawQueue(address[] calldata withdrawQueue_) external {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();
        s.withdrawQueue = withdrawQueue_;
    }

    function deposit(uint256 assets, address receiver) external allowSelf returns (uint256 shares) {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();

        uint256 newTotalAssets = totalAssets();
        _accrueFee(s, newTotalAssets);

        shares = _convertToSharesWithTotals(assets, LibToken.totalSupply(), newTotalAssets);

        s.underlyingAsset.safeTransferFrom(msg.sender, address(this), assets);
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.mint.selector, receiver, shares));
        for (uint256 i; i < s.depositQueue.length; i++) {
            (bool success,) = s.depositQueue[i].delegatecall(abi.encodeCall(IStrategyBase.deposit, (assets)));
            if (success) {
                break;
            }
        }
        _updateLastTotalAssets(s, newTotalAssets + assets);
    }

    function redeem(uint256 shares, address receiver) external allowSelf {
        LibFunds.FundsStorage storage s = LibFunds._getFundsStorage();

        uint256 newTotalAssets = totalAssets();
        _accrueFee(s, newTotalAssets);

        uint256 assets = _convertToAssetsWithTotals(shares, LibToken.totalSupply(), newTotalAssets);

        _updateLastTotalAssets(s, newTotalAssets.zeroFloorSub(assets));

        uint256 _assets = assets;
        for (uint256 i; i < s.withdrawQueue.length; i++) {
            if (_assets == 0) break;
            // TODO: create smarter method to get precise amount able to be withdrawn
            uint256 assetBalance = IStrategyBase(s.withdrawQueue[i]).assetBalance(address(this));
            if (assetBalance == 0) continue;
            uint256 availableToWithdraw = FixedPointMathLib.min(assetBalance, _assets);
            _assets -= availableToWithdraw;
            s.withdrawQueue[i].functionDelegateCall(abi.encodeCall(IStrategyBase.withdraw, (availableToWithdraw)));
        }
        s.underlyingAsset.safeTransfer(receiver, assets);
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.burn.selector, msg.sender, shares));
    }

    function totalAssets() public view returns (uint256 assets) {
        LibFunds.FundsStorage memory s = LibFunds._getFundsStorage();
        assets = s.underlyingAsset.balanceOf(address(this));
        for (uint256 i; i < s.depositQueue.length; ++i) {
            assets += IStrategyBase(s.depositQueue[i]).assetBalance(address(this));
        }
    }

    function _accrueFee(LibFunds.FundsStorage memory s, uint256 newTotalAssets) internal {
        uint256 totalInterest = newTotalAssets.zeroFloorSub(s.lastTotalAssets);
        if (totalInterest > 0) {
            uint256 feeShares = _convertToSharesWithTotals(totalInterest, LibToken.totalSupply(), s.lastTotalAssets);
            if (feeShares > 0) {
                address(this).functionDelegateCall(
                    abi.encodeWithSelector(TokenFacet.mint.selector, s.yieldExtractor, feeShares)
                );
            }
        }

        // TODO: events
        // emit EventsLib.AccrueInterest(newTotalAssets, feeShares);
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
        return newTotalSupply == 0 ? assets : assets.mulDiv(newTotalSupply, newTotalAssets);
    }

    function _convertToAssetsWithTotals(uint256 shares, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        // TODO: support _decimalOffset
        return shares.mulDiv(newTotalAssets, newTotalSupply);
    }
}

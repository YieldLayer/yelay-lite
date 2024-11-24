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

import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";

import {console} from "forge-std/console.sol";

contract FundsFacet is SelfOnly, IFundsFacet {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 constant YIELD_PROJECT_ID = 0;

    error NotEnoughAssets();
    error NotEnoughLiquidity();
    // error CapReached();
    // error InconsistentLength();
    // error InconsistentReallocation();
    // error StrategyExists();
    // error OnlyView();
    // error CompoundFailure();

    function deposit(uint256 assets, uint256 projectId, address receiver) external allowSelf returns (uint256 shares) {
        (LibFunds.FundsStorage storage sF, uint256 newTotalAssets) = _accrueFee();
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        shares = _convertToSharesWithTotals(assets, LibToken.totalSupply(), newTotalAssets);

        sF.underlyingAsset.safeTransferFrom(msg.sender, address(this), assets);
        address(this).functionDelegateCall(
            abi.encodeWithSelector(TokenFacet.mint.selector, receiver, projectId, shares)
        );
        bool success;
        for (uint256 i; i < sM.depositQueue.length; i++) {
            (success,) = sM.strategies[sM.depositQueue[i]].adapter.delegatecall(
                abi.encodeWithSelector(
                    IStrategyBase.deposit.selector, assets, sM.strategies[sM.depositQueue[i]].supplement
                )
            );
            if (success) {
                break;
            }
        }
        if (!success) {
            sF.underlyingBalance += assets;
        }
        _updateLastTotalAssets(sF, newTotalAssets + assets);
    }

    // TODO: add access control
    function managedDeposit(StrategyArgs calldata strategyArgs) public {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        _managedDeposit(sM, sF, strategyArgs);
    }

    function _managedDeposit(
        LibManagement.ManagementStorage storage sM,
        LibFunds.FundsStorage storage sF,
        StrategyArgs calldata strategyArgs
    ) internal {
        sM.strategies[strategyArgs.index].adapter.functionDelegateCall(
            abi.encodeWithSelector(
                IStrategyBase.deposit.selector, strategyArgs.amount, sM.strategies[strategyArgs.index].supplement
            )
        );
        sF.underlyingBalance -= strategyArgs.amount;
    }

    // TODO: add access control
    function managedWithdraw(StrategyArgs calldata strategyArgs) public {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        _managedWithdraw(sM, sF, strategyArgs);
    }

    function _managedWithdraw(
        LibManagement.ManagementStorage storage sM,
        LibFunds.FundsStorage storage sF,
        StrategyArgs calldata strategyArgs
    ) internal {
        sM.strategies[strategyArgs.index].adapter.functionDelegateCall(
            abi.encodeWithSelector(
                IStrategyBase.withdraw.selector, strategyArgs.amount, sM.strategies[strategyArgs.index].supplement
            )
        );
        sF.underlyingBalance += strategyArgs.amount;
    }

    // TODO: add access control
    function reallocate(StrategyArgs[] calldata withdrawals, StrategyArgs[] calldata deposits) external {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        for (uint256 i; i < withdrawals.length; i++) {
            _managedWithdraw(sM, sF, withdrawals[i]);
        }
        for (uint256 i; i < deposits.length; i++) {
            _managedDeposit(sM, sF, deposits[i]);
        }
    }

    // TODO: add access control?
    // TODO: add test
    function accrueFee() external {
        _accrueFee();
    }

    function redeem(uint256 shares, uint256 projectId, address receiver) external allowSelf {
        (LibFunds.FundsStorage storage sF, uint256 newTotalAssets) = _accrueFee();
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        uint256 assets = _convertToAssetsWithTotals(shares, LibToken.totalSupply(), newTotalAssets);

        _updateLastTotalAssets(sF, newTotalAssets.zeroFloorSub(assets));

        uint256 _assets = assets;
        for (uint256 i; i < sM.withdrawQueue.length; i++) {
            if (_assets == 0) break;
            // TODO: create smarter method to get precise amount able to be withdrawn
            uint256 assetBalance = IStrategyBase(sM.strategies[sM.withdrawQueue[i]].adapter).assetBalance(
                address(this), sM.strategies[sM.withdrawQueue[i]].supplement
            );
            if (assetBalance == 0) continue;
            uint256 availableToWithdraw = FixedPointMathLib.min(assetBalance, _assets);
            (bool success,) = sM.strategies[sM.withdrawQueue[i]].adapter.delegatecall(
                abi.encodeWithSelector(
                    IStrategyBase.withdraw.selector, availableToWithdraw, sM.strategies[sM.withdrawQueue[i]].supplement
                )
            );
            if (success) {
                _assets -= availableToWithdraw;
            }
        }
        if (_assets > 0) {
            sF.underlyingBalance -= _assets;
        }
        sF.underlyingAsset.safeTransfer(receiver, assets);
        address(this).functionDelegateCall(
            abi.encodeWithSelector(TokenFacet.burn.selector, msg.sender, projectId, shares)
        );
    }

    function totalAssets() public view returns (uint256 assets) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        assets = sF.underlyingBalance;
        for (uint256 i; i < sM.strategies.length; ++i) {
            assets += IStrategyBase(sM.strategies[i].adapter).assetBalance(address(this), sM.strategies[i].supplement);
        }
    }

    function strategyAssets(uint256 index) external view returns (uint256) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        return IStrategyBase(sM.strategies[index].adapter).assetBalance(address(this), sM.strategies[index].supplement);
    }

    function _accrueFee() internal returns (LibFunds.FundsStorage storage sF, uint256 newTotalAssets) {
        sF = LibFunds._getFundsStorage();
        newTotalAssets = totalAssets();

        uint256 totalInterest = newTotalAssets.zeroFloorSub(sF.lastTotalAssets);
        if (totalInterest > 0) {
            uint256 feeShares = _convertToSharesWithTotals(totalInterest, LibToken.totalSupply(), sF.lastTotalAssets);
            if (feeShares > 0) {
                address(this).functionDelegateCall(
                    abi.encodeWithSelector(TokenFacet.mint.selector, sF.yieldExtractor, YIELD_PROJECT_ID, feeShares)
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
        return newTotalSupply == 0 ? assets : assets.mulDiv(newTotalSupply, newTotalAssets);
    }

    function _convertToAssetsWithTotals(uint256 shares, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        return shares.mulDiv(newTotalAssets, newTotalSupply);
    }

    function lastTotalAssets() external view returns (uint256) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.lastTotalAssets;
    }

    function underlyingBalance() external view returns (uint256) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.underlyingBalance;
    }

    function underlyingAsset() external view returns (address) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return address(sF.underlyingAsset);
    }

    function yieldExtractor() external view returns (address) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.yieldExtractor;
    }
}

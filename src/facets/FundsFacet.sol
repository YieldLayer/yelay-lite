// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";
import {IFundsFacet, StrategyArgs} from "src/interfaces/IFundsFacet.sol";
import {SwapArgs} from "src/interfaces/ISwapper.sol";

import {SelfOnly} from "src/abstract/SelfOnly.sol";
import {RoleCheck} from "src/abstract/RoleCheck.sol";

import {LibFunds} from "src/libraries/LibFunds.sol";
import {LibClients} from "src/libraries/LibClients.sol";
import {LibToken} from "src/libraries/LibToken.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

import {console} from "forge-std/console.sol";

contract FundsFacet is SelfOnly, RoleCheck, IFundsFacet {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 constant YIELD_PROJECT_ID = 0;

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

    function swapper() external view returns (address) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return address(sF.swapper);
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

    function strategyRewards(uint256 index) external view returns (Reward[] memory rewards) {
        require(tx.origin == address(0), LibErrors.OnlyView());
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        rewards =
            IStrategyBase(sM.strategies[index].adapter).viewRewards(address(this), sM.strategies[index].supplement);
    }

    function deposit(uint256 assets, uint256 projectId, address receiver) external allowSelf returns (uint256 shares) {
        require(LibClients.isProjectActive(projectId), LibErrors.ProjectInactive());

        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        uint256 newTotalAssets;
        // TODO: in case there will be multiple strategies i.e. 5
        // it could be beneficial to not accrue fee on each deposit
        // to save on users gas?
        // TODO: cover in test
        bool needYieldAccrual = sF.lastTotalAssetsTimestamp + 12 hours < block.timestamp;
        if (needYieldAccrual) {
            newTotalAssets = _accrueFee(sF);
        } else {
            newTotalAssets = sF.lastTotalAssets;
        }
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        shares = _convertToShares(assets, LibToken.totalSupply(), newTotalAssets);

        sF.underlyingAsset.safeTransferFrom(msg.sender, address(this), assets);
        LibToken.mint(receiver, projectId, shares);
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
        // TODO: cover in test
        if (needYieldAccrual) {
            sF.lastTotalAssetsTimestamp = uint64(block.timestamp);
        }

        LibClients.onDeposit(projectId, msg.sender, receiver, assets, shares);

        emit LibEvents.Deposit(projectId, msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, uint256 projectId, address receiver) external allowSelf returns (uint256 assets) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        uint256 newTotalAssets = _accrueFee(sF);

        assets = _convertToAssets(shares, LibToken.totalSupply(), newTotalAssets);

        _updateLastTotalAssets(sF, newTotalAssets.zeroFloorSub(assets));

        uint256 _assets = assets;
        for (uint256 i; i < sM.withdrawQueue.length; i++) {
            if (_assets == 0) break;
            // TODO: create smarter method to get precise amount able to be withdrawn?
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
        LibToken.burn(msg.sender, projectId, shares);

        LibClients.onRedeem(projectId, msg.sender, receiver, assets, shares);

        emit LibEvents.Redeem(projectId, msg.sender, receiver, assets, shares);
    }

    function migratePosition(uint256 fromProjectId, uint256 toProjectId, uint256 amount) external allowSelf {
        require(
            LibClients.isProjectActive(fromProjectId) && LibClients.isProjectActive(toProjectId)
                && LibClients.sameClient(fromProjectId, toProjectId),
            LibErrors.PositionMigrationForbidden()
        );
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        // TODO: cover in test
        uint256 newTotalAssets = _accrueFee(sF);
        _updateLastTotalAssets(sF, newTotalAssets);
        LibToken.migrate(msg.sender, fromProjectId, toProjectId, amount);
        emit LibEvents.PositionMigrated(msg.sender, fromProjectId, toProjectId, amount);
    }

    function managedDeposit(StrategyArgs calldata strategyArgs) public onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        _managedDeposit(sM, sF, strategyArgs);
    }

    function managedWithdraw(StrategyArgs calldata strategyArgs) public onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        _managedWithdraw(sM, sF, strategyArgs);
    }

    function reallocate(StrategyArgs[] calldata withdrawals, StrategyArgs[] calldata deposits)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        for (uint256 i; i < withdrawals.length; i++) {
            _managedWithdraw(sM, sF, withdrawals[i]);
        }
        for (uint256 i; i < deposits.length; i++) {
            _managedDeposit(sM, sF, deposits[i]);
        }
    }

    function compound(SwapArgs[] memory swapArgs)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        allowSelf
        returns (uint256 compounded)
    {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        address _underlyingAsset = address(sF.underlyingAsset);
        address _swapper = address(sF.swapper);
        for (uint256 i; i < swapArgs.length; i++) {
            require(swapArgs[i].tokenIn != _underlyingAsset, LibErrors.CompoundUnderlyingForbidden());
            uint256 tokenInAmount = ERC20(swapArgs[i].tokenIn).balanceOf(address(this));
            ERC20(swapArgs[i].tokenIn).safeTransfer(_swapper, tokenInAmount);
        }
        compounded = sF.swapper.swap(swapArgs, _underlyingAsset);
        // TODO: cover this in test
        sF.underlyingBalance += compounded;
        uint256 newTotalAssets = _accrueFee(sF);
        _updateLastTotalAssets(sF, newTotalAssets + compounded);
        sF.lastTotalAssetsTimestamp = uint64(block.timestamp);
        emit LibEvents.Compounded(compounded);
    }

    function accrueFee() public allowSelf onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        // TODO: cover this in test
        uint256 newTotalAssets = _accrueFee(sF);
        _updateLastTotalAssets(sF, newTotalAssets);
    }

    function claimStrategyRewards(uint256 index) external onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        sM.strategies[index].adapter.functionDelegateCall(
            abi.encodeWithSelector(IStrategyBase.claimRewards.selector, sM.strategies[index].supplement)
        );
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
        emit LibEvents.ManagedDeposit(sM.strategies[strategyArgs.index].adapter, strategyArgs.amount);
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
        emit LibEvents.ManagedWithdraw(sM.strategies[strategyArgs.index].adapter, strategyArgs.amount);
    }

    function _accrueFee(LibFunds.FundsStorage storage sF) internal returns (uint256 newTotalAssets) {
        newTotalAssets = totalAssets();

        uint256 totalInterest = newTotalAssets.zeroFloorSub(sF.lastTotalAssets);
        if (totalInterest > 0) {
            uint256 feeShares = _convertToShares(totalInterest, LibToken.totalSupply(), sF.lastTotalAssets);
            if (feeShares > 0) {
                LibToken.mint(sF.yieldExtractor, YIELD_PROJECT_ID, feeShares);
            }
            emit LibEvents.AccrueInterest(newTotalAssets, totalInterest, feeShares);
        }
    }

    function _updateLastTotalAssets(LibFunds.FundsStorage storage sF, uint256 updatedTotalAssets) internal {
        // TODO: safe cast?
        sF.lastTotalAssets = uint192(updatedTotalAssets);
        emit LibEvents.UpdateLastTotalAssets(updatedTotalAssets);
    }

    function _convertToShares(uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        return newTotalSupply == 0 ? assets : assets.mulDiv(newTotalSupply, newTotalAssets);
    }

    function _convertToAssets(uint256 shares, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        return shares.mulDiv(newTotalAssets, newTotalSupply);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155SupplyUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";
import {IFundsFacet, StrategyArgs} from "src/interfaces/IFundsFacet.sol";
import {ISwapper, SwapArgs} from "src/interfaces/ISwapper.sol";

import {RoleCheck} from "src/abstract/RoleCheck.sol";
import {PausableCheck} from "src/abstract/PausableCheck.sol";

import {LibFunds} from "src/libraries/LibFunds.sol";
import {LibClients} from "src/libraries/LibClients.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

/**
 * @title FundsFacet
 * @dev Contract that manages funds, including deposits, withdrawals, reallocation, compounding etc.
 */
contract FundsFacet is RoleCheck, PausableCheck, ERC1155SupplyUpgradeable, IFundsFacet {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 constant YIELD_PROJECT_ID = 0;
    uint256 constant WITHDRAW_MARGIN = 10;

    ISwapper private immutable _swapper;

    /**
     * @dev Initializes the contract with the given swapper.
     * @param swapper_ The address of the swapper contract.
     */
    constructor(ISwapper swapper_) {
        _swapper = swapper_;
    }

    /// @inheritdoc IFundsFacet
    function totalSupply() public view override(ERC1155SupplyUpgradeable, IFundsFacet) returns (uint256) {
        return super.totalSupply();
    }

    /// @inheritdoc IFundsFacet
    function totalSupply(uint256 id) public view override(ERC1155SupplyUpgradeable, IFundsFacet) returns (uint256) {
        return super.totalSupply(id);
    }

    /// @inheritdoc IFundsFacet
    function lastTotalAssets() external view returns (uint256) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.lastTotalAssets;
    }

    /// @inheritdoc IFundsFacet
    function lastTotalAssetsTimestamp() external view returns (uint64) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.lastTotalAssetsTimestamp;
    }

    /// @inheritdoc IFundsFacet
    function lastTotalAssetsUpdateInterval() external view returns (uint64) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.lastTotalAssetsUpdateInterval;
    }

    /// @inheritdoc IFundsFacet
    function setLastTotalAssetsUpdateInterval(uint64 interval) external notPaused onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        sF.lastTotalAssetsUpdateInterval = interval;
        emit LibEvents.UpdateLastTotalAssetsUpdateInterval(interval);
    }

    /// @inheritdoc IFundsFacet
    function underlyingBalance() external view returns (uint256) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.underlyingBalance;
    }

    /// @inheritdoc IFundsFacet
    function underlyingAsset() external view returns (address) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return address(sF.underlyingAsset);
    }

    /// @inheritdoc IFundsFacet
    function yieldExtractor() external view returns (address) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.yieldExtractor;
    }

    /// @inheritdoc IFundsFacet
    function setYieldExtractor(address _yieldExtractor) external notPaused onlyRole(LibRoles.STRATEGY_AUTHORITY) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        sF.yieldExtractor = _yieldExtractor;
        emit LibEvents.UpdateYieldExtractor(_yieldExtractor);
    }

    /// @inheritdoc IFundsFacet
    function swapper() external view returns (address) {
        return address(_swapper);
    }

    /// @inheritdoc IFundsFacet
    function totalAssets() public view returns (uint256 assets) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        assets = sF.underlyingBalance;
        for (uint256 i; i < sM.activeStrategies.length; ++i) {
            assets += LibManagement._strategyAssets(i);
        }
    }

    /// @inheritdoc IFundsFacet
    function strategyAssets(uint256 index) external view returns (uint256) {
        return LibManagement._strategyAssets(index);
    }

    /// @inheritdoc IFundsFacet
    function strategyRewards(uint256 index) external view returns (Reward[] memory rewards) {
        require(tx.origin == address(0), LibErrors.OnlyView());
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        rewards = IStrategyBase(sM.activeStrategies[index].adapter).viewRewards(
            address(this), sM.activeStrategies[index].supplement
        );
    }

    /// @inheritdoc IFundsFacet
    function deposit(uint256 assets, uint256 projectId, address receiver) external notPaused returns (uint256 shares) {
        require(LibClients._isProjectActive(projectId), LibErrors.ProjectInactive());

        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        uint256 newTotalAssets;
        if (sF.lastTotalAssetsTimestamp + sF.lastTotalAssetsUpdateInterval < block.timestamp) {
            newTotalAssets = _mintFee(sF);
            sF.lastTotalAssetsTimestamp = SafeCast.toUint64(block.timestamp);
        } else {
            newTotalAssets = sF.lastTotalAssets;
        }
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        shares = _convertToShares(assets, totalSupply(), newTotalAssets);

        sF.underlyingAsset.safeTransferFrom(msg.sender, address(this), assets);
        bool success;
        for (uint256 i; i < sM.depositQueue.length; i++) {
            (success,) = sM.activeStrategies[sM.depositQueue[i]].adapter.delegatecall(
                abi.encodeWithSelector(
                    IStrategyBase.deposit.selector, assets, sM.activeStrategies[sM.depositQueue[i]].supplement
                )
            );
            if (success) {
                break;
            }
        }
        if (!success) {
            sF.underlyingBalance += SafeCast.toUint192(assets);
        }
        _updateLastTotalAssets(sF, newTotalAssets + assets);

        _mint(receiver, projectId, shares, "");

        emit LibEvents.Deposit(projectId, msg.sender, receiver, assets, shares);
    }

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
        uint256 toReturn = lack > WITHDRAW_MARGIN ? assets : assets - lack;
        // ensure we have enough funds in vault
        require(sF.underlyingBalance + WITHDRAW_MARGIN >= toReturn, LibErrors.NotEnoughInternalFunds());
        // normalize for the last withdrawal - we already know that they are close together
        toReturn = FixedPointMathLib.min(sF.underlyingBalance, toReturn);
        sF.underlyingBalance -= SafeCast.toUint192(toReturn);
        sF.underlyingAsset.safeTransfer(receiver, toReturn);
        _burn(msg.sender, projectId, shares);

        emit LibEvents.Redeem(projectId, msg.sender, receiver, toReturn, shares);
    }

    /// @inheritdoc IFundsFacet
    function migratePosition(uint256 fromProjectId, uint256 toProjectId, uint256 amount) external notPaused {
        require(
            LibClients._isProjectActive(fromProjectId) && LibClients._isProjectActive(toProjectId)
                && LibClients._sameClient(fromProjectId, toProjectId) && fromProjectId != toProjectId,
            LibErrors.PositionMigrationForbidden()
        );
        _accrueFee();
        _burn(msg.sender, fromProjectId, amount);
        _mint(msg.sender, toProjectId, amount, "");
        emit LibEvents.PositionMigrated(msg.sender, fromProjectId, toProjectId, amount);
    }

    /// @inheritdoc IFundsFacet
    function managedDeposit(StrategyArgs calldata strategyArgs) public onlyRole(LibRoles.FUNDS_OPERATOR) notPaused {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        _managedDeposit(sM, sF, strategyArgs);
    }

    /// @inheritdoc IFundsFacet
    function managedWithdraw(StrategyArgs calldata strategyArgs) public onlyRole(LibRoles.FUNDS_OPERATOR) notPaused {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        _managedWithdraw(sM, sF, strategyArgs);
    }

    /// @inheritdoc IFundsFacet
    function reallocate(StrategyArgs[] calldata withdrawals, StrategyArgs[] calldata deposits)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        notPaused
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

    /// @inheritdoc IFundsFacet
    function swapRewards(SwapArgs[] memory swapArgs)
        external
        notPaused
        onlyRole(LibRoles.SWAP_REWARDS_OPERATOR)
        returns (uint256 compounded)
    {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        address _underlyingAsset = address(sF.underlyingAsset);
        uint256 totalAssetsBefore = totalAssets();
        for (uint256 i; i < swapArgs.length; i++) {
            require(swapArgs[i].tokenIn != _underlyingAsset, LibErrors.CompoundUnderlyingForbidden());
            uint256 tokenInAmount = ERC20(swapArgs[i].tokenIn).balanceOf(address(this));
            ERC20(swapArgs[i].tokenIn).safeTransfer(address(_swapper), tokenInAmount);
        }
        compounded = _swapper.swap(swapArgs, _underlyingAsset);
        sF.underlyingBalance += SafeCast.toUint192(compounded);
        require(totalAssets() > totalAssetsBefore, LibErrors.TotalAssetsLoss());
        _accrueFee();
        emit LibEvents.Compounded(compounded);
    }

    /// @inheritdoc IFundsFacet
    function accrueFee() public notPaused {
        _accrueFee();
    }

    /**
     * @dev Internal function to accrue fees.
     */
    function _accrueFee() internal {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        uint256 newTotalAssets = _mintFee(sF);
        _updateLastTotalAssets(sF, newTotalAssets);
        sF.lastTotalAssetsTimestamp = SafeCast.toUint64(block.timestamp);
    }

    /// @inheritdoc IFundsFacet
    function claimStrategyRewards(uint256 index) external notPaused onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        sM.activeStrategies[index].adapter.functionDelegateCall(
            abi.encodeWithSelector(IStrategyBase.claimRewards.selector, sM.activeStrategies[index].supplement)
        );
    }

    /**
     * @dev Internal function to deposit assets into a strategy.
     * @param sM The management storage.
     * @param sF The funds storage.
     * @param strategyArgs The strategy arguments.
     */
    function _managedDeposit(
        LibManagement.ManagementStorage storage sM,
        LibFunds.FundsStorage storage sF,
        StrategyArgs calldata strategyArgs
    ) internal {
        sM.activeStrategies[strategyArgs.index].adapter.functionDelegateCall(
            abi.encodeWithSelector(
                IStrategyBase.deposit.selector, strategyArgs.amount, sM.activeStrategies[strategyArgs.index].supplement
            )
        );
        sF.underlyingBalance -= SafeCast.toUint192(strategyArgs.amount);
        emit LibEvents.ManagedDeposit(sM.activeStrategies[strategyArgs.index].name, strategyArgs.amount);
    }

    /**
     * @dev Internal function to withdraw assets from a strategy.
     * @param sM The management storage.
     * @param sF The funds storage.
     * @param strategyArgs The strategy arguments.
     */
    function _managedWithdraw(
        LibManagement.ManagementStorage storage sM,
        LibFunds.FundsStorage storage sF,
        StrategyArgs calldata strategyArgs
    ) internal {
        bytes memory payload = strategyArgs.amount == type(uint256).max
            ? abi.encodeWithSelector(IStrategyBase.withdrawAll.selector, sM.activeStrategies[strategyArgs.index].supplement)
            : abi.encodeWithSelector(
                IStrategyBase.withdraw.selector, strategyArgs.amount, sM.activeStrategies[strategyArgs.index].supplement
            );
        bytes memory result = sM.activeStrategies[strategyArgs.index].adapter.functionDelegateCall(payload);
        uint256 withdrawn = abi.decode(result, (uint256));
        sF.underlyingBalance += SafeCast.toUint192(withdrawn);
        emit LibEvents.ManagedWithdraw(sM.activeStrategies[strategyArgs.index].name, withdrawn);
    }

    /**
     * @dev Internal function to mint fees.
     * @param sF The funds storage.
     * @return newTotalAssets The new total assets value.
     */
    function _mintFee(LibFunds.FundsStorage storage sF) internal returns (uint256 newTotalAssets) {
        newTotalAssets = totalAssets();

        uint256 totalInterest = newTotalAssets.zeroFloorSub(sF.lastTotalAssets);
        if (totalInterest > 0) {
            uint256 feeShares = _convertToShares(totalInterest, totalSupply(), sF.lastTotalAssets);
            if (feeShares > 0) {
                _mint(sF.yieldExtractor, YIELD_PROJECT_ID, feeShares, "");
            }
            emit LibEvents.AccrueInterest(newTotalAssets, totalInterest, feeShares);
        }
    }

    /**
     * @dev Internal function to update the last total assets value.
     * @param sF The funds storage.
     * @param updatedTotalAssets The updated total assets value.
     */
    function _updateLastTotalAssets(LibFunds.FundsStorage storage sF, uint256 updatedTotalAssets) internal {
        sF.lastTotalAssets = SafeCast.toUint192(updatedTotalAssets);
        emit LibEvents.UpdateLastTotalAssets(updatedTotalAssets);
    }

    /**
     * @dev Internal function to convert assets to shares.
     * @param assets The amount of assets.
     * @param newTotalSupply The new total supply.
     * @param newTotalAssets The new total assets.
     * @return The amount of shares.
     */
    function _convertToShares(uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        return newTotalSupply == 0 ? assets : assets.mulDiv(newTotalSupply, newTotalAssets);
    }

    /**
     * @dev Internal function to convert shares to assets.
     * @param shares The amount of shares.
     * @param newTotalSupply The new total supply.
     * @param newTotalAssets The new total assets.
     * @return The amount of assets.
     */
    function _convertToAssets(uint256 shares, uint256 newTotalSupply, uint256 newTotalAssets)
        internal
        pure
        returns (uint256)
    {
        return shares.mulDiv(newTotalAssets, newTotalSupply);
    }
}

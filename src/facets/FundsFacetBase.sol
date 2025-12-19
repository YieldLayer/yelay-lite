// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155SupplyUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

import {IStrategyBase, Reward} from "src/interfaces/IStrategyBase.sol";
import {IFundsFacetBase, StrategyArgs} from "src/interfaces/IFundsFacetBase.sol";
import {ISwapper, SwapArgs} from "src/interfaces/ISwapper.sol";
import {IMerklDistributor} from "src/interfaces/external/merkl/IMerklDistributor.sol";

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
contract FundsFacetBase is RoleCheck, PausableCheck, ERC1155SupplyUpgradeable, IFundsFacetBase {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 constant YIELD_PROJECT_ID = 0;
    uint256 constant WITHDRAW_MARGIN = 10;

    ISwapper private immutable _swapper;
    IMerklDistributor private immutable _merklDistributor;

    /**
     * @dev Initializes the contract with the given swapper.
     * @param swapper_ The address of the swapper contract.
     * @param merklDistributor_ The address of the merkl distributor contract.
     */
    constructor(ISwapper swapper_, IMerklDistributor merklDistributor_) {
        _swapper = swapper_;
        _merklDistributor = merklDistributor_;
    }

    /// @inheritdoc IFundsFacetBase
    function totalSupply() public view virtual override(ERC1155SupplyUpgradeable, IFundsFacetBase) returns (uint256) {
        return super.totalSupply();
    }

    /// @inheritdoc IFundsFacetBase
    function totalSupply(uint256 id)
        public
        view
        virtual
        override(ERC1155SupplyUpgradeable, IFundsFacetBase)
        returns (uint256)
    {
        return super.totalSupply(id);
    }

    /// @inheritdoc IFundsFacetBase
    function lastTotalAssets() external view returns (uint256) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.lastTotalAssets;
    }

    /// @inheritdoc IFundsFacetBase
    function lastTotalAssetsTimestamp() external view returns (uint64) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.lastTotalAssetsTimestamp;
    }

    /// @inheritdoc IFundsFacetBase
    function underlyingBalance() external view returns (uint256) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.underlyingBalance;
    }

    /// @inheritdoc IFundsFacetBase
    function underlyingAsset() external view returns (address) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return address(sF.underlyingAsset);
    }

    /// @inheritdoc IFundsFacetBase
    function yieldExtractor() external view returns (address) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        return sF.yieldExtractor;
    }

    /// @inheritdoc IFundsFacetBase
    function setYieldExtractor(address _yieldExtractor) external notPaused onlyRole(LibRoles.STRATEGY_AUTHORITY) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        sF.yieldExtractor = _yieldExtractor;
        emit LibEvents.UpdateYieldExtractor(_yieldExtractor);
    }

    /// @inheritdoc IFundsFacetBase
    function swapper() external view returns (address) {
        return address(_swapper);
    }

    /// @inheritdoc IFundsFacetBase
    function merklDistributor() external view returns (address) {
        return address(_merklDistributor);
    }

    /// @inheritdoc IFundsFacetBase
    function totalAssets() public view returns (uint256 assets) {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();

        assets = sF.underlyingBalance;
        for (uint256 i; i < sM.activeStrategies.length; ++i) {
            assets += LibManagement._strategyAssets(i);
        }
    }

    /// @inheritdoc IFundsFacetBase
    function strategyAssets(uint256 index) external view returns (uint256) {
        return LibManagement._strategyAssets(index);
    }

    /// @inheritdoc IFundsFacetBase
    function strategyRewards(uint256 index) external view returns (Reward[] memory rewards) {
        require(tx.origin == address(0), LibErrors.OnlyView());
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        rewards = IStrategyBase(sM.activeStrategies[index].adapter).viewRewards(
            address(this), sM.activeStrategies[index].supplement
        );
    }

    /// @inheritdoc IFundsFacetBase
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

    /// @inheritdoc IFundsFacetBase
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

    /// @inheritdoc IFundsFacetBase
    function managedDeposit(StrategyArgs calldata strategyArgs) public onlyRole(LibRoles.FUNDS_OPERATOR) notPaused {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        _managedDeposit(sM, sF, strategyArgs);
    }

    /// @inheritdoc IFundsFacetBase
    function managedWithdraw(StrategyArgs calldata strategyArgs) public onlyRole(LibRoles.FUNDS_OPERATOR) notPaused {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        _managedWithdraw(sM, sF, strategyArgs);
    }

    /// @inheritdoc IFundsFacetBase
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

    /// @inheritdoc IFundsFacetBase
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

    /// @inheritdoc IFundsFacetBase
    function compoundUnderlyingReward()
        external
        notPaused
        onlyRole(LibRoles.SWAP_REWARDS_OPERATOR)
        returns (uint256 compounded)
    {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        uint256 totalAssetsBefore = totalAssets();
        uint256 balance = sF.underlyingAsset.balanceOf(address(this));
        compounded = balance - sF.underlyingBalance;
        sF.underlyingBalance += SafeCast.toUint192(compounded);
        require(totalAssets() > totalAssetsBefore, LibErrors.TotalAssetsLoss());
        _accrueFee();
        emit LibEvents.Compounded(compounded);
    }

    // TODO: do not accrue yield / mint yield shares on Satellite Vault
    /// @inheritdoc IFundsFacetBase
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

    /// @inheritdoc IFundsFacetBase
    function claimStrategyRewards(uint256 index) external notPaused onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        sM.activeStrategies[index].adapter.functionDelegateCall(
            abi.encodeWithSelector(IStrategyBase.claimRewards.selector, sM.activeStrategies[index].supplement)
        );
    }

    /// @inheritdoc IFundsFacetBase
    function claimMerklRewards(address[] calldata tokens, uint256[] calldata amounts, bytes32[][] calldata proofs)
        external
        notPaused
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        address[] memory users = new address[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            users[i] = address(this);
        }
        _merklDistributor.claim(users, tokens, amounts, proofs);
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
        uint256 depositAmount = strategyArgs.amount == type(uint256).max ? sF.underlyingBalance : strategyArgs.amount;
        sM.activeStrategies[strategyArgs.index].adapter.functionDelegateCall(
            abi.encodeWithSelector(
                IStrategyBase.deposit.selector, depositAmount, sM.activeStrategies[strategyArgs.index].supplement
            )
        );
        sF.underlyingBalance -= SafeCast.toUint192(depositAmount);
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
        virtual
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
        virtual
        returns (uint256)
    {
        return shares.mulDiv(newTotalAssets, newTotalSupply);
    }
}

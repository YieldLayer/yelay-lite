// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";
import {IManagementFacet, StrategyData} from "src/interfaces/IManagementFacet.sol";

import {RoleCheck} from "src/abstract/RoleCheck.sol";
import {PausableCheck} from "src/abstract/PausableCheck.sol";

import {LibFunds} from "src/libraries/LibFunds.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

/**
 * @title ManagementFacet
 * @dev Contract that manages strategies and their queues.
 */
contract ManagementFacet is RoleCheck, PausableCheck, IManagementFacet {
    using Address for address;
    using SafeTransferLib for ERC20;

    /// @inheritdoc IManagementFacet
    function getStrategies() external view returns (StrategyData[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        return sM.strategies;
    }

    /// @inheritdoc IManagementFacet
    function getActiveStrategies() external view returns (StrategyData[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        return sM.activeStrategies;
    }

    /// @inheritdoc IManagementFacet
    function getDepositQueue() external view returns (uint256[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        return sM.depositQueue;
    }

    /// @inheritdoc IManagementFacet
    function getWithdrawQueue() external view returns (uint256[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        return sM.withdrawQueue;
    }

    /// @inheritdoc IManagementFacet
    function updateDepositQueue(uint256[] calldata depositQueue_)
        external
        notPaused
        onlyRole(LibRoles.QUEUES_OPERATOR)
    {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        _updateDepositQueue(sM, depositQueue_);
    }

    function _updateDepositQueue(LibManagement.ManagementStorage storage sM, uint256[] calldata depositQueue_)
        internal
    {
        sM.depositQueue = depositQueue_;
        emit LibEvents.UpdateDepositQueue();
    }

    /// @inheritdoc IManagementFacet
    function updateWithdrawQueue(uint256[] calldata withdrawQueue_)
        external
        notPaused
        onlyRole(LibRoles.QUEUES_OPERATOR)
    {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        _updateWithdrawQueue(sM, withdrawQueue_);
    }

    function _updateWithdrawQueue(LibManagement.ManagementStorage storage sM, uint256[] calldata withdrawQueue_)
        internal
    {
        sM.withdrawQueue = withdrawQueue_;
        emit LibEvents.UpdateWithdrawQueue();
    }

    function _getStrategyId(StrategyData memory strategy) internal pure returns (bytes32) {
        return keccak256((abi.encodePacked(strategy.adapter, strategy.supplement)));
    }

    /// @inheritdoc IManagementFacet
    function addStrategy(StrategyData calldata strategy) external notPaused onlyRole(LibRoles.STRATEGY_AUTHORITY) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        bytes32 strategyId = _getStrategyId(strategy);
        require(sM.strategyRegistered[strategyId] == false, LibErrors.StrategyRegistered());
        sM.strategyRegistered[strategyId] = true;
        sM.strategies.push(strategy);
        emit LibEvents.AddStrategy(strategy.adapter, strategy.supplement);
    }

    /// @inheritdoc IManagementFacet
    function removeStrategy(uint256 index) external notPaused onlyRole(LibRoles.STRATEGY_AUTHORITY) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        bytes32 strategyId = _getStrategyId(sM.strategies[index]);
        require(sM.strategyIsActive[strategyId] == false, LibErrors.StrategyActive());
        emit LibEvents.RemoveStrategy(sM.strategies[index].adapter, sM.strategies[index].supplement);
        sM.strategyRegistered[strategyId] = false;
        sM.strategies[index] = sM.strategies[sM.strategies.length - 1];
        sM.strategies.pop();
    }

    /// @inheritdoc IManagementFacet
    function activateStrategy(uint256 index, uint256[] calldata depositQueue_, uint256[] calldata withdrawQueue_)
        external
        notPaused
        onlyRole(LibRoles.QUEUES_OPERATOR)
    {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        StrategyData memory strategy = sM.strategies[index];
        bytes32 strategyId = _getStrategyId(strategy);
        require(sM.strategyIsActive[strategyId] == false, LibErrors.StrategyActive());
        sM.strategyIsActive[strategyId] = true;
        sM.activeStrategies.push(strategy);
        strategy.adapter.functionDelegateCall(abi.encodeWithSelector(IStrategyBase.onAdd.selector, strategy.supplement));
        _updateDepositQueue(sM, depositQueue_);
        _updateWithdrawQueue(sM, withdrawQueue_);
        emit LibEvents.ActivateStrategy(strategy.adapter, strategy.supplement);
    }

    /// @inheritdoc IManagementFacet
    function deactivateStrategy(uint256 index, uint256[] calldata depositQueue_, uint256[] calldata withdrawQueue_)
        external
        notPaused
        onlyRole(LibRoles.QUEUES_OPERATOR)
    {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        StrategyData memory strategy = sM.activeStrategies[index];
        bytes32 strategyId = _getStrategyId(strategy);
        require(LibManagement._strategyAssets(index) == 0, LibErrors.StrategyNotEmpty());
        emit LibEvents.DeactivateStrategy(strategy.adapter, strategy.supplement);
        sM.strategyIsActive[strategyId] = false;
        sM.activeStrategies[index].adapter
            .functionDelegateCall(
                abi.encodeWithSelector(IStrategyBase.onRemove.selector, sM.activeStrategies[index].supplement)
            );
        sM.activeStrategies[index] = sM.activeStrategies[sM.activeStrategies.length - 1];
        sM.activeStrategies.pop();
        _updateDepositQueue(sM, depositQueue_);
        _updateWithdrawQueue(sM, withdrawQueue_);
    }

    /// @inheritdoc IManagementFacet
    function approveStrategy(uint256 index, uint256 amount) external notPaused onlyRole(LibRoles.STRATEGY_AUTHORITY) {
        LibFunds.FundsStorage memory sF = LibFunds._getFundsStorage();
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        address protocol = IStrategyBase(sM.strategies[index].adapter).protocol(sM.strategies[index].supplement);
        sF.underlyingAsset.safeApprove(protocol, amount);
    }
}

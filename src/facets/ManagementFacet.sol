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

contract ManagementFacet is RoleCheck, PausableCheck, IManagementFacet {
    using Address for address;
    using SafeTransferLib for ERC20;

    function getStrategies() external view returns (StrategyData[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        return sM.strategies;
    }

    function getDepositQueue() external view returns (uint256[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        return sM.depositQueue;
    }

    function getWithdrawQueue() external view returns (uint256[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        return sM.withdrawQueue;
    }

    function updateDepositQueue(uint256[] calldata depositQueue_)
        external
        notPaused
        onlyRole(LibRoles.QUEUES_OPERATOR)
    {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        sM.depositQueue = depositQueue_;
        emit LibEvents.UpdateDepositQueue();
    }

    function updateWithdrawQueue(uint256[] calldata withdrawQueue_)
        external
        notPaused
        onlyRole(LibRoles.QUEUES_OPERATOR)
    {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        sM.withdrawQueue = withdrawQueue_;
        emit LibEvents.UpdateWithdrawQueue();
    }

    function addStrategy(StrategyData calldata strategy) external notPaused onlyRole(LibRoles.STRATEGY_AUTHORITY) {
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        sM.strategies.push(strategy);
        _approveStrategy(strategy, type(uint256).max);
        strategy.adapter.functionDelegateCall(abi.encodeWithSelector(IStrategyBase.onAdd.selector, strategy.supplement));
        emit LibEvents.AddStrategy(strategy.adapter, strategy.supplement);
    }

    function removeStrategy(uint256 index) external notPaused onlyRole(LibRoles.STRATEGY_AUTHORITY) {
        require(LibManagement._strategyAssets(index) == 0, LibErrors.StrategyNotEmpty());
        LibManagement.ManagementStorage storage sM = LibManagement._getManagementStorage();
        _approveStrategy(sM.strategies[index], 0);
        sM.strategies[index].adapter.functionDelegateCall(
            abi.encodeWithSelector(IStrategyBase.onRemove.selector, sM.strategies[index].supplement)
        );
        emit LibEvents.RemoveStrategy(sM.strategies[index].adapter, sM.strategies[index].supplement);
        sM.strategies[index] = sM.strategies[sM.strategies.length - 1];
        sM.strategies.pop();
    }

    function _approveStrategy(StrategyData memory strategy, uint256 amount) internal {
        LibFunds.FundsStorage memory sF = LibFunds._getFundsStorage();
        address protocol = IStrategyBase(strategy.adapter).protocol();
        sF.underlyingAsset.safeApprove(protocol, amount);
    }
}

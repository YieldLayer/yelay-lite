// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/utils/Address.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {IStrategyBase} from "src/interfaces/IStrategyBase.sol";

import {LibFunds} from "src/libraries/LibFunds.sol";
import {LibManagement} from "src/libraries/LibManagement.sol";

import {console} from "forge-std/console.sol";

// TODO: add access control
contract ManagementFacet {
    using Address for address;
    using SafeTransferLib for ERC20;

    function getDepositQueue() external view returns (uint256[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement.getStorage();
        return sM.depositQueue;
    }

    function updateDepositQueue(uint256[] calldata depositQueue_) external {
        LibManagement.ManagementStorage storage sM = LibManagement.getStorage();
        sM.depositQueue = depositQueue_;
    }

    function getWithdrawQueue() external view returns (uint256[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement.getStorage();
        return sM.withdrawQueue;
    }

    function updateWithdrawQueue(uint256[] calldata withdrawQueue_) external {
        LibManagement.ManagementStorage storage sM = LibManagement.getStorage();
        sM.withdrawQueue = withdrawQueue_;
    }

    function getStrategies() external view returns (LibManagement.StrategyData[] memory) {
        LibManagement.ManagementStorage storage sM = LibManagement.getStorage();
        return sM.strategies;
    }

    function addStrategy(LibManagement.StrategyData calldata strategy) external {
        LibManagement.ManagementStorage storage sM = LibManagement.getStorage();
        sM.strategies.push(strategy);
        _approveStrategy(strategy, type(uint256).max);
        strategy.adapter.functionDelegateCall(abi.encodeCall(IStrategyBase.onAdd, ()));
    }

    function removeStrategy(uint256 index) external {
        LibManagement.ManagementStorage storage sM = LibManagement.getStorage();
        _approveStrategy(sM.strategies[index], 0);
        sM.strategies[index].adapter.functionDelegateCall(abi.encodeCall(IStrategyBase.onRemove, ()));
        sM.strategies[index] = sM.strategies[sM.strategies.length - 1];
        sM.strategies.pop();
    }

    function _approveStrategy(LibManagement.StrategyData memory strategy, uint256 amount) internal {
        LibFunds.FundsStorage memory sM = LibFunds.getStorage();
        address protocol = IStrategyBase(strategy.adapter).protocol();
        sM.underlyingAsset.approve(protocol, amount);
    }
}

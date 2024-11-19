// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/utils/Address.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {TokenFacet} from "src/facets/TokenFacet.sol";
import {SelfOnly} from "src/abstract/SelfOnly.sol";
import {LibFunds} from "src/libraries/LibFunds.sol";

contract FundsFacet is SelfOnly {
    using Address for address;
    using SafeTransferLib for ERC20;

    function deposit(address receiver, uint256 amount) external allowSelf {
        LibFunds.FundsStorage memory s = LibFunds._getFundsStorage();
        s.underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.mint.selector, receiver, amount));
    }

    function withdraw(address receiver, uint256 amount) external allowSelf {
        LibFunds.FundsStorage memory s = LibFunds._getFundsStorage();
        s.underlyingAsset.safeTransfer(receiver, amount);
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.burn.selector, msg.sender, amount));
    }
}

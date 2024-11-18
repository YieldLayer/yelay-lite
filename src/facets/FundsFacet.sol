// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Address} from "@openzeppelin/utils/Address.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {TokenFacet} from "src/facets/TokenFacet.sol";
import {SelfOnly} from "src/abstract/SelfOnly.sol";

contract FundsFacet is SelfOnly {
    using Address for address;
    using SafeTransferLib for ERC20;

    // TODO: implement erc7201!
    ERC20 public underlyingAsset;

    // TODO: decide how to support multiple initializers
    function initializeFundsFacet(address underlyingAsset_) external {
        underlyingAsset = ERC20(underlyingAsset_);
    }

    function deposit(address receiver, uint256 amount) external allowSelf {
        underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.mint.selector, receiver, amount));
    }

    function withdraw(address receiver, uint256 amount) external allowSelf {
        underlyingAsset.safeTransfer(receiver, amount);
        address(this).functionDelegateCall(abi.encodeWithSelector(TokenFacet.burn.selector, msg.sender, amount));
    }
}

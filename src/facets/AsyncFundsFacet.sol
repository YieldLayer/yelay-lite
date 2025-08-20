// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {FundsFacetBase} from "src/facets/FundsFacetBase.sol";

import {ISwapper} from "src/interfaces/ISwapper.sol";
import {IMerklDistributor} from "src/interfaces/external/merkl/IMerklDistributor.sol";
import {IFundsFacetBase} from "src/interfaces/IFundsFacetBase.sol";
import {IAsyncFundsFacet, StrategyArgs} from "src/interfaces/IAsyncFundsFacet.sol";

import {LibAsyncFunds} from "src/libraries/LibAsyncFunds.sol";
import {LibFunds} from "src/libraries/LibFunds.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

/**
 * @title AsyncFundsFacet
 * @dev Contract that manages funds with async withdrawal support, including deposits, withdrawals, reallocation, compounding etc.
 */
contract AsyncFundsFacet is FundsFacetBase, IAsyncFundsFacet {
    using SafeTransferLib for ERC20;

    constructor(ISwapper swapper_, IMerklDistributor merklDistributor_) FundsFacetBase(swapper_, merklDistributor_) {}

    function requestAsyncFunds(uint256 shares, uint256 projectId, address receiver)
        external
        notPaused
        returns (uint256 requestId)
    {
        LibAsyncFunds.AsyncFundsStorage storage sA = LibAsyncFunds._getAsyncFundsStorage();
        require(shares > 0, LibErrors.ZeroAmount());
        require(receiver != address(0), LibErrors.ZeroAddress());
        require(balanceOf(msg.sender, projectId) >= shares, LibErrors.InsufficientBalance());

        sA.lastRequestId++;
        requestId = sA.lastRequestId;

        sA.requestIdToAsyncFundsRequest[requestId] = LibAsyncFunds.AsyncFundsRequest({
            sharesRedeemed: shares,
            assetsSent: 0,
            receiver: receiver,
            user: msg.sender,
            projectId: projectId
        });

        _safeTransferFrom(msg.sender, address(this), projectId, shares, "");

        emit LibEvents.AsyncFundsRequest(msg.sender, projectId, receiver, requestId, shares);
    }

    function fullfilAsyncRequest(uint256 requestId)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 assets)
    {
        LibAsyncFunds.AsyncFundsStorage storage sA = LibAsyncFunds._getAsyncFundsStorage();
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();

        LibAsyncFunds.AsyncFundsRequest memory request = sA.requestIdToAsyncFundsRequest[requestId];
        require(request.receiver != address(0) && request.assetsSent == 0, LibErrors.InvalidRequest());
        // TODO: make sure we should use lastTotalAssets
        assets = _convertToAssets(request.sharesRedeemed, totalSupply(), sF.lastTotalAssets);
        sA.requestIdToAsyncFundsRequest[requestId].assetsSent = assets;
        _burn(address(this), request.projectId, request.sharesRedeemed);
        sF.underlyingAsset.safeTransfer(request.receiver, assets);
        emit LibEvents.AsyncFundsRequestFullfiled(request.user, request.projectId, request.receiver, requestId, assets);
    }

    /**
     * @dev Handle the receipt of a single ERC1155 token type.
     */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev Handle the receipt of multiple ERC1155 token types.
     */
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert LibErrors.NotSupported();
    }

    function totalSupply() public view override(FundsFacetBase, IFundsFacetBase) returns (uint256) {
        return super.totalSupply();
    }

    function totalSupply(uint256 id) public view override(FundsFacetBase, IFundsFacetBase) returns (uint256) {
        return super.totalSupply(id);
    }
}

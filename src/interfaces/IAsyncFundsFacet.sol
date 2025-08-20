// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import {IFundsFacetBase, StrategyArgs} from "./IFundsFacetBase.sol";

interface IAsyncFundsFacet is IFundsFacetBase, IERC1155Receiver {
    /**
     * @dev Requests async funds withdrawal.
     * @param shares The amount of shares to redeem.
     * @param projectId The project ID.
     * @param receiver The address of the receiver.
     */
    function requestAsyncFunds(uint256 shares, uint256 projectId, address receiver)
        external
        returns (uint256 requestId);

    /**
     * @dev Fulfills an async funds request.
     * @dev Callable by FUNDS_OPERATOR.
     * @param requestId The request ID to fulfill.
     */
    function fullfilAsyncRequest(uint256 requestId) external returns (uint256 amount);
}

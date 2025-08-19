// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IFundsFacetBase} from "./IFundsFacetBase.sol";

interface IFundsFacet is IFundsFacetBase {
    /**
     * @dev Redeems shares from the contract.
     * @param shares The amount of shares to redeem.
     * @param projectId The project ID.
     * @param receiver The address of the receiver.
     * @return assets The amount of assets redeemed.
     */
    function redeem(uint256 shares, uint256 projectId, address receiver) external returns (uint256 assets);
}

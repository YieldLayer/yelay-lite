// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {YieldExtractor} from "src/YieldExtractor.sol";

contract MockYieldExtractor {
    uint256 constant YIELD_PROJECT_ID = 0;

    uint256 toClaim;

    function setToClaim(uint256 value) external {
        toClaim = value;
    }

    function claim(YieldExtractor.ClaimRequest[] calldata data) external {
        IFundsFacet(data[0].yelayLiteVault).redeem(toClaim, YIELD_PROJECT_ID, msg.sender);
    }

    function transform(YieldExtractor.ClaimRequest[] calldata data) external {
        IFundsFacet(data[0].yelayLiteVault).transformYieldShares(data[0].projectId, toClaim, msg.sender);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155SupplyUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

import {LibOwner} from "src/libraries/LibOwner.sol";
import {LibFunds} from "src/libraries/LibFunds.sol";

contract MigrateToYieldExtractor is ERC1155SupplyUpgradeable {
    uint256 constant YIELD_SHARES_ID = 0;

    function transferYieldSharesToYieldExtractor(address newYieldExtractor, address testingDeployer) external {
        LibFunds.FundsStorage storage sF = LibFunds._getFundsStorage();
        address oldYieldExtractor = sF.yieldExtractor;

        uint256 yieldSharesBalance = balanceOf(oldYieldExtractor, YIELD_SHARES_ID);
        require(yieldSharesBalance > 0, "ZeroYieldShares");

        uint256 yieldSharesTestingBalance;
        if (testingDeployer != address(0)) {
            yieldSharesTestingBalance = balanceOf(testingDeployer, YIELD_SHARES_ID);
        }

        uint256 yieldSharesTotalSupply = totalSupply(YIELD_SHARES_ID);
        uint256 yieldShares = (yieldSharesBalance + yieldSharesTestingBalance);
        require(yieldShares == yieldSharesTotalSupply, "YieldSharesMismatch");

        _safeTransferFrom(oldYieldExtractor, newYieldExtractor, YIELD_SHARES_ID, yieldSharesBalance, "");
        if (testingDeployer != address(0)) {
            _safeTransferFrom(testingDeployer, newYieldExtractor, YIELD_SHARES_ID, yieldSharesTestingBalance, "");
        }

        sF.yieldExtractor = newYieldExtractor;

        require(balanceOf(sF.yieldExtractor, YIELD_SHARES_ID) == yieldSharesTotalSupply, "NotAllYieldSharesTransferred");
    }
}

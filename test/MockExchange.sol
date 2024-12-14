// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Quote {
    uint256 fromAmount;
    uint256 toAmount;
}

contract MockExchange {
    mapping(address => mapping(address => Quote)) quotes;

    function setQuote(address from, address to, Quote calldata quote) external {
        quotes[from][to] = quote;
        quotes[to][from] = Quote(quote.toAmount, quote.fromAmount);
    }

    function swap(address from, address to, uint256 toTake) external {
        uint256 toGive = previewSwap(from, to, toTake);
        IERC20(from).transferFrom(msg.sender, address(this), toTake);
        IERC20(to).transfer(msg.sender, toGive);
    }

    function previewSwap(address from, address to, uint256 toTake) public view returns (uint256 toGive) {
        Quote memory quote = quotes[from][to];
        return (toTake * quote.toAmount) / quote.fromAmount;
    }
}

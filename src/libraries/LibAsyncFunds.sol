// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibAsyncFunds {
    struct AsyncFundsRequest {
        uint256 sharesRedeemed;
        uint256 assetsSent;
        address receiver;
        address user;
        uint256 projectId;
    }

    struct AsyncFundsStorage {
        mapping(uint256 => AsyncFundsRequest) requestIdToAsyncFundsRequest;
        uint256 lastRequestId;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.AsyncFundsFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AsyncFundsStorageLocation =
        0x364272b2965bc64f170b3489debb9ca7391a66217f68dac15312be3ae3353600;

    function _getAsyncFundsStorage() internal pure returns (AsyncFundsStorage storage $) {
        assembly {
            $.slot := AsyncFundsStorageLocation
        }
    }
}

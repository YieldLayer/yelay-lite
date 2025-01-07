// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibErrors} from "src/libraries/LibErrors.sol";

library LibPausable {
    /// @custom:storage-location erc7201:yelay-vault.storage.Pausable
    struct PausableStorage {
        mapping(bytes4 => bool) selectorToPaused;
    }

    // keccak256(abi.encode(uint256(keccak256("yelay-vault.storage.Pausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PAUSABLE_STORAGE_LOCATION =
        0x63245fb7e3e0d2c2a6b753106e72e074a7694d950994c2caa5065a7b16bdb600;

    function _getPausableStorage() internal pure returns (PausableStorage storage $) {
        assembly {
            $.slot := PAUSABLE_STORAGE_LOCATION
        }
    }

    /**
     * @dev checks that called method is not paused
     */
    function _checkNotPaused() internal view {
        if (_getPausableStorage().selectorToPaused[msg.sig]) revert LibErrors.Paused(msg.sig);
    }
}

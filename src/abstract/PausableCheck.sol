// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibPausable} from "src/libraries/LibPausable.sol";

/**
 * @title PausableCheck
 * @dev Abstract contract that provides a modifier to check if the function is paused.
 */
abstract contract PausableCheck {
    /**
     * @dev Modifier to make a function callable only if it is not paused.
     */
    modifier notPaused() {
        LibPausable._checkNotPaused();
        _;
    }
}

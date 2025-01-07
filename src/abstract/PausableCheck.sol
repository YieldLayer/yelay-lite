// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibPausable} from "src/libraries/LibPausable.sol";

abstract contract PausableCheck {
    modifier notPaused() {
        LibPausable._checkNotPaused();
        _;
    }
}

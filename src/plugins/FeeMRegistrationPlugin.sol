// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title FeeMRegistrationPlugin
 * @notice Contract used for registering vaults on Sonic FeeM
 */
contract FeeMRegistrationPlugin {
    /**
     * @notice Register contract on Sonic FeeM
     */
    function registerMe() external {
        (bool _success,) = address(0xDC2B0D2Dd2b7759D97D50db4eabDC36973110830).call(
            abi.encodeWithSignature("selfRegister(uint256)", 137)
        );
        require(_success, "FeeM registration failed");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @notice Request data structure for claiming yield
 * @param yelayLiteVault Address of the YelayLite vault contract
 * @param projectId ID of the project in the vault
 * @param cycle Yield cycle number
 * @param yieldSharesTotal Total amount of yield shares to be claimed
 * @param proof Merkle proof array for verification
 */
struct ClaimRequest {
    address yelayLiteVault;
    uint256 projectId;
    uint256 cycle;
    uint256 yieldSharesTotal;
    bytes32[] proof;
}

interface IYieldExtractor {
    /**
     * @notice Transform yield shares to project shares on behalf of a user
     * @dev Callable only by the vault (data.yelayLiteVault)
     * @param data Claim request
     * @param user Owner of the shares to transform
     * @return toClaim The amount of shares transformed
     */
    function transformFor(ClaimRequest calldata data, address user) external returns (uint256 toClaim);
}

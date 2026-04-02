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

/**
 * @notice Merkle tree root data structure
 * @param hash Merkle root hash
 * @param blockNumber Block number at which yield share values were calculated
 */
struct Root {
    bytes32 hash;
    uint256 blockNumber;
}

interface IYieldExtractor {
    /**
     * @dev Returns the current cycle count for yield distributions for a given vault.
     * @param yelayLiteVault Address of the vault.
     * @return The current cycle count.
     */
    function cycleCount(address yelayLiteVault) external view returns (uint256);

    /**
     * @dev Returns the Merkle tree root for a given cycle and vault.
     * @param yelayLiteVault Address of the vault.
     * @param cycle The cycle number.
     * @return hash The Merkle root hash.
     * @return blockNumber The block number at which yield share values were calculated.
     */
    function roots(address yelayLiteVault, uint256 cycle) external view returns (bytes32 hash, uint256 blockNumber);

    /**
     * @dev Tracks whether a specific leaf has been claimed.
     * @param leaf The leaf hash.
     * @return True if the leaf has been claimed.
     */
    function isLeafClaimed(bytes32 leaf) external view returns (bool);

    /**
     * @dev Tracks yield shares claimed by users.
     * @param user The user address.
     * @param yelayLiteVault Address of the vault.
     * @param projectId The project ID.
     * @return The amount of yield shares claimed.
     */
    function yieldSharesClaimed(address user, address yelayLiteVault, uint256 projectId)
        external
        view
        returns (uint256);

    /**
     * @dev Pauses claiming.
     * @dev Callable by PAUSER.
     */
    function pause() external;

    /**
     * @dev Unpauses claiming.
     * @dev Callable by UNPAUSER.
     */
    function unpause() external;

    /**
     * @dev Adds a Merkle tree root for a new cycle for a given vault.
     * @dev Callable by YIELD_PUBLISHER.
     * @param root Root to add.
     * @param yelayLiteVault Address of the vault.
     */
    function addTreeRoot(Root memory root, address yelayLiteVault) external;

    /**
     * @dev Updates existing root for a given cycle for a given vault.
     * @dev Callable by YIELD_PUBLISHER.
     * @param root New root.
     * @param cycle Cycle to update.
     * @param yelayLiteVault Address of the vault.
     */
    function updateTreeRoot(Root memory root, uint256 cycle, address yelayLiteVault) external;

    /**
     * @dev Claims incentives by submitting Merkle proofs.
     * @param data Array of claim requests.
     */
    function claim(ClaimRequest[] calldata data) external;

    /**
     * @dev Transforms incentives to project shares by submitting a Merkle proof.
     * @param data Claim request.
     */
    function transform(ClaimRequest calldata data) external;

    /**
     * @dev Transforms yield shares to project shares on behalf of a user.
     * @dev Callable only by the vault (data.yelayLiteVault).
     * @param data Claim request.
     * @param user Owner of the shares to transform.
     */
    function transformFor(ClaimRequest calldata data, address user) external;

    /**
     * @dev Verifies a Merkle proof for a given claim request.
     * @param data Claim request to verify.
     * @param user User address for claim request.
     * @return True if the proof is valid.
     */
    function verify(ClaimRequest memory data, address user) external view returns (bool);
}

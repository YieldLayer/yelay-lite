// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {PausableUpgradeable} from "@openzeppelin-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ERC1155HolderUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LibEvents} from "src/libraries/LibEvents.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";

import {IFundsFacet} from "src/interfaces/IFundsFacet.sol";
import {IAsyncFundsFacet} from "src/interfaces/IAsyncFundsFacet.sol";

/**
 * @title YieldExtractor
 * @notice Contract for distributing yield to users through Merkle proofs
 * @dev This contract manages the distribution of yield shares to users based on their earned yield
 *      in the YelayLite vault system. The distribution happens through a Merkle tree system where:
 *      - A root manager (YIELD_PUBLISHER) periodically adds new Merkle roots containing user yield data
 *      - Each root represents a cycle of yield
 *      - Each vault has its own cycle count and root
 *      - Clients / Users can claim the yield by providing valid Merkle proofs
 *      - The contract tracks claimed yield to prevent double-claiming
 *      - Yield is distributed as the underlying token following direct redeemal of the shares on the vault.
 *
 * Key features:
 * - Merkle-based yield distribution system
 * - Cycle-based yield tracking
 * - Double-claim prevention
 * - Pausable claim functionality
 * - Upgradeable contract design
 */
contract YieldExtractor is
    PausableUpgradeable,
    ERC1155HolderUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 constant YIELD_PROJECT_ID = 0;

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

    /**
     * @notice Current cycle count for yield distributions per vault
     * @dev Mapping structure: vaultAddress => cycleCount
     */
    mapping(address => uint256) public cycleCount;

    /**
     * @notice Merkle tree root for each cycle per vault
     * @dev Mapping structure: vaultAddress => cycleCount => Root
     */
    mapping(address => mapping(uint256 => Root)) public roots;

    /**
     * @notice Tracks whether a specific leaf has been claimed
     */
    mapping(bytes32 => bool) public isLeafClaimed;

    /**
     * @notice Tracks yield shares claimed by users
     * @dev Mapping structure: user => yelayLiteVault => projectId => shares
     */
    mapping(address => mapping(address => mapping(uint256 => uint256))) public yieldSharesClaimed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the given owner.
     * @param owner The address of the owner.
     * @param _yieldPublisher The yield publisher address with rights to update Merkle root
     */
    function initialize(address owner, address _yieldPublisher) public initializer {
        __ERC1155Holder_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __AccessControlDefaultAdminRules_init(0, owner);

        _grantRole(LibRoles.YIELD_PUBLISHER, _yieldPublisher);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155HolderUpgradeable, AccessControlDefaultAdminRulesUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Pause claiming
     */
    function pause() external onlyRole(LibRoles.PAUSER) {
        _pause();
    }

    /**
     * @notice Unpause claiming
     */
    function unpause() external onlyRole(LibRoles.UNPAUSER) {
        _unpause();
    }

    /**
     * @notice Add a Merkle tree root for a new cycle for a given vault
     * @param root Root to add
     * @param yelayLiteVault Address of the vault
     */
    function addTreeRoot(Root memory root, address yelayLiteVault) external onlyRole(LibRoles.YIELD_PUBLISHER) {
        cycleCount[yelayLiteVault]++;
        roots[yelayLiteVault][cycleCount[yelayLiteVault]] = root;

        emit LibEvents.PoolRootAdded(yelayLiteVault, cycleCount[yelayLiteVault], root.hash, root.blockNumber);
    }

    /**
     * @notice Update existing root for a given cycle for a given vault
     * @param root New root
     * @param cycle Cycle to update
     * @param yelayLiteVault Address of the vault
     */
    function updateTreeRoot(Root memory root, uint256 cycle, address yelayLiteVault)
        external
        onlyRole(LibRoles.YIELD_PUBLISHER)
    {
        require(cycle <= cycleCount[yelayLiteVault], LibErrors.InvalidCycle());

        Root memory previousRoot = roots[yelayLiteVault][cycle];
        roots[yelayLiteVault][cycle] = root;

        emit LibEvents.PoolRootUpdated(yelayLiteVault, cycle, previousRoot.hash, root.hash, root.blockNumber);
    }

    /**
     * @notice Claim incentives by submitting a Merkle proof
     * @param data Array of claim requests
     */
    function claim(ClaimRequest[] calldata data) external whenNotPaused {
        for (uint256 i; i < data.length; ++i) {
            uint256 toClaim = _processClaimRequest(data[i], i);
            IFundsFacet(data[i].yelayLiteVault).redeem(toClaim, YIELD_PROJECT_ID, msg.sender);
            emit LibEvents.YieldClaimed(msg.sender, data[i].yelayLiteVault, data[i].projectId, data[i].cycle, toClaim);
        }
    }

    function request(ClaimRequest[] calldata data) external whenNotPaused {
        for (uint256 i; i < data.length; ++i) {
            uint256 toClaim = _processClaimRequest(data[i], i);
            uint256 requestId =
                IAsyncFundsFacet(data[i].yelayLiteVault).requestAsyncFunds(toClaim, YIELD_PROJECT_ID, msg.sender);
            emit LibEvents.YieldRequested(
                msg.sender, data[i].yelayLiteVault, data[i].projectId, data[i].cycle, toClaim, requestId
            );
        }
    }

    /**
     * @notice Transform incentives to projectId shares by submitting a Merkle proof
     * @param data Claim request
     */
    function transform(ClaimRequest calldata data) external whenNotPaused {
        uint256 toClaim = _processClaimRequest(data, 0);

        IFundsFacet(data.yelayLiteVault).transformYieldShares(data.projectId, toClaim, msg.sender);

        emit LibEvents.YieldTransformed(msg.sender, data.yelayLiteVault, data.projectId, data.cycle, toClaim);
    }

    /**
     * @notice Verify a Merkle proof for given claim request
     * @param data Claim request to verify
     * @param user User address for claim request
     */
    function verify(ClaimRequest memory data, address user) external view returns (bool) {
        return _verify(data, _getLeaf(data, user));
    }

    function _processClaimRequest(ClaimRequest memory data, uint256 i) internal returns (uint256) {
        bytes32 leaf = _getLeaf(data, msg.sender);
        require(!isLeafClaimed[leaf], LibErrors.ProofAlreadyClaimed(i));
        require(_verify(data, leaf), LibErrors.InvalidProof(i));

        isLeafClaimed[leaf] = true;

        uint256 alreadyClaimed = yieldSharesClaimed[msg.sender][data.yelayLiteVault][data.projectId];
        uint256 toClaim = data.yieldSharesTotal - alreadyClaimed;
        yieldSharesClaimed[msg.sender][data.yelayLiteVault][data.projectId] = data.yieldSharesTotal;

        return toClaim;
    }

    /**
     * @notice Verifies a Merkle proof for a claim request
     * @param data Claim request to verify
     * @param leaf Computed leaf node for verification
     * @return bool True if the proof is valid
     */
    function _verify(ClaimRequest memory data, bytes32 leaf) internal view returns (bool) {
        return MerkleProof.verify(data.proof, roots[data.yelayLiteVault][data.cycle].hash, leaf);
    }

    /**
     * @notice Computes the leaf node for a claim request
     * @param data Claim request data
     * @param user Address of the claiming user
     * @return bytes32 Computed leaf node
     */
    function _getLeaf(ClaimRequest memory data, address user) internal pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(abi.encode(user, data.cycle, data.yelayLiteVault, data.projectId, data.yieldSharesTotal))
            )
        );
    }

    /**
     * @dev UUPS upgrade authorization function.
     * Only the owner may upgrade.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}

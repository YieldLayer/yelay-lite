// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC1155HolderUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {ClientData, IClientsFacet} from "src/interfaces/IClientsFacet.sol";
import {LibErrors} from "./libraries/LibErrors.sol";
import {LibEvents} from "./libraries/LibEvents.sol";

/**
 * @title DepositLockPlugin
 * @dev Allows locking of deposits so that funds sent to a vault via this plugin remain locked until
 * the lock period expires. The project owner (as given by the vault's ClientsFacet) may update the project's
 * lock period. Each deposit records the time at which it was made (lockTime) and the unlock time is computed
 * dynamically as lockTime + projectLockPeriods[vault][projectId], allowing adjustments if the project's lock period changes.
 */
contract DepositLockPlugin is OwnableUpgradeable, ERC1155HolderUpgradeable, UUPSUpgradeable {
    /// @notice Maximum allowable lock period – 365 days.
    uint256 public constant MAX_LOCK_PERIOD = 365 days;

    /**
     * @custom:storage-location DepositLockPlugin.storage.lockedDeposits
     * @custom:member shares The amount of shares locked.
     * @custom:member lockTime The timestamp when the deposit was made.
     */
    struct Deposit {
        uint192 shares;
        uint64 lockTime;
    }

    /**
     * @dev Mapping: vault address => projectId => user address => array of deposits.
     * Each deposit record includes the locked share amount and the timestamp when it was recorded.
     */
    mapping(address => mapping(uint256 => mapping(address => Deposit[]))) public lockedDeposits;

    /**
     * @dev Mapping for the current lock period set for a project in a vault.
     * Only the project owner (as returned by the vault's ClientsFacet) may update this.
     */
    mapping(address => mapping(uint256 => uint256)) public projectLockPeriods;

    /**
     * @dev Mapping to track the pointer for each user's deposits so that redeemed deposits need not be shuffled.
     */
    mapping(address => mapping(uint256 => mapping(address => uint256))) private depositPointers;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with the given owner.
     * @param owner The address of the owner.
     */
    function initialize(address owner) public initializer {
        __Ownable_init(owner);
        __ERC1155Holder_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Updates the deposit lock period for a given project in a vault.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param lockPeriod New lock period (in seconds). Must be <= MAX_LOCK_PERIOD.
     */
    function updateLockPeriod(address vault, uint256 projectId, uint256 lockPeriod) external {
        // The vault is expected to implement the ClientsFacet so that we can verify the project owner.
        require(_isProjectOwner(vault, projectId), LibErrors.NotProjectOwner(projectId, msg.sender));
        require(lockPeriod <= MAX_LOCK_PERIOD, LibErrors.LockPeriodExceedsMaximum(lockPeriod));

        projectLockPeriods[vault][projectId] = lockPeriod;
        emit LibEvents.LockPeriodUpdated(vault, projectId, lockPeriod);
    }

    /**
     * @notice Deposits assets into the vault via this plugin and locks the resulting vault shares.
     * @param vault The vault address.
     * @param assets The amount of underlying assets to deposit.
     * @param projectId The project identifier.
     * @return shares The amount of vault shares received.
     */
    function depositLocked(address vault, uint256 assets, uint256 projectId) external returns (uint256 shares) {
        address underlyingAsset = IYelayLiteVault(vault).underlyingAsset();
        IERC20(underlyingAsset).transferFrom(msg.sender, address(this), assets);
        IERC20(underlyingAsset).approve(vault, assets);
        shares = IYelayLiteVault(vault).deposit(assets, projectId, address(this));

        _addLockedDeposit(vault, projectId, shares);

        emit LibEvents.DepositLocked(vault, projectId, msg.sender, shares);
    }

    /**
     * @notice Redeems vault shares that have matured (i.e. whose lock period has expired) for the user.
     * Uses pointer-style logic so that deposits remain in the original order.
     * @param vault The vault address.
     * @param sharesToRedeem The amount of shares the user wishes to redeem.
     * @param projectId The project identifier.
     * @return assets The amount of underlying assets redeemed.
     */
    function redeemLocked(address vault, uint256 sharesToRedeem, uint256 projectId) external returns (uint256 assets) {
        _removeShares(vault, projectId, sharesToRedeem, true);

        assets = IYelayLiteVault(vault).redeem(sharesToRedeem, projectId, msg.sender);

        emit LibEvents.RedeemLocked(vault, projectId, msg.sender, sharesToRedeem, assets);
    }

    /**
     * @notice Migrates locked shares from one project to another.
     * Removes the specified amount of locked shares from the "from" project
     * and creates a new deposit record in the "to" project with a fresh lock time.
     *
     * Requirements:
     * - The destination project must have a lock period set.
     * - The user must have at least `shares` locked in the source project.
     *
     * @param vault The vault address.
     * @param fromProjectId The source project ID.
     * @param toProjectId The destination project ID.
     * @param shares The amount of locked shares to migrate.
     */
    function migrateLocked(address vault, uint256 fromProjectId, uint256 toProjectId, uint256 shares) external {
        _removeShares(vault, fromProjectId, shares, false);

        _addLockedDeposit(vault, toProjectId, shares);

        emit LibEvents.MigrateLocked(msg.sender, fromProjectId, toProjectId, shares);
    }

    /**
     * @notice Returns the total matured vault shares for a user in a given vault and project.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param user The address of the user.
     * @return totalMatured The total matured vault shares for the user.
     */
    function getMaturedShares(address vault, uint256 projectId, address user)
        external
        view
        returns (uint256 totalMatured)
    {
        Deposit[] storage deposits = lockedDeposits[vault][projectId][user];
        uint256 pointer = depositPointers[vault][projectId][user];
        uint256 lockPeriod = projectLockPeriods[vault][projectId];
        for (uint256 i = pointer; i < deposits.length; i++) {
            if (!isMatured(deposits[i].lockTime, lockPeriod)) {
                break;
            }
            totalMatured += deposits[i].shares;
        }
    }

    /**
     * @notice Checks specific deposit record indices for whether the lock has expired.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param user The address of the user.
     * @param indices Array of deposit indices to check.
     * @return statuses A boolean array indicating if the corresponding deposit is matured.
     */
    function checkLocks(address vault, uint256 projectId, address user, uint256[] calldata indices)
        external
        view
        returns (bool[] memory statuses)
    {
        Deposit[] storage deposits = lockedDeposits[vault][projectId][user];
        uint256 lockPeriod = projectLockPeriods[vault][projectId];
        statuses = new bool[](indices.length);
        for (uint256 i = 0; i < indices.length; i++) {
            statuses[i] = isMatured(deposits[indices[i]].lockTime, lockPeriod);
        }
    }

    /**
     * @dev Internal helper function to determine if the caller is the project owner.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @return True if the caller is the project owner, false otherwise.
     */
    function _isProjectOwner(address vault, uint256 projectId) internal view returns (bool) {
        ClientData memory clientData = IClientsFacet(vault).ownerToClientData(msg.sender);
        return clientData.minProjectId <= projectId && projectId <= clientData.maxProjectId;
    }

    /**
     * @dev Internal helper function to remove a shares from a user's locked deposits.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param shares The amount of shares to remove.
     * @param isRedeem Whether the shares are being redeemed. In this case, we check for maturity
     *                 of the deposit containing the shares, and stop if it is not matured.
     */
    function _removeShares(address vault, uint256 projectId, uint256 shares, bool isRedeem) internal {
        uint256 pointer = depositPointers[vault][projectId][msg.sender];
        Deposit[] storage deposits = lockedDeposits[vault][projectId][msg.sender];
        uint256 lockPeriod;
        if (isRedeem) lockPeriod = projectLockPeriods[vault][projectId];
        uint256 remaining = shares;

        while (pointer < deposits.length && remaining > 0) {
            Deposit storage deposit = deposits[pointer];

            // When redeeming, once we encounter a deposit that is not matured, we stop.
            if (isRedeem && (!isMatured(deposit.lockTime, lockPeriod))) {
                break;
            }

            if (remaining < deposit.shares) {
                deposit.shares = uint192(deposit.shares - remaining);
                remaining = 0;
            } else {
                remaining -= deposit.shares;
                deposit.shares = 0;
                pointer++;
            }
        }
        require(remaining == 0, LibErrors.NotEnoughShares(shares, shares - remaining));
        depositPointers[vault][projectId][msg.sender] = pointer;
    }

    /**
     * @dev Internal helper function to add a locked deposit record for a user.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param shares The amount of shares to lock.
     */
    function _addLockedDeposit(address vault, uint256 projectId, uint256 shares) internal {
        uint256 lockPeriod = projectLockPeriods[vault][projectId];
        require(lockPeriod > 0, LibErrors.DepositLockNotSetForProject(projectId));

        lockedDeposits[vault][projectId][msg.sender].push(
            Deposit({shares: uint192(shares), lockTime: uint64(block.timestamp)})
        );
    }

    /**
     * @dev Internal helper function to determine if a deposit has matured.
     * @param lockTime The timestamp when the deposit was made.
     * @param lockPeriod The lock period for the project.
     * @return True if the deposit has matured, false otherwise.
     */
    function isMatured(uint256 lockTime, uint256 lockPeriod) internal view returns (bool) {
        return block.timestamp >= lockTime + lockPeriod;
    }

    /**
     * @dev UUPS upgrade authorization function.
     * Only the owner may upgrade.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC1155HolderUpgradeable} from
    "@openzeppelin-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {IYelayLiteVault} from "src/interfaces/IYelayLiteVault.sol";
import {ClientData, IClientsFacet} from "src/interfaces/IClientsFacet.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {LibEvents} from "src/libraries/LibEvents.sol";

/**
 * @title DepositLockPlugin
 * @dev Allows locking of deposits so that funds sent to a vault via this plugin remain locked until
 * some lock period expires. The project owner (as given by the vault's ClientsFacet) may update the project's
 * lock period. In Variable mode, each deposit is recorded with a timestamp.
 *
 * In Global mode, all deposits share the same unlock time so we optimize by simply tracking a single
 * aggregated shares value per (vault, project, user).
 *
 * There are two available active lock modes (See LockMode). Every vault–projectId is assigned a LockMode
 * (Unset, Variable, Global) on the first admin update. Subsequently, the owner may update the value for the
 * chosen mode, but cannot switch between active modes.
 */
contract DepositLockPlugin is OwnableUpgradeable, ERC1155HolderUpgradeable, UUPSUpgradeable {
    using SafeTransferLib for ERC20;

    /// @notice Maximum allowable lock period – 365 days.
    uint256 public constant MAX_LOCK_PERIOD = 365 days;

    /**
     * @notice Enumeration for lock mode.
     * @custom:member Unset The lock mode has not been set.
     * @custom:member Variable The lock period is set 'per deposit' - the unlock time is computed as lockTime +
     *                   projectLockPeriods[vault][projectId].
     * @custom:member Global The lock period is set 'per project' - a single aggregated shares value is maintained.
     */
    enum LockMode {
        Unset,
        Variable,
        Global
    }

    /**
     * @custom:member shares The amount of shares locked.
     * @custom:member lockTime The timestamp when the deposit was made.
     */
    struct Deposit {
        uint192 shares;
        uint64 lockTime;
    }

    /**
     * @dev Mapping for Variable mode: vault => projectId => user => array of deposits.
     * Each deposit record includes the locked share amount and the timestamp when it was recorded.
     */
    mapping(address => mapping(uint256 => mapping(address => Deposit[]))) public lockedDeposits;

    /**
     * @dev Mapping for Global mode: vault => projectId => user => total locked shares.
     */
    mapping(address => mapping(uint256 => mapping(address => uint256))) public globalLockedShares;

    /**
     * @dev Mapping for the current lock period set for a project in a vault.
     * Used when the project is in Variable mode.
     */
    mapping(address => mapping(uint256 => uint256)) public projectLockPeriods;

    /**
     * @dev Mapping for the global unlock time set for a project in a vault.
     * Used when the project is in Global mode.
     */
    mapping(address => mapping(uint256 => uint256)) public projectGlobalUnlockTime;

    /**
     * @dev Mapping for the lock mode assigned to a project in a vault.
     * Once set, the mode cannot be changed.
     */
    mapping(address => mapping(uint256 => LockMode)) public projectLockModes;

    /**
     * @dev Mapping to track the pointer for each user's deposits (for Variable mode)
     * so that redeemed deposits need not be shuffled.
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
        require(_isProjectOwner(vault, projectId), LibErrors.NotProjectOwner(vault, projectId, msg.sender));
        require(lockPeriod <= MAX_LOCK_PERIOD, LibErrors.LockPeriodExceedsMaximum(lockPeriod));
        _setOrValidateLockMode(vault, projectId, LockMode.Variable);

        projectLockPeriods[vault][projectId] = lockPeriod;
        emit LibEvents.LockPeriodUpdated(vault, projectId, lockPeriod);
    }

    /**
     * @notice Updates the global unlock time for a given project in a vault.
     * @dev - If a global unlock time is set, it takes precedence over per-deposit lock periods.
     *         - Once a mode is set, it cannot be changed.
     * @param vault The address of the vault.
     * @param projectId The project identifier.
     * @param unlockTime The new global unlock time. Must be non-zero.
     */
    function updateGlobalUnlockTime(address vault, uint256 projectId, uint256 unlockTime) external {
        require(_isProjectOwner(vault, projectId), LibErrors.NotProjectOwner(vault, projectId, msg.sender));
        _setOrValidateLockMode(vault, projectId, LockMode.Global);

        projectGlobalUnlockTime[vault][projectId] = unlockTime;
        emit LibEvents.GlobalUnlockTimeUpdated(vault, projectId, unlockTime);
    }

    /**
     * @notice Deposits assets into the vault via this plugin and locks the resulting vault shares.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param assets The amount of underlying assets to deposit.
     * @return shares The amount of vault shares received.
     */
    function depositLocked(address vault, uint256 projectId, uint256 assets) external returns (uint256 shares) {
        uint256 globalUnlockTime = projectGlobalUnlockTime[vault][projectId];
        if (globalUnlockTime > 0) {
            require(block.timestamp < globalUnlockTime, LibErrors.GlobalUnlockTimeReached(globalUnlockTime));
        }
        address underlyingAsset = IYelayLiteVault(vault).underlyingAsset();
        ERC20(underlyingAsset).safeTransferFrom(msg.sender, address(this), assets);
        ERC20(underlyingAsset).safeApprove(vault, assets);
        shares = IYelayLiteVault(vault).deposit(assets, projectId, address(this));

        _addLockedDeposit(vault, projectId, shares);

        emit LibEvents.DepositLocked(msg.sender, vault, projectId, shares, assets);
    }

    /**
     * @notice Redeems vault shares that have matured (i.e. whose lock period has expired) for the user.
     * Uses pointer-style logic for Variable mode, and direct subtraction for Global mode.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param shares The amount of shares the user wishes to redeem.
     * @return assets The amount of underlying assets redeemed.
     */
    function redeemLocked(address vault, uint256 projectId, uint256 shares) external returns (uint256 assets) {
        _removeShares(vault, projectId, shares);

        assets = IYelayLiteVault(vault).redeem(shares, projectId, msg.sender);

        emit LibEvents.RedeemLocked(msg.sender, vault, projectId, shares, assets);
    }

    /**
     * @notice Migrates locked shares from one project to another.
     * Removes the specified amount of locked shares from the "from" project
     * and creates a new deposit record in the "to" project with a fresh lock time.
     *
     * Requirements:
     * - The destination project must have a lock configuration set.
     * - The user must have at least `shares` matured.
     *
     * @param vault The vault address.
     * @param fromProjectId The source project ID.
     * @param toProjectId The destination project ID.
     * @param shares The amount of locked shares to migrate.
     */
    function migrateLocked(address vault, uint256 fromProjectId, uint256 toProjectId, uint256 shares) external {
        _removeShares(vault, fromProjectId, shares);
        _addLockedDeposit(vault, toProjectId, shares);

        IYelayLiteVault(vault).migratePosition(fromProjectId, toProjectId, shares);

        emit LibEvents.MigrateLocked(msg.sender, vault, fromProjectId, toProjectId, shares);
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
        LockMode mode = projectLockModes[vault][projectId];
        if (mode == LockMode.Global) {
            totalMatured = _getMaturedSharesGlobal(vault, projectId, user);
        } else if (mode == LockMode.Variable) {
            totalMatured = _getMaturedSharesVariable(vault, projectId, user);
        } else {
            revert LibErrors.LockModeNotSetForProject(vault, projectId);
        }
    }

    /**
     * @notice Checks specific deposit record indices for whether the lock has expired.
     * Applicable for Variable mode.
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
            statuses[i] = _isMatured(deposits[indices[i]].lockTime, lockPeriod);
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
     * @dev Internal helper function to remove locked shares from a user's deposits.
     * Delegates to the appropriate function based on the project's lock mode.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param shares The amount of shares to remove.
     */
    function _removeShares(address vault, uint256 projectId, uint256 shares) internal {
        LockMode mode = projectLockModes[vault][projectId];
        if (mode == LockMode.Global) {
            _removeSharesGlobal(vault, projectId, shares);
        } else if (mode == LockMode.Variable) {
            _removeSharesVariable(vault, projectId, shares);
        } else {
            revert LibErrors.LockModeNotSetForProject(vault, projectId);
        }
    }

    /**
     * @dev Internal helper function to remove shares in Variable mode.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param shares The amount of shares to remove.
     */
    function _removeSharesVariable(address vault, uint256 projectId, uint256 shares) internal {
        uint256 pointer = depositPointers[vault][projectId][msg.sender];
        Deposit[] storage deposits = lockedDeposits[vault][projectId][msg.sender];
        uint256 lockPeriod = projectLockPeriods[vault][projectId];
        uint256 remaining = shares;
        while (pointer < deposits.length && remaining > 0) {
            Deposit storage deposit = deposits[pointer];
            if (!_isMatured(deposit.lockTime, lockPeriod)) {
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
     * @dev Internal helper function to remove shares in Global mode.
     * For Global mode, we simply subtract from the aggregated locked shares.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param shares The amount of shares to remove.
     */
    function _removeSharesGlobal(address vault, uint256 projectId, uint256 shares) internal {
        require(
            block.timestamp >= projectGlobalUnlockTime[vault][projectId],
            LibErrors.GlobalUnlockTimeNotReached(projectGlobalUnlockTime[vault][projectId])
        );
        uint256 current = globalLockedShares[vault][projectId][msg.sender];
        require(current >= shares, LibErrors.NotEnoughShares(shares, current));
        unchecked {
            globalLockedShares[vault][projectId][msg.sender] = current - shares;
        }
    }

    /**
     * @dev Internal helper function to add a locked deposit record for a user.
     * For Global mode, this increments the stored locked shares.
     * For Variable mode, it pushes a new deposit record.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param shares The amount of shares to lock.
     */
    function _addLockedDeposit(address vault, uint256 projectId, uint256 shares) internal {
        if (projectLockModes[vault][projectId] == LockMode.Global) {
            globalLockedShares[vault][projectId][msg.sender] += shares;
        } else if (projectLockModes[vault][projectId] == LockMode.Variable) {
            lockedDeposits[vault][projectId][msg.sender].push(
                Deposit({shares: uint192(shares), lockTime: uint64(block.timestamp)})
            );
        } else {
            revert LibErrors.LockModeNotSetForProject(vault, projectId);
        }
    }

    /**
     * @dev Internal helper function to get matured shares in Variable mode.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param user The address of the user.
     * @return totalMatured The total matured shares.
     */
    function _getMaturedSharesVariable(address vault, uint256 projectId, address user)
        internal
        view
        returns (uint256 totalMatured)
    {
        Deposit[] storage deposits = lockedDeposits[vault][projectId][user];
        uint256 pointer = depositPointers[vault][projectId][user];
        uint256 lockPeriod = projectLockPeriods[vault][projectId];
        for (uint256 i = pointer; i < deposits.length; i++) {
            if (!_isMatured(deposits[i].lockTime, lockPeriod)) {
                break;
            }
            totalMatured += deposits[i].shares;
        }
    }

    /**
     * @dev Internal helper function to get matured shares in Global mode.
     * In Global mode, if the global unlock time is reached, all locked shares are matured.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param user The address of the user.
     * @return totalMatured The total matured shares.
     */
    function _getMaturedSharesGlobal(address vault, uint256 projectId, address user)
        internal
        view
        returns (uint256 totalMatured)
    {
        if (block.timestamp < projectGlobalUnlockTime[vault][projectId]) {
            return 0;
        }
        return globalLockedShares[vault][projectId][user];
    }

    /**
     * @dev Internal helper function to determine if a deposit has matured.
     * @param lockTime The timestamp when the deposit was made.
     * @param lockPeriod The lock period for the project.
     * @return True if the deposit has matured, false otherwise.
     */
    function _isMatured(uint256 lockTime, uint256 lockPeriod) internal view returns (bool) {
        return block.timestamp >= lockTime + lockPeriod;
    }

    /**
     * @dev Internal helper function to set the lock mode if not already set, or validate the already set mode otherwise.
     * @param vault The vault address.
     * @param projectId The project identifier.
     * @param mode The lock mode to set/validate.
     */
    function _setOrValidateLockMode(address vault, uint256 projectId, LockMode mode) internal {
        if (projectLockModes[vault][projectId] == LockMode.Unset) {
            projectLockModes[vault][projectId] = mode;
        } else {
            require(
                projectLockModes[vault][projectId] == mode,
                LibErrors.LockModeAlreadySet(vault, projectId, uint256(mode))
            );
        }
    }

    /**
     * @dev UUPS upgrade authorization function.
     * Only the owner may upgrade.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

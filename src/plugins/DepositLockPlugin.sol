// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "src/interfaces/IYelayLiteVault.sol";

/// @notice emitted when the caller is not the vault owner
error NotVaultOwner(address vault, address caller);

/// @notice emitted when the lock period exceeds the maximum allowable period
error LockPeriodExceedsMaximum(uint256 lockPeriod);

/// @notice emitted when the lock period is not set for a vault
error DepositLockNotSetForVault(address vault);

/// @notice emitted when the requested shares to redeem exceed the matured shares available
error NotEnoughMaturedShares(uint256 requested, uint256 available);

/**
 * @title DepositLockPlugin
 * @dev Allows locking of deposits so that funds sent to a vault via this plugin remain locked until
 * the lock period expires. The vault's owner (as given by IYelayLiteVault(vault).owner()) can update the vault's
 * lock period. Each deposit saves the time it was locked (lockTime), and the unlock period is computed
 * dynamically (deposit.lockTime + vaultLockPeriods[vault]), allowing adjustments if the vault's period changes.
 */
contract DepositLockPlugin is Ownable, ERC1155Holder {
    /// @notice Maximum allowable lock period – 365 days.
    uint256 public constant MAX_LOCK_PERIOD = 365 days;

    struct Deposit {
        uint256 shares;
        uint256 lockTime; // Timestamp when the deposit was made
    }

    /**
     * @dev Mapping: vault address => projectId => user address => array of deposits.
     * Each deposit record includes the locked share amount and the timestamp when it was recorded.
     */
    mapping(address => mapping(uint256 => mapping(address => Deposit[]))) public lockedDeposits;

    /**
     * @dev Mapping for the current lock period set for a vault.
     * The vault's owner  (as given by IYelayLiteVault(vault).owner()) may update this period.
     */
    mapping(address => uint256) public vaultLockPeriods;

    event DepositLocked(
        address indexed vault, uint256 indexed projectId, address indexed user, uint256 shares, uint256 lockTime
    );
    event Redeemed(
        address indexed vault, uint256 indexed projectId, address indexed user, uint256 shares, uint256 assets
    );
    event LockPeriodUpdated(address indexed vault, uint256 lockPeriod);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Updates the deposit lock period for a given vault.
     * @param vault The address of the vault.
     * @param lockPeriod New lock period (in seconds). Must be <= MAX_LOCK_PERIOD.
     */
    function updateLockPeriod(address vault, uint256 lockPeriod) external {
        if (IYelayLiteVault(vault).owner() != msg.sender) {
            revert NotVaultOwner(vault, msg.sender);
        }
        if (lockPeriod > MAX_LOCK_PERIOD) {
            revert LockPeriodExceedsMaximum(lockPeriod);
        }

        vaultLockPeriods[vault] = lockPeriod;
        emit LockPeriodUpdated(vault, lockPeriod);
    }

    /**
     * @notice Deposits assets into the vault via this plugin and locks the resulting vault shares.
     * @param vault The vault address.
     * @param assets The amount of underlying assets to deposit.
     * @param projectId The project (or ERC1155 token) identifier.
     * @return shares The amount of vault shares received.
     */
    function depositLocked(address vault, uint256 assets, uint256 projectId) external returns (uint256 shares) {
        uint256 lockPeriod = vaultLockPeriods[vault];
        if (lockPeriod == 0) {
            revert DepositLockNotSetForVault(vault);
        }

        address underlying = IYelayLiteVault(vault).underlyingAsset();
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        IERC20(underlying).approve(vault, assets);

        shares = IYelayLiteVault(vault).deposit(assets, projectId, address(this));

        lockedDeposits[vault][projectId][msg.sender].push(Deposit({shares: shares, lockTime: block.timestamp}));

        emit DepositLocked(vault, projectId, msg.sender, shares, block.timestamp);
    }

    /**
     * @notice Redeems vault shares that have matured (i.e. whose lock period has expired) for the user.
     * @param vault The vault address.
     * @param sharesToRedeem The amount of shares the user wishes to redeem.
     * @param projectId The project identifier.
     * @return assets The amount of underlying assets redeemed.
     */
    function redeemLocked(address vault, uint256 sharesToRedeem, uint256 projectId) external returns (uint256 assets) {
        uint256 maturedShares = 0;
        Deposit[] storage deposits = lockedDeposits[vault][projectId][msg.sender];

        // Iterate over deposit records and compute each deposit's unlock time dynamically.
        // exit when enough shares have been found, or all deposits have been checked.
        for (uint256 i = 0; i < deposits.length && maturedShares != sharesToRedeem;) {
            uint256 depositUnlockTime = deposits[i].lockTime + vaultLockPeriods[vault];
            if (block.timestamp >= depositUnlockTime) {
                uint256 available = deposits[i].shares;
                uint256 toRedeem;

                if (maturedShares + available > sharesToRedeem) {
                    toRedeem = sharesToRedeem - maturedShares;
                    deposits[i].shares = available - toRedeem;
                    maturedShares += toRedeem;
                    break;
                } else {
                    toRedeem = available;
                    maturedShares += available;
                    // Remove this deposit record.
                    _removeDepositAtIndex(deposits, i);
                    continue;
                }
            }
            i++;
        }
        if (maturedShares != sharesToRedeem) {
            revert NotEnoughMaturedShares(sharesToRedeem, maturedShares);
        }

        assets = IYelayLiteVault(vault).redeem(sharesToRedeem, projectId, msg.sender);

        emit Redeemed(vault, projectId, msg.sender, sharesToRedeem, assets);
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
        uint256 currentLockPeriod = vaultLockPeriods[vault];
        for (uint256 i = 0; i < deposits.length; i++) {
            if (block.timestamp >= deposits[i].lockTime + currentLockPeriod) {
                totalMatured += deposits[i].shares;
            }
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
        uint256 currentLockPeriod = vaultLockPeriods[vault];
        statuses = new bool[](indices.length);
        for (uint256 i = 0; i < indices.length; i++) {
            statuses[i] = (block.timestamp >= deposits[indices[i]].lockTime + currentLockPeriod);
        }
    }

    /**
     * @dev Internal helper function to remove a deposit record from an array.
     * @param deposits The array of deposit records.
     * @param index The index from which to remove the deposit.
     */
    function _removeDepositAtIndex(Deposit[] storage deposits, uint256 index) internal {
        uint256 lastIndex = deposits.length - 1;
        if (index != lastIndex) {
            deposits[index] = deposits[lastIndex];
        }
        deposits.pop();
    }
}

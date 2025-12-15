// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {AccessFacet} from "src/facets/AccessFacet.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";

/*//////////////////////////////////////////////////////////////
                        DECENTRAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface IDecentralPool {
    function deposit(uint256 amount) external returns (uint256 tokenId);

    function requestYieldWithdrawal(uint256 tokenId) external;
    function executeYieldWithdrawal(uint256 tokenId) external;

    function requestPrincipalWithdrawal(uint256 tokenId) external;
    function executePrincipalWithdrawal(uint256 tokenId) external;

    function getYieldWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (uint256 amount, uint256 requestTimestamp, bool exists, bool approved);

    function getPrincipalWithdrawalRequest(uint256 tokenId)
        external
        view
        returns (
            uint256 amount,
            uint256 requestTimestamp,
            uint256 availableTimestamp,
            bool exists,
            bool approved
        );

    function stablecoinAddress() external view returns (address);

    function pendingRewards(uint256 tokenId) external view returns (uint256);

    /// Pool exposes the NFT contract that is the source of truth for principal (and other accounting fields).
    function poolToken() external view returns (address);
}

/// PoolToken / position NFT interface (authoritative principal).
/// NOTE: Adjust return tuple if PoolToken.getTokenInfo() differs in your deployed version.
/// We only need the first value (principal).
interface IPoolToken {
    function getTokenInfo(uint256 tokenId)
        external
        view
        returns (
            uint256 principal,
            uint256 /*createdAt*/,
            uint256 /*rewardDebt*/,
            uint256 /*reserved*/,
            uint256 /*reserved*/
        );
}

/*//////////////////////////////////////////////////////////////
                        STORAGE LIBRARY
//////////////////////////////////////////////////////////////*/

library LibAsyncDecentral {
    bytes32 internal constant STORAGE_POSITION = keccak256("yelay.async.decentral.storage");

    struct Position {
        uint256 tokenId;

        // Cache only (fallback/analytics). NOT source of truth.
        uint256 cachedPrincipal;

        bool yieldRequested;
        bool principalRequested;

        // Local workflow flag. Must never be used to zero out economic value.
        // Only set true once authoritative principal is zero (best-effort).
        bool closed;
    }

    struct Storage {
        mapping(uint256 => Position) positions; // projectId => position
    }

    function store() internal pure returns (Storage storage s) {
        bytes32 p = STORAGE_POSITION;
        assembly {
            s.slot := p
        }
    }
}

/*//////////////////////////////////////////////////////////////
                    DECENTRAL STRATEGY FACET
//////////////////////////////////////////////////////////////*/

contract DecentralStrategyFacet is AccessFacet {
    using SafeTransferLib for ERC20;

    /// Base Decentral pool on the target chain.
    IDecentralPool public constant DECENTRAL_POOL =
        IDecentralPool(0x6fC42888f157A772968CaB5B95A4e42a38C07fD0);

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _stable() internal view returns (ERC20) {
        return ERC20(DECENTRAL_POOL.stablecoinAddress());
    }

    function _poolToken() internal view returns (IPoolToken) {
        return IPoolToken(DECENTRAL_POOL.poolToken());
    }

    function _authoritativePrincipal(uint256 tokenId) internal view returns (uint256 principal) {
        (principal,,,,) = _poolToken().getTokenInfo(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function decentralDeposit(uint256 projectId, uint256 amount) external onlyRole(LibRoles.FUNDS_OPERATOR) {
        if (amount == 0) revert LibErrors.ZeroAmount();

        LibAsyncDecentral.Position storage p = LibAsyncDecentral.store().positions[projectId];

        // One NFT per projectId; must be closed (or never created) to deposit again.
        if (p.tokenId != 0 && !p.closed) revert("DECENTRAL_INVALID_STATE");

        ERC20 stable = _stable();

        // Safer approve pattern for non-standard ERC20s.
        stable.safeApprove(address(DECENTRAL_POOL), 0);
        stable.safeApprove(address(DECENTRAL_POOL), amount);

        uint256 tokenId = DECENTRAL_POOL.deposit(amount);

        // Reset state machine.
        p.tokenId = tokenId;
        p.cachedPrincipal = amount; // cache only
        p.yieldRequested = false;
        p.principalRequested = false;
        p.closed = false;
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD WITHDRAWAL (ASYNC)
    //////////////////////////////////////////////////////////////*/

    function requestDecentralYield(uint256 projectId) external onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibAsyncDecentral.Position storage p = LibAsyncDecentral.store().positions[projectId];

        if (p.tokenId == 0 || p.yieldRequested) revert("DECENTRAL_INVALID_STATE");

        DECENTRAL_POOL.requestYieldWithdrawal(p.tokenId);
        p.yieldRequested = true;
    }

    function finalizeDecentralYield(uint256 projectId)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received)
    {
        LibAsyncDecentral.Position storage p = LibAsyncDecentral.store().positions[projectId];

        if (p.tokenId == 0 || !p.yieldRequested) revert("DECENTRAL_INVALID_STATE");

        (, , bool exists, bool approved) = DECENTRAL_POOL.getYieldWithdrawalRequest(p.tokenId);
        if (!exists || !approved) revert("DECENTRAL_NOT_READY");

        ERC20 stable = _stable();
        uint256 balBefore = stable.balanceOf(address(this));
        DECENTRAL_POOL.executeYieldWithdrawal(p.tokenId);
        received = stable.balanceOf(address(this)) - balBefore;

        p.yieldRequested = false;
    }

    /*//////////////////////////////////////////////////////////////
                    PRINCIPAL WITHDRAWAL (ASYNC)
    //////////////////////////////////////////////////////////////*/

    function requestDecentralPrincipal(uint256 projectId) external onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibAsyncDecentral.Position storage p = LibAsyncDecentral.store().positions[projectId];

        if (p.tokenId == 0 || p.principalRequested) revert("DECENTRAL_INVALID_STATE");

        DECENTRAL_POOL.requestPrincipalWithdrawal(p.tokenId);
        p.principalRequested = true;
    }

    /// @dev Returns received amount and remaining principal (authoritative).
    /// Remaining principal can be > 0 due to partial redemptions, losses, or fees applied to principal.
    function finalizeDecentralPrincipal(uint256 projectId)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received, uint256 remainingPrincipal)
    {
        LibAsyncDecentral.Position storage p = LibAsyncDecentral.store().positions[projectId];

        if (p.tokenId == 0 || !p.principalRequested) revert("DECENTRAL_INVALID_STATE");

        (, , uint256 availableTs, bool exists, bool approved) = DECENTRAL_POOL.getPrincipalWithdrawalRequest(p.tokenId);

        if (!exists || !approved) revert("DECENTRAL_NOT_READY");
        if (block.timestamp < availableTs) revert("DECENTRAL_NOT_READY");

        ERC20 stable = _stable();
        uint256 balBefore = stable.balanceOf(address(this));
        DECENTRAL_POOL.executePrincipalWithdrawal(p.tokenId);
        received = stable.balanceOf(address(this)) - balBefore;

        // Re-sync principal from the authoritative NFT after execution.
        remainingPrincipal = _authoritativePrincipal(p.tokenId);
        p.cachedPrincipal = remainingPrincipal;

        // Mark closed only when principal is fully gone.
        if (remainingPrincipal == 0) {
            p.closed = true;
        }

        p.principalRequested = false;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW
    //////////////////////////////////////////////////////////////*/

    function decentralPosition(uint256 projectId) external view returns (LibAsyncDecentral.Position memory) {
        return LibAsyncDecentral.store().positions[projectId];
    }

    /// @dev Aligns with FundsFacetBase.totalAssets: report economic value, not workflow state.
    /// Principal is sourced from PoolToken (authoritative), yield from pool.pendingRewards.
    function totalAssets(uint256 projectId) external view returns (uint256 assets) {
        LibAsyncDecentral.Position memory p = LibAsyncDecentral.store().positions[projectId];

        if (p.tokenId == 0) return 0;

        uint256 principal;
        uint256 pendingYield;

        // Do not brick view if external call fails; fall back to cached principal.
        try _poolToken().getTokenInfo(p.tokenId) returns (uint256 pr, uint256, uint256, uint256, uint256) {
            principal = pr;
        } catch {
            principal = p.cachedPrincipal;
        }

        try DECENTRAL_POOL.pendingRewards(p.tokenId) returns (uint256 y) {
            pendingYield = y;
        } catch {
            pendingYield = 0;
        }

        return principal + pendingYield;
    }
}

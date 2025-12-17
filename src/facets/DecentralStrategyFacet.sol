// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {AccessFacet} from "src/facets/AccessFacet.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {IDecentralPool} from "src/interfaces/external/decentral/IDecentralPool.sol";


/*//////////////////////////////////////////////////////////////
                        DECENTRAL INTERFACES
//////////////////////////////////////////////////////////////*/



interface IPoolToken {
    function getTokenInfo(uint256 tokenId)
        external
        view
        returns (
            uint256 principal,
            uint256,
            uint256,
            uint256,
            uint256
        );
}

/*//////////////////////////////////////////////////////////////
                        STORAGE LIBRARY
//////////////////////////////////////////////////////////////*/

library LibAsyncDecentral {
    bytes32 internal constant STORAGE_POSITION =
        keccak256("yelay.async.decentral.storage");

    struct Position {
        uint256 tokenId;

        // Cached principal (NOT authoritative)
        uint256 cachedPrincipal;

        bool yieldRequested;
        bool principalRequested;

        // Workflow flag only
        bool closed;
    }

    struct Storage {
        Position position;
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

    function decentralDeposit(uint256 amount)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        if (amount == 0) revert LibErrors.ZeroAmount();

        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().position;

        if (p.tokenId != 0 && !p.closed) revert("DECENTRAL_INVALID_STATE");

        ERC20 stable = _stable();

        stable.safeApprove(address(DECENTRAL_POOL), 0);
        stable.safeApprove(address(DECENTRAL_POOL), amount);

        uint256 tokenId = DECENTRAL_POOL.deposit(amount);

        p.tokenId = tokenId;
        p.cachedPrincipal = amount;
        p.yieldRequested = false;
        p.principalRequested = false;
        p.closed = false;
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD WITHDRAWAL (ASYNC)
    //////////////////////////////////////////////////////////////*/

    function requestDecentralYield()
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().position;

        if (p.tokenId == 0 || p.yieldRequested) revert("DECENTRAL_INVALID_STATE");

        DECENTRAL_POOL.requestYieldWithdrawal(p.tokenId);
        p.yieldRequested = true;
    }

    function finalizeDecentralYield()
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received)
    {
        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().position;

        if (p.tokenId == 0 || !p.yieldRequested) revert("DECENTRAL_INVALID_STATE");

        (, , bool exists, bool approved) =
            DECENTRAL_POOL.getYieldWithdrawalRequest(p.tokenId);

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

    function requestDecentralPrincipal()
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().position;

        if (p.tokenId == 0 || p.principalRequested) revert("DECENTRAL_INVALID_STATE");

        DECENTRAL_POOL.requestPrincipalWithdrawal(p.tokenId);
        p.principalRequested = true;
    }

    function finalizeDecentralPrincipal()
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received, uint256 remainingPrincipal)
    {
        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().position;

        if (p.tokenId == 0 || !p.principalRequested) revert("DECENTRAL_INVALID_STATE");

        (, , uint256 availableTs, bool exists, bool approved) =
            DECENTRAL_POOL.getPrincipalWithdrawalRequest(p.tokenId);

        if (!exists || !approved) revert("DECENTRAL_NOT_READY");
        if (block.timestamp < availableTs) revert("DECENTRAL_NOT_READY");

        ERC20 stable = _stable();
        uint256 balBefore = stable.balanceOf(address(this));

        DECENTRAL_POOL.executePrincipalWithdrawal(p.tokenId);

        received = stable.balanceOf(address(this)) - balBefore;

        remainingPrincipal = _authoritativePrincipal(p.tokenId);
        p.cachedPrincipal = remainingPrincipal;

        if (remainingPrincipal == 0) {
            p.closed = true;
        }

        p.principalRequested = false;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW
    //////////////////////////////////////////////////////////////*/

    function decentralPosition()
        external
        view
        returns (LibAsyncDecentral.Position memory)
    {
        return LibAsyncDecentral.store().position;
    }

    function totalAssets()
        external
        view
        returns (uint256 assets)
    {
        LibAsyncDecentral.Position memory p =
            LibAsyncDecentral.store().position;

        if (p.tokenId == 0) return 0;

        uint256 principal;
        uint256 pendingYield;

        try _poolToken().getTokenInfo(p.tokenId)
            returns (uint256 pr, uint256, uint256, uint256, uint256)
        {
            principal = pr;
        } catch {
            principal = p.cachedPrincipal;
        }

        try DECENTRAL_POOL.pendingRewards(p.tokenId)
            returns (uint256 y)
        {
            pendingYield = y;
        } catch {
            pendingYield = 0;
        }

        return principal + pendingYield;
    }
}

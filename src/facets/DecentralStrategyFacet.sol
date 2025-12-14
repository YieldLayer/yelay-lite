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

}

/*//////////////////////////////////////////////////////////////
                        STORAGE LIBRARY
//////////////////////////////////////////////////////////////*/

library LibAsyncDecentral {
    bytes32 internal constant STORAGE_POSITION =
        keccak256("yelay.async.decentral.storage");

    struct Position {
        uint256 tokenId;
        uint256 principal;
        bool yieldRequested;
        bool principalRequested;
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

    IDecentralPool public constant DECENTRAL_POOL =
        IDecentralPool(0x6fC42888f157A772968CaB5B95A4e42a38C07fD0);

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _stable() internal view returns (ERC20) {
        return ERC20(DECENTRAL_POOL.stablecoinAddress());
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function decentralDeposit(uint256 projectId, uint256 amount)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        if (amount == 0) revert LibErrors.ZeroAmount();

        LibAsyncDecentral.Storage storage s = LibAsyncDecentral.store();
        LibAsyncDecentral.Position storage p = s.positions[projectId];

        if (p.tokenId != 0 && !p.closed) revert("DECENTRAL_INVALID_STATE");

        ERC20 stable = _stable();
        stable.safeApprove(address(DECENTRAL_POOL), amount);
        uint256 tokenId = DECENTRAL_POOL.deposit(amount);

        s.positions[projectId] = LibAsyncDecentral.Position({
            tokenId: tokenId,
            principal: amount,
            yieldRequested: false,
            principalRequested: false,
            closed: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD WITHDRAWAL (ASYNC)
    //////////////////////////////////////////////////////////////*/

    function requestDecentralYield(uint256 projectId)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().positions[projectId];

        if (p.closed || p.yieldRequested) revert("DECENTRAL_INVALID_STATE");

        DECENTRAL_POOL.requestYieldWithdrawal(p.tokenId);
        p.yieldRequested = true;
    }

    function finalizeDecentralYield(uint256 projectId)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received)
    {
        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().positions[projectId];

        if (!p.yieldRequested || p.closed) revert("DECENTRAL_INVALID_STATE");

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

    function requestDecentralPrincipal(uint256 projectId)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().positions[projectId];

        if (p.closed || p.principalRequested) revert("DECENTRAL_INVALID_STATE");

        DECENTRAL_POOL.requestPrincipalWithdrawal(p.tokenId);
        p.principalRequested = true;
    }

    function finalizeDecentralPrincipal(uint256 projectId)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received)
    {
        LibAsyncDecentral.Position storage p =
            LibAsyncDecentral.store().positions[projectId];

        if (!p.principalRequested || p.closed) revert("DECENTRAL_INVALID_STATE");

        (, , uint256 availableTs, bool exists, bool approved) =
            DECENTRAL_POOL.getPrincipalWithdrawalRequest(p.tokenId);

        if (!exists || !approved) revert("DECENTRAL_NOT_READY");
        if (block.timestamp < availableTs) revert("DECENTRAL_NOT_READY");

        ERC20 stable = _stable();
        uint256 balBefore = stable.balanceOf(address(this));
        DECENTRAL_POOL.executePrincipalWithdrawal(p.tokenId);
        received = stable.balanceOf(address(this)) - balBefore;

        p.closed = true;
        p.principal = 0;
        p.principalRequested = false;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW
    //////////////////////////////////////////////////////////////*/

    function decentralPosition(uint256 projectId)
        external
        view
        returns (LibAsyncDecentral.Position memory)
    {
        return LibAsyncDecentral.store().positions[projectId];
    }

    function totalAssets(uint256 projectId)
        external
        view
        returns (uint256 assets)
    {
        LibAsyncDecentral.Position memory p =
            LibAsyncDecentral.store().positions[projectId];

        if (p.closed || p.tokenId == 0) return 0;

        uint256 principal = p.principal;

        uint256 pendingYield =
            IDecentralPool(DECENTRAL_POOL).pendingRewards(p.tokenId);

        return principal + pendingYield;
    }

}

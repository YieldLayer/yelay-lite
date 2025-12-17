// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {AccessFacet} from "src/facets/AccessFacet.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {IDecentralPool} from "src/interfaces/external/decentral/IDecentralPool.sol";
import {LibFunds} from "src/libraries/LibFunds.sol";

/*//////////////////////////////////////////////////////////////
                        POOL TOKEN INTERFACE
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

    struct NFTPosition {
        uint256 tokenId;

        bool yieldRequested;
        bool principalRequested;

        bool closed;
    }

    struct Storage {
        NFTPosition[] positions;
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
        return LibFunds._getFundsStorage().underlyingAsset;
    }

    function _poolToken() internal view returns (IPoolToken) {
        return IPoolToken(DECENTRAL_POOL.poolToken());
    }

   function _principal(uint256 tokenId) internal view returns (uint256) {
        (uint256 p,,,,) = _poolToken().getTokenInfo(tokenId);
        return p;
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function decentralDeposit(uint256 amount)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
//        require(
//            _stable().balanceOf(address(this)) >= amount,
//            "VAULT_HAS_NO_FUNDS"
//        );

        if (amount == 0) revert LibErrors.ZeroAmount();

        ERC20 stable = _stable();

        require(address(stable) == DECENTRAL_POOL.stablecoinAddress(), "DECENTRAL_WRONG_STABLE");
        require(stable.balanceOf(address(this)) >= amount, "VAULT_HAS_NO_FUNDS");

        stable.safeApprove(address(DECENTRAL_POOL), 0);
        stable.safeApprove(address(DECENTRAL_POOL), amount);

        uint256 tokenId = DECENTRAL_POOL.deposit(amount);

        LibAsyncDecentral.store().positions.push(
            LibAsyncDecentral.NFTPosition({
                tokenId: tokenId,
                yieldRequested: false,
                principalRequested: false,
                closed: false
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD WITHDRAWAL (ASYNC)
    //////////////////////////////////////////////////////////////*/


    function requestDecentralYield(uint256 index)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {
        LibAsyncDecentral.NFTPosition storage p =
            LibAsyncDecentral.store().positions[index];

        if (p.closed || p.yieldRequested) revert("DECENTRAL_INVALID_STATE");
        DECENTRAL_POOL.requestYieldWithdrawal(p.tokenId);
        p.yieldRequested = true;
    }



    function finalizeDecentralYield(uint256 index)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received)
    {
        LibAsyncDecentral.NFTPosition storage p =
            LibAsyncDecentral.store().positions[index];
        if (p.closed || !p.yieldRequested) revert("DECENTRAL_INVALID_STATE");

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


    function requestDecentralPrincipal(uint256 index)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
    {

        LibAsyncDecentral.NFTPosition storage p =
            LibAsyncDecentral.store().positions[index];

        if (p.closed || p.principalRequested) revert("DECENTRAL_INVALID_STATE");

        DECENTRAL_POOL.requestPrincipalWithdrawal(p.tokenId);
        p.principalRequested = true;
    }



    function finalizeDecentralPrincipal(uint256 index)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received)
    {

        LibAsyncDecentral.NFTPosition storage p =
            LibAsyncDecentral.store().positions[index];
        if (p.closed || !p.principalRequested) revert("DECENTRAL_INVALID_STATE");


        (, , uint256 availableTs, bool exists, bool approved) =
            DECENTRAL_POOL.getPrincipalWithdrawalRequest(p.tokenId);

        if (!exists || !approved || block.timestamp < availableTs) {
            revert("DECENTRAL_NOT_READY");
        }

        ERC20 stable = _stable();
        uint256 balBefore = stable.balanceOf(address(this));
        DECENTRAL_POOL.executePrincipalWithdrawal(p.tokenId);
        received = stable.balanceOf(address(this)) - balBefore;

        if (_principal(p.tokenId) == 0) {
            p.closed = true;
        }

        p.principalRequested = false;
    }



    /*//////////////////////////////////////////////////////////////

                            VIEW

    //////////////////////////////////////////////////////////////*/



    function decentralPositions()
        external
        view
        returns (LibAsyncDecentral.NFTPosition[] memory)
    {
        return LibAsyncDecentral.store().positions;
    }


    function totalAssets() external view returns (uint256 assets) {
        LibAsyncDecentral.Storage storage s =
            LibAsyncDecentral.store();
        uint256 len = s.positions.length;

        for (uint256 i = 0; i < len; i++) {
            LibAsyncDecentral.NFTPosition memory p = s.positions[i];
            if (p.closed) continue;
            assets += _principal(p.tokenId);
            try DECENTRAL_POOL.pendingRewards(p.tokenId) returns (uint256 y) {
                assets += y;
            } catch {}
        }
    }


}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {AccessFacet} from "src/facets/AccessFacet.sol";
import {LibRoles} from "src/libraries/LibRoles.sol";
import {LibErrors} from "src/libraries/LibErrors.sol";
import {IDecentralPool} from "src/interfaces/external/decentral/IDecentralPool.sol";
import {LibFunds} from "src/libraries/LibFunds.sol";

import "forge-std/console2.sol";

/*//////////////////////////////////////////////////////////////
                        POOL TOKEN INTERFACE
//////////////////////////////////////////////////////////////*/

interface IPoolToken {
    struct TokenInfo {
        address pool;
        uint256 principalAmount;
        uint256 principalRedeemed;
        uint256 rewardDebt;
        uint256 createdAt;
        uint256 lastYieldPayoutTime;
    }

    function getTokenInfo(uint256 tokenId) external view returns (TokenInfo memory);
}

/*//////////////////////////////////////////////////////////////
                        STORAGE LIBRARY
//////////////////////////////////////////////////////////////*/

library LibAsyncDecentral {
    bytes32 internal constant STORAGE_POSITION = keccak256("yelay.async.decentral.storage");

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

    IDecentralPool public constant DECENTRAL_POOL = IDecentralPool(0x6fC42888f157A772968CaB5B95A4e42a38C07fD0);

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
        IPoolToken.TokenInfo memory info = _poolToken().getTokenInfo(tokenId);

        return info.principalAmount - info.principalRedeemed;
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function decentralDeposit(uint256 amount) external onlyRole(LibRoles.FUNDS_OPERATOR) {
        if (amount == 0) revert LibErrors.ZeroAmount();

        ERC20 stable = _stable();

        IDecentralPool pool = IDecentralPool(DECENTRAL_POOL);

        require(address(stable) == pool.stablecoinAddress(), "DECENTRAL_WRONG_STABLE");
        require(stable.balanceOf(address(this)) >= amount, "VAULT_HAS_NO_FUNDS");

        stable.safeApprove(address(pool), 0);
        stable.safeApprove(address(pool), amount);

        uint256 tokenId = pool.deposit(amount);

        LibAsyncDecentral.store().positions
            .push(
                LibAsyncDecentral.NFTPosition({
                    tokenId: tokenId, yieldRequested: false, principalRequested: false, closed: false
                })
            );
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD WITHDRAWAL (ASYNC)
    //////////////////////////////////////////////////////////////*/

    function requestDecentralYieldWithdrawal(uint256 index) external onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibAsyncDecentral.NFTPosition storage p = LibAsyncDecentral.store().positions[index];

        if (p.closed || p.yieldRequested) revert("DECENTRAL_INVALID_STATE");

        console2.log("DecentralStrategyFacet.finalizeDecentralYieldWithdrawal for:", p.tokenId);

        DECENTRAL_POOL.requestYieldWithdrawal(p.tokenId);
        p.yieldRequested = true;
    }

    function finalizeDecentralYieldWithdrawal(uint256 index)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received)
    {
        LibAsyncDecentral.NFTPosition storage p = LibAsyncDecentral.store().positions[index];
        if (p.closed || !p.yieldRequested) revert("DECENTRAL_INVALID_STATE");

        (,, bool exists, bool approved) = DECENTRAL_POOL.getYieldWithdrawalRequest(p.tokenId);

        if (!exists || !approved) revert("DECENTRAL_NOT_READY");

        console2.log("DecentralStrategyFacet.finalizeDecentralYieldWithdrawal for:", p.tokenId);

        ERC20 stable = _stable();
        uint256 balBefore = stable.balanceOf(address(this));
        DECENTRAL_POOL.executeYieldWithdrawal(p.tokenId);
        received = stable.balanceOf(address(this)) - balBefore;

        p.yieldRequested = false;
    }

    /*//////////////////////////////////////////////////////////////

                    PRINCIPAL WITHDRAWAL (ASYNC)

    //////////////////////////////////////////////////////////////*/

    function requestDecentralPrincipalWithdrawal(uint256 index) external onlyRole(LibRoles.FUNDS_OPERATOR) {
        LibAsyncDecentral.NFTPosition storage p = LibAsyncDecentral.store().positions[index];

        if (p.closed || p.principalRequested) revert("DECENTRAL_INVALID_STATE");

        console2.log("DecentralStrategyFacet.requestDecentralPrincipalWithdrawal for:", p.tokenId);

        DECENTRAL_POOL.requestPrincipalWithdrawal(p.tokenId);
        p.principalRequested = true;
    }

    function finalizeDecentralPrincipalWithdrawal(uint256 index)
        external
        onlyRole(LibRoles.FUNDS_OPERATOR)
        returns (uint256 received)
    {
        LibAsyncDecentral.NFTPosition storage p = LibAsyncDecentral.store().positions[index];
        if (p.closed || !p.principalRequested) revert("DECENTRAL_INVALID_STATE");

        console2.log("DecentralStrategyFacet.finalizeDecentralPrincipalWithdrawal for:", p.tokenId);

        (uint256 withdrawalAmount, uint256 requestTs, uint256 availableTs, bool exists, bool approved) =
            DECENTRAL_POOL.getPrincipalWithdrawalRequest(p.tokenId);

        console2.log("Facet.getPrincipalWithdrawalRequest withdrawalAmount:", withdrawalAmount);
        console2.log("Facet.getPrincipalWithdrawalRequest requestTs:", requestTs);
        console2.log("Facet.getPrincipalWithdrawalRequest availableTs:", availableTs);
        console2.log("Facet.getPrincipalWithdrawalRequest exists:", exists);
        console2.log("Facet.getPrincipalWithdrawalRequest approved:", approved);
        console2.log("Facet.getPrincipalWithdrawalRequest approved. Current timestamp:", block.timestamp);

        if (!exists || !approved) {
            revert("DECENTRAL_NOT_READY");
        }

        uint256 principalBefore = _principal(p.tokenId);
        console2.log("principalBefore:", principalBefore);

        ERC20 stable = _stable();
        uint256 balBefore = stable.balanceOf(address(this));
        console2.log("balBefore:", balBefore);

        console2.log("Facet. Calling executePrincipalWithdrawal for:", p.tokenId);
        DECENTRAL_POOL.executePrincipalWithdrawal(p.tokenId); //    This burn shares if successful
        received = stable.balanceOf(address(this)) - balBefore;
        console2.log("balAfter:", stable.balanceOf(address(this)));
        console2.log("received:", received);

        // 🔒 If principal was fully redeemed, token is now burned
        if (received >= principalBefore) {
            p.closed = true;
        }

        p.principalRequested = false;
    }

    /*//////////////////////////////////////////////////////////////

                            VIEW

    //////////////////////////////////////////////////////////////*/

    function decentralPositions() external view returns (LibAsyncDecentral.NFTPosition[] memory) {
        return LibAsyncDecentral.store().positions;
    }

    function totalAssets() external view returns (uint256 assets) {
        LibAsyncDecentral.Storage storage s = LibAsyncDecentral.store();
        uint256 len = s.positions.length;

        console2.log("TotalAssets(). s.positions.length = ", len);

        for (uint256 i = 0; i < len; i++) {
            LibAsyncDecentral.NFTPosition memory p = s.positions[i];
            if (p.closed) continue;
            console2.log("TotalAssets(). tokenID = ", p.tokenId);
            console2.log("TotalAssets(). principal = ", _principal(p.tokenId));
            assets += _principal(p.tokenId);
            try DECENTRAL_POOL.pendingRewards(p.tokenId) returns (uint256 y) {
                assets += y;
                console2.log("TotalAssets(). yield = ", y);
            } catch {}
        }
    }
}

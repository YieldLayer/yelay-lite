# ERC4626Plugin

## Overview
- Exposes a standard ERC4626 vault interface on top of a Yelay V3 vault so integrators can treat project shares as vanilla ERC20 shares.
- Handles all coordination with `YelayLiteVault`: for every ERC4626 deposit/mint the plugin deposits the underlying into the vault, and for every redeem/withdraw it unwinds positions and forwards assets to users.
- Bridges Yelay's ERC1155 project share model with ERC4626 semantics by tracking a `projectId` and managing share accounting on behalf of depositors.
- Provides optional yield operations (`accrue`, `skim`) so idle funds and harvested rewards get re-invested without requiring users to leave the ERC4626 surface.
- Each deployed plugin is bound 1:1 with a Yelay project and exposes it as its own ERC4626 vault.

## Contract Composition
- Inherits `ERC4626Upgradeable` for tokenised vault behaviour and `ERC1155HolderUpgradeable` to hold the underlying ERC1155 project shares minted by `YelayLiteVault`.
- Holds immutable reference to the shared `YieldExtractor`, allowing the plugin to transform Merkle-distributed yield into usable project shares.
- Maintains per-instance configuration for the bound `YelayLiteVault` address, the target `projectId`, and a decimals offset so share/asset conversions stay aligned even when the underlying token is non-18 decimals.

## Yield Management
- `accrue(YieldExtractor.ClaimRequest calldata data)` delegates to the global `YieldExtractor.transform`, which converts Merkle-authorised yield shares (project 0) into the plugin's project shares for the caller. This lets operators reinvest harvested yield directly from off-chain proofs.
- `skim()` detects loose underlying tokens sitting on the plugin and deposits them into the vault. A positive sweep emits `LibEvents.ERC4626PluginAssetsSkimmed`.

Together these functions keep idle balances minimal and allow automated yield re-compounding without leaving the ERC4626 interface.

## View Helpers
- `previewRedeem` / `previewWithdraw` mirror ERC4626 previews but pass through Yelay's multi-share accounting to give accurate estimates based on current vault share supply.
- `totalAssets` reports the sum of:
  - Assets currently invested via project shares (`convertToAssets(balanceOf(projectId))`), and
  - Loose underlying ERC20 held on the plugin.
- `maxWithdraw` inherits the ERC4626 limit logic while applying the protocol’s withdrawal margin.

## Integration Notes
- The plugin itself is the ERC4626 share minter/burner. External front ends should treat the plugin address as the vault contract, and interact with `deposit`, `mint`, `redeem`, and `withdraw` directly.
- All ERC20 approvals must target the plugin address, not the underlying `YelayLiteVault`.
- To surface protocol yield to users:
  1. Off-chain operators publish Merkle roots via the `YieldExtractor`.
  2. Operators call `accrue` with the relevant claim proof so yield shares are transformed to project shares owned by the plugin.
  3. Resulting value is reflected in `totalAssets`, so ERC4626 share price increases naturally.

## Security & Operational Considerations
- The plugin trusts the configured `YelayLiteVault` for accounting and fund custody.
- Rounding decisions (`Math.mulDiv` with floor/ceil) favour user safety during redemption/withdrawal but can create small residual shares; the withdrawal margin prevents the edge cases from reverting due to dust.
- `accrue` and `skim` are externally callable.

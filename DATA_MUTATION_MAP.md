# Phase D3 Data Mutation Map

Source of truth: `embedded_payload.bin`, SHA-256
`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

This document records the payload data-table mutation layer reconstructed in D3. Prototype
IDs are original bytecode structure identifiers. Helper names in source are semantic
reconstruction names unless an exact public/global name is explicitly stated.

## Runtime ownership after D3

| Feature key | Public entry | Runtime owner after payload init |
|---|---|---|
| `no_recoil` | exact global `set_dongdong_feature_config` | reconstructed source |
| `converge` | exact global `set_dongdong_feature_config` | reconstructed source |
| `aim` | exact global `set_dongdong_feature_config` | original embedded payload |
| `anti_shake` | exact global `set_dongdong_feature_config` | original embedded payload |

`src/spectra/payload_feature_bridge.lua` captures the original public global after the
byte-identical payload initializes. It dispatches only `no_recoil` and `converge` into
source. All other keys are delegated to the original payload closure.

## Reconstructed snapshot/table layer

| Prototype | Reconstructed source role |
|---|---|
| `0.29.10` | normalize identifier to lowercase alphanumeric |
| `0.29.11` | resolve `Facade.TableManager` / fallback `TableManager` |
| `0.29.12` | protected engine call helper |
| `0.29.13` | `TableManager:GetTable(name)` |
| `0.29.14` | create per-feature `{records, seen}` snapshot |
| `0.29.15` | snapshot old field once and assign replacement |
| `0.29.16` | clear one feature snapshot |
| `0.29.17` | restore one feature snapshot in reverse record order |
| `0.29.18` | userdata `TableExtend` conversion |
| `0.29.19` | safe field read + `TableExtend` conversion |
| `0.29.20` | protected table iteration |
| `0.29.21` | zero numeric / false boolean field |
| `0.29.22` | recursive numeric/boolean zero helper, depth <= 9 |
| `0.29.23` | patch `MinValue`, `MaxValue`, `RandomValues` |
| `0.29.24` | patch random-value collection |
| `0.29.25` | patch horizontal/vertical recoil group |
| `0.29.26` | apply `no_recoil` mutations to one row |
| `0.29.29` | recursive spread/dispersion/bloom convergence mutation |
| `0.29.67` | enumerate table rows and dispatch feature mutation |
| `0.29.68` | resolve/dedupe feature DataTables and apply them |

Editable implementation: `src/spectra/mutation_runtime.lua`.

## Exact DataTable name candidates

### `no_recoil`

1. `WeaponBase/WeaponRecoilTable`
2. `weaponBase/weaponrecoiltable`
3. `WeaponRecoilTable`
4. `/Game/DataTables/WeaponBase/WeaponRecoilTable`

### `converge`

1. `WeaponBase/WeaponSpreadTable`
2. `weaponBase/weaponspreadtable`
3. `WeaponSpreadTable`
4. `/Game/DataTables/WeaponBase/WeaponSpreadTable`
5. `WeaponBase/WeaponMainAttributeTable`
6. `weaponBase/weaponmainattributetable`
7. `WeaponMainAttributeTable`

`0.29.68` deduplicates candidates by the resolved DataTable object identity before applying
`0.29.67`.

## `no_recoil` field behavior

`0.29.26` applies recoil-group mutation to these exact row fields:

- `SingleOrBurstShootRecoil`
- `SingleOrBurstShootRecoils`
- `ContinueShootRecoil`
- `ContinueShootRecoils`
- `ContinueShootRecoilLoop`
- `ContinueShootRecoilLoops`

Each recoil group processes:

- `HorizontalRandomRecoil`
- `HorizontalRandomRecoils`
- `HorizontalScale`
- `VerticalRandomRecoil`
- `VerticalRandomRecoils`
- `VerticalScale`
- `HorizontalRecoils`
- `VerticalRecoils`

It also processes `SideAimingRecoilFactor` / `SideAimingRecoilFactors` and zeros their
`Horizontal` / `Vertical` numeric fields, plus top-level `HorizontalRecoils` and
`VerticalRecoils` collections.

All source-owned writes go through the reconstructed snapshot mechanism so disabling the
feature restores the first observed value for each object/key pair.

## `converge` recursion semantics

`0.29.29` has a depth cutoff after 10 levels. A key whose normalized name contains
`spread`, `dispersion`, or `bloom` starts forced recursion. Under forced recursion every
numeric descendant becomes `0.0` and every boolean descendant becomes `false`, even when
the descendant key itself does not contain those words.

For userdata traversal the baseline supplies a fixed 114-field probe list. The exact list
is retained as `MutationRuntime.CONVERGE_FIELDS`; the validator asserts its count and the
unit test exercises force propagation and reversible snapshots.

## Bone-array restoration helpers represented in D3 source

The following previously mapped aim helper layer is now also present in
`mutation_runtime.lua`, but is not yet used for runtime aim takeover:

`0.29.44`, `0.29.46`, `0.29.48`, `0.29.49`, `0.29.50`, `0.29.51`, `0.29.52`,
`0.29.53`, `0.29.54`, `0.29.55`, `0.29.56`, `0.29.57`, `0.29.58`, `0.29.59`,
`0.29.60`.

They cover canonical bone names, name conversion, array access, array snapshots/bindings,
and restoration. D3 tests verify the table-array path; engine userdata behavior remains a
game-runtime checkpoint.

## Deliberate D3 boundary

D3 does not claim source ownership of `aim` or `anti_shake`. The aim row mutation path
enters `0.29.65`, which is 842 instructions with 136 constants and mode/table-specific
replacement logic. It must be reconstructed and tested before the public bridge can
safely route those features away from the known-good payload.

### Aim field replacement checkpoint

`aim_mutation.lua` reconstructs `P0.29.65` decisions and the parent `R52` profile
constants from verified bytecode. The row snapshot/write lives in `P0.29.66`,
not inside `P0.29.65`; its source bridge is still pending. See
`AIM_MUTATION_MAP.md` for the ordinary/Gamepad distinction, fire/ADS branches,
and exact replacement return contract. Runtime ownership has not changed.

`P0.29.66` traversal is now represented in source with snapshot/restore checks,
while `P0.29.67/68` and the active feature bridge continue to use the payload.

The aim-only `P0.29.67` row branch now resolves bytecode profile row IDs in
source, and requires explicit bone handling before it can be used by the bridge.
`aim_bones.lua` now provides inert, tested `P0.29.45/61..64` source.

`aim_bones.lua` also materializes the `P0.29.64` table refresh, with tested
snapshot restoration before rescanning the aim-assistor table.

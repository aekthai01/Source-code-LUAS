# Phase D data mutation map

Source of truth: `embedded_payload.bin` SHA-256
`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

This document describes the current source-owned data mutation layer after the Phase D
aim migration gate passed. Prototype IDs refer to payload bytecode structure; helper
names in source are reconstructed descriptions unless stated otherwise.

## Runtime ownership after payload initialization

| Feature key | Public entry | Runtime owner |
| --- | --- | --- |
| `no_recoil` | `set_dongdong_feature_config` | reconstructed source |
| `converge` | `set_dongdong_feature_config` | reconstructed source |
| `aim` | `set_dongdong_feature_config` | reconstructed source |
| `anti_shake` | `set_dongdong_feature_config` | reconstructed source |

Unsupported feature keys still delegate to the captured payload implementation.

`src/spectra/payload_feature_bridge.lua` captures both payload globals used by the aim
control path. The source bridge installs `P73`/`P77` together and rolls both globals
back if installation is incomplete. Runtime failures restore source-owned mutation
state before delegating to the known-good payload closure.

## Snapshot/table layer

`src/spectra/mutation_runtime.lua` represents the reversible mutation helpers around:

- `P0.29.10..26` where applicable
- `P0.29.29`
- bone-array snapshot support used by `P0.29.44` and related helpers
- generic table dispatch `P0.29.67`
- feature table dispatch `P0.29.68`

Feature snapshot writes record the original value before assignment and restore in
reverse order. Transactional regressions cover write failure, snapshot failure,
recursive-child failure, bone failure and partial mutation rollback.

## `no_recoil`

Candidate table aliases:

1. `WeaponBase/WeaponRecoilTable`
2. `weaponBase/weaponrecoiltable`
3. `WeaponRecoilTable`
4. `/Game/DataTables/WeaponBase/WeaponRecoilTable`

The reconstructed source mutates the recovered recoil groups and restores their first
observed values when the feature is disabled.

## `converge`

Candidate table aliases:

1. `WeaponBase/WeaponSpreadTable`
2. `weaponBase/weaponspreadtable`
3. `WeaponSpreadTable`
4. `/Game/DataTables/WeaponBase/WeaponSpreadTable`
5. `WeaponBase/WeaponMainAttributeTable`
6. `weaponBase/weaponmainattributetable`
7. `WeaponMainAttributeTable`

The recursive helper preserves the recovered forced-recursion semantics for spread,
dispersion and bloom descendants.

## Aim table dispatch

`P0.29.68` walks the configured feature table list with `ipairs`, resolves each name
through reconstructed `P13`, deduplicates by the raw resolved table object identity,
and dispatches to `P67`. Alias names that resolve to the same DataTable are applied once.

The aim configuration list contains the recovered aliases for:

- `WeaponAimAssistorTable`
- `WeaponAimAssistorTableForGamepad`
- `WeaponAssistedAimingTable`
- `WeaponAssistedAimingGroupTable`
- `WeaponBulletTable`

`P68` itself does not check whether a toggle is active and does not wrap `P67` in an
internal `pcall`.

## Aim row mutation chain

```text
P68
 ↓
P67
 ↓
P63 bone handling
 ↓
P66 recursive walker
 ↓
P65 replacement
```

`P67` uses `AimAssistorId` when available and falls back to exact row names:

```text
Default   -> 1
NewRow    -> 1001
NewRow_0  -> 1002
NewRow_1  -> 1003
NewRow_2  -> 11001
NewRow_3  -> 1004
```

The walker keeps the recovered depth limit of 13 and skips
`ConeFilterBones` / `ConeFilterBonesOfAI`. Table and userdata reads use the
reconstructed ABI where required; the `P2` false-to-nil behavior is not replaced by
the more permissive generic safe getter.

## Bone mutation and restoration

`src/spectra/aim_bones.lua` represents `P0.29.45` and `P0.29.61..64`.
It snapshots bone arrays before remapping, patches AI/filter structures, restores prior
arrays, and refreshes the aim-assistor table path. Duplicate bindings are tracked so a
single underlying array can be restored through multiple aliases.

## Weapon/runtime refresh

`src/spectra/aim_refresh.lua` represents `P0.29.74..76` and reuses reconstructed
`P2/P3/P4/P12` call semantics. Focused tests cover self/static ordering, fallback order,
protected calls, nil handling and duplicate side-effect risk.

## Runtime checkpoint

Current deterministic hashes and test results are authoritative in
`validation_phase_d.json`. Baseline and embedded payload bytes remain unchanged.
`game_runtime_test=false` remains unchanged until the rebuilt custom chunk is actually
executed in the DFM/game runtime.

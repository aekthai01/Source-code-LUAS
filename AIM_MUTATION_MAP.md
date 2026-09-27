# Phase D aim reconstruction map

Source of truth: `embedded_payload.bin` SHA-256
`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

`AIM_PROTOTYPE_INDEX.json` is the current implementation/ownership map:
**26 primary requested prototypes plus nested callbacks, 39 indexed entries total**
(26 primary + `P0.29.67/68` outer dispatch + 11 nested callbacks).
The pre-takeover structural metadata with instruction counts, constants, captures and
resolved call edges is preserved as `AIM_PROTOTYPE_INDEX_LEGACY_DETAILED.json`.
Names assigned in source are reconstructed descriptions unless an exact public/global
symbol is explicitly identified.

## Runtime ownership

After the byte-identical embedded payload initializes, reconstructed source owns:

- `aim`
- `anti_shake`
- public `set_dongdong_feature_config` (`P0.29.73`) for all four supported feature keys
- public `set_dongdong_aim_part` (`P0.29.77`)
- the aim mutation chain `P68 -> P67 -> P63 -> P66 -> P65`
- weapon/runtime refresh `P0.29.74..76`

The bridge preserves the original payload `set_dongdong_feature_config` and
`set_dongdong_aim_part`. Installation is dual-global and transactional. A dependency
failure leaves payload globals untouched; a halfway install restores both originals;
a source execution failure rolls back source snapshots/state and delegates to the saved
payload function without recursive fallback.

`game_runtime_test=false` remains authoritative because the rebuilt custom chunk has not
been executed in the DFM/game runtime.

## Reconstructed dependency chain

| Prototypes | Reconstructed source | Verified behavior |
| --- | --- | --- |
| `P0.29.30..43` | `src/spectra/aim_mutation.lua` | setting conversion/clamp helpers, mode selection, profile lookup/scaling |
| `P0.29.44..45` | `mutation_runtime.lua`, `aim_bones.lua` | canonical bone handling and target-part remap |
| `P0.29.61..64` | `src/spectra/aim_bones.lua` | bone snapshot, AI patch, row patch, restore/refresh |
| `P0.29.65` | `src/spectra/aim_mutation.lua` | field replacement contract `(replacement, should_patch)` |
| `P0.29.66` | `src/spectra/aim_chain.lua` | recursive depth-13 walker, snapshot-before-write, bone-field skip |
| `P0.29.67` | `src/spectra/aim_chain.lua` + generic table iteration in `mutation_runtime.lua` | row-ID resolution, P63 then P66 |
| `P0.29.68` | `src/spectra/mutation_runtime.lua` | configured-list traversal, P13 lookup, raw-identity dedupe, P67 dispatch |
| `P0.29.74..76` | `src/spectra/aim_refresh.lua` | weapon object collection, refresh methods, InitWeapon/InitAmmos |
| `P0.29.77` | `src/spectra/feature_control.lua` | source-owned delayed aim-part orchestration |

## `P0.29.68` parity

The 38 instructions were matched against payload disassembly and prototype captures.

- input: feature key
- captured configuration: parent `R27` feature-to-table-name list
- traversal: `ipairs`, preserving configured list order
- table resolution: captured `P0.29.13`
- dedupe: raw resolved table identity, before any extension/conversion
- dispatch: captured `P0.29.67(feature, table_value, table_name)`
- return: truthy if any dispatch returns truthy, otherwise false
- no active-mode check in `P68`
- no internal `pcall` around `P67`
- missing/invalid configured list returns false
- missing table is skipped
- duplicate aliases resolving to the same object dispatch once

The descriptive source name is `apply_feature`; it is not claimed as an original stripped
symbol.

## `P0.29.67` / row identity

The aim row branch obtains `AimAssistorId`; if conversion fails, exact row-name fallbacks are:

```text
Default   -> 1
NewRow    -> 1001
NewRow_0  -> 1002
NewRow_1  -> 1003
NewRow_2  -> 11001
NewRow_3  -> 1004
```

The chain applies bone handling first (`P63`) and then recursive field handling (`P66`).
`_Dat`, table/userdata traversal, depth limit 13, raw cycle/duplicate handling,
`ConeFilterBones` / `ConeFilterBonesOfAI` skipping, and snapshot-before-write behavior
are covered by focused regressions. `P2` false-to-nil semantics are used for the relevant
field reads rather than the broader `Mutation.safe_get` helper.

## `P0.29.65` parity

Mode mapping:

- no active aim mode -> `(nil, false)`
- `aim` -> `fire`
- `anti_shake` -> `ads`

ADS keeps ordinary `WeaponAimAssistorTable` separate from
`WeaponAimAssistorTableForGamepad`.

Fire coverage includes bullet radius, AssistedAimingGroup PVE links, AssistedAiming,
ordinary AimAssistor no-direct-field behavior, shooting/following/damping, active
tracking, and zoom paths.

Exact profile IDs covered:

```text
1
1001
1002
1003
11001
1004
```

Boundary/invalid conversion fixtures cover Aim Speed, Aim FOV, Aim Distance and
Aim Lock Delay. Differential fixtures encode expected values from bytecode evidence,
not from the reconstructed function under test.

## `P0.29.74..76` ABI parity

`aim_refresh.lua` reuses reconstructed `P0.29.2`, `P0.29.3`, `P0.29.4` and
`P0.29.12` semantics. Tests cover self/static ordering, fallback ordering, protected
calls, return values, nil handling and the side-effect-then-throw retry case.

## `P0.29.77` closure ownership

The payload `P77` captured payload `P73`, so replacing only the feature-config global
would leave delayed callbacks hybrid-owned. The active bridge therefore installs
source `P73` and source `P77` together. Source `P77` captures the source setter directly.

Verified delayed sequence:

```text
0.12 -> 0.04 -> 0.10 -> 0.38
```

Revision guards remain only where present in the reconstructed bytecode behavior. The
final callback checks the current feature toggle and does not add an extra revision guard.

## Validation state

The gated pre-takeover checkpoint passed direct-checkout GitHub Actions first. Ownership
was enabled only afterward. Current deterministic artifact hashes are recorded in
`validation_phase_d.json`; baseline and embedded payload hashes remain unchanged.

# Phase D aim evidence and source boundary

Evidence: verified `embedded_payload.bin` SHA-256 `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.
`AIM_PROTOTYPE_INDEX.json` indexes all 26 requested `P0.29.30..45`, `61..66`, and `74..77` prototypes with their offsets, instruction counts, parent-register captures, capture dependents, constants, fields, environment access and return operands. Generate it with `python3 tools/aim_forensics.py`. A capture is a dependency, not proof of an executed call. The names assigned here are reconstructed descriptive names, never recovered local/debug symbols.

## Verified dependency chain

| Prototypes | Evidence and relation | Current source |
| --- | --- | --- |
| `30..39` | `P0.29.65` captures `31..36,39`; `P0.29.43` captures `32,34,33`; `30` supplies clamping. Parent `proto_0_29.txt:935..944` binds closures. | `aim_mutation.lua` settings and clamp; mode `aim → fire`, `anti_shake → ads` |
| `40..43` | `P0.29.41` reads parent `R52[tonumber(row_id)]` then calls `P0.29.40` for qualified field key; `P0.29.42` scales/clamps; `P0.29.43` combines FOV, distance and FOV scale. Parent `R52` initialization is instructions `388..934`. | Profile matrix, qualified key and composite formula in `aim_mutation.lua`; active walk still pending |
| `44..45` | Parent captures and constants recorded in index; `44` is also represented in existing bone layer. | `mutation_runtime.lua`, aim bridge still pending |
| `61..64` | `P0.29.61` verifies and snapshots bone-array writes; `62` patches `ConeFilterBones` in AI entries; `63` traverses `_Dat`/bone arrays; `64` iterates `WeaponAimAssistorTable` after restoring snapshots. | Existing bone helpers are present, but this entire active chain is not yet connected to source |
| `65 → 66` | `P0.29.66` captures and calls `P0.29.65` with `(row, table_name, field, original, row_id)` at `17..23`; when `should_patch`, it snapshots and patches at `24..32`. It recursively descends to depth 13. | `aim_mutation.lua` implements the replacement decisions; caller/snapshot traversal remains payload-owned |
| `74..76 → 77` | Parent `R99..R102` closures; `P0.29.77` captures `P0.29.76` and `75` for weapon/init refresh, and schedule helper `P0.29.8`. | `feature_control.lua` implements `77`; runtime bridge still delegates aim modes |

`P0.29.65` captures: normalizer `P0.29.10`, mode `36`, speed `31`, FOV `32`, FOV scale `33`, distance `34`, composite `43`, lock delay `39`, safe field read `P0.29.2`, profile lookup `41`, scale/clamp `42`, lock setting `35`. Its source signature exposes `row_id` explicitly. See `proto_0_29.txt:1050..1051`, `_aim_sections/0_29_65.txt`, `_aim_sections/0_29_66.txt` and the index. The `normalize_identifier`, `read_field` and `scale_clamp` dependencies are still injected and must be wired to the existing reconstructed helpers before any takeover.

## P0.29.65 branch results

| Branch (instruction range) | Conditions and replacement contract |
| --- | --- |
| mode unavailable `10..16` | `(nil, false)` |
| ordinary assistor ADS `38..50,148..285` | `WeaponAimAssistorTable` must match **without** `ForGamepad`. `bTakeEffect=true`; FOV and rate fields from config; distance-dependent `InRangeB` tiers `9000/5500/2800/2200` with values `33333/22222/9999/(7000 or 7777)` scaled by `distance/150`; unsupported hip rate returns `(nil,false)`. |
| Gamepad ADS `38..50,150..154` | `WeaponAimAssistorTableForGamepad` is excluded from the ordinary ADS branch and returns `(nil,false)` there. Do not collapse the two names. |
| bullet fire `286..302` | Numeric `Radius <= 3` becomes `5`; otherwise no patch. |
| assisted group fire `303..402` | Six PVE link fields read `SingleId`, `AutoId`, `BurstId`, `AimingSingleId`, `AimingAutoId`, `AimingBurstId` from the row; patch only positive numeric IDs. |
| assisted aiming fire `403..522` | Min/max assist distance, radii, vertical scale, recoil speed, cooldown, sticky and prevent-miss values use the exact bytecode literals and formulas in source; other fields return `(nil,false)`. |
| ordinary assistor fire `523..527` | Returns `(nil,false)` for this direct field replacement path. |
| generic fire `528..840` | `bTakeEffect` is false for active tracking or zoom, true for shooting/following/damping, otherwise no patch. Profile lookup uses exact IDs `1, 1001, 1002, 1003, 11001, 1004`; `factor`, timing, FOV, height and range rules scale/clamp their stored values. Fallback angle/input/actor-limit fields are handled after profile lookup. |

`P0.29.65` returns `(replacement, should_patch)` with two values (`RETURN B=3`) on handled/declined paths. It does not itself snapshot or write the row. `P0.29.66` owns that action after a true flag. The new source function is compiled into the bundle and tested, but **never called by the active bridge**. This preserves known-good payload behavior while the walker, bone array, refresh and runtime handoff need further fidelity checks.

## Target-part revision timing

Verified against `proto_0_29_77.txt` and nested `proto_0_29_77_0*.txt`: increment revision and delay `0.12`; guard revision, identify active mode, reapply false, clear bone snapshot/name cache and set build revision; delay `0.04`, reapply true; delay `0.10`, guard revision and run weapon initialization (fallback refresh if false); delay `0.38`, reassert only if the same mode is still active. The existing `feature_control.lua` follows this order. The final delayed callback checks the current toggle, as bytecode does; it does not repeat the earlier revision guard.

## Remaining migration gate

Materialize and compare the `P0.29.66/67/68` recursive walker and snapshot/restore calls, `61..64` bone chain, `74..76` weapon refresh and profile wiring to runtime state. Then extend tests around transactional bridge fallback and run a game execution check before calling the feature runtime-verified. Until that gate passes, `aim` and `anti_shake` stay payload-owned and `game_runtime_test=false`.

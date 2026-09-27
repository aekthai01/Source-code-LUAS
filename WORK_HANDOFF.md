# Work handoff: SPECTRA Lua reconstruction

## Authoritative branch

Repository: `aekthai01/Source-code-LUAS`

Branch: `work/phase-d-aim-reconstruction`

Draft PR: `#2 Phase D aim reconstruction: bytecode field rules (draft)`

Do not merge `main` as part of this handoff.

## Binary source of truth

Baseline:

- size `180034`
- SHA-256 `35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536`

Embedded payload:

- size `108533`
- SHA-256 `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`

The forensic tarball may remain for archive purposes, but it is no longer required to
reproduce Phase D validation.

## Direct-checkout reproduction

From a clean checkout:

```sh
python3 tools/build_phase_d.py
python3 tools/aim_forensics.py
python3 tools/full_payload_forensics.py
python3 tools/validate_phase_d.py
```

GitHub Actions runs the same validation path and a second deterministic build.

## Current Phase D / Phase E artifact

Phase: `E3-root-durability-check-reconstruction`

- source size `387518`
- source SHA-256 `95b0b52451685292b95137a533eea618485a740e9d87515287ef5ab0c7a55770`
- standard chunk size `306747`
- standard SHA-256 `14b4a057ea2e4af169cc07d12f29aa720ceb86a59ce5777153eb8639af5181f4`
- custom chunk size `306747`
- custom SHA-256 `e7df52db4f7b768fd2312d897b6a357a586e94599897fdf21a8af3b841acf830`

`validation_phase_d.json` is the machine-readable checkpoint.

## Runtime ownership

Source-owned after the byte-identical payload initializes:

- wrapper/bootstrap/auth/storage/login UI
- native post-login settings UI
- `no_recoil`
- `converge`
- `aim`
- `anti_shake`
- root P0.0..P0.2 and P0.4..P0.6 method overlay
- P0.3 source logic with conditional runtime ownership when original logger captures are available
- source `set_dongdong_feature_config` (`P0.29.73`)
- source `set_dongdong_aim_part` (`P0.29.77`)
- aim chain `P68 -> P67 -> P63 -> P66 -> P65`
- `P0.29.74..76` weapon/runtime refresh
- public visual entries and reconstructed visual scan/fashion/tick path

Still payload-owned:

- root P0.3 when original diagnostic U0/U2 closures are unavailable
- root P0.7 bullet check when captured helper/logger/module identity is unavailable; its source and tests exist but the prototype remains partially reconstructed
- root P0.8 durability check when its captured error logger is unavailable; its source and tests exist but the prototype remains partially reconstructed
- remaining unreconstructed business/equipment behavior outside the migrated Phase D
  feature/visual surfaces
- saved payload feature/aim functions retained only as transactional fallback

## Aim prototype status

`AIM_PROTOTYPE_INDEX.json` is the current implementation/ownership index:
**26 primary requested prototypes plus nested callbacks, 39 indexed entries total**.

`AIM_PROTOTYPE_INDEX_LEGACY_DETAILED.json` preserves the pre-takeover detailed structural
metadata (instruction counts, constants, captures, conservative call edges). Do not use
legacy runtime-status wording from that archive as the current ownership source.

Important current mappings:

- `P0.29.65` -> `replace_aim_field` in `aim_mutation.lua`
- `P0.29.66` -> recursive walker in `aim_chain.lua`
- `P0.29.67` -> aim row dispatcher in `aim_chain.lua`
- `P0.29.68` -> reconstructed `apply_feature` in `mutation_runtime.lua`
- `P0.29.74..76` -> `aim_refresh.lua`
- `P0.29.77` -> source `set_dongdong_aim_part` in `feature_control.lua`

Names above are reconstructed descriptions unless they are exact public globals.

## Transactional bridge invariants

The active feature bridge must preserve both original payload globals.

- dependency failure before install: no global replacement
- failure replacing the second global: restore both payload globals
- source execution failure: rollback source snapshots/state, then call saved payload
- no fallback recursion through the source wrapper
- P77 delayed callbacks stay bound to source P73 after takeover

Aim and anti-shake remain mutually exclusive.

## Focused regressions

The validator runs:

- native settings UI
- feature control
- character visuals
- aim runtime
- P65 mutation
- differential P65 fixtures
- bone handling
- refresh helper ABI
- P68 dispatch
- P67/P68 chain
- chain fidelity
- transactional mutation failures
- mutation runtime
- payload feature bridge
- visual runtime/scan/bridge
- wrapper smoke
- auth/protocol fixture

CI also checks custom/standard roundtrip, Lua 5.3 chunk structure, baseline/payload
identity and deterministic custom-chunk output.

## Remaining required runtime checkpoint

`game_runtime_test=false`.

Do not change it until the rebuilt custom chunk is actually executed in the DFM/game
runtime. CI/mock success is not a substitute for that engine-runtime execution.

## Follow-up rollback hardening

Before delegating a failed source transaction, the bridge verifies every saved field and
bone record. Bone checks include captured array counts, canonical values at all indices,
owner bindings, parent-array entries and parent-owner links. Failed restoration retains
snapshots and the bone-name pool and returns false without entering payload. Focused tests
create two actual bone records and cover partial value, binding and index failures plus
complete restore. Game runtime execution remains unverified.

## Phase E3 full inventory and root equipment-check methods

`FULL_PAYLOAD_PROTOTYPE_INDEX.json` is generated from the verified payload prototype,
constant and disassembly artifacts. It contains exactly 296 prototype paths. Generated
coverage is 79 source-owned, 212 payload-owned, 5 partially reconstructed, 0 verified
dead and 0 unknown. Static closure reachability does not assert runtime invocation.

`FULL_PAYLOAD_RECONSTRUCTION_MAP.md` records exact P0.0..P0.28 exports and the
`EquipTypeList` / `ContainerTypeList` fields. `src/spectra/product_module.lua` materializes
P0.0..P0.8 plus nested callbacks P0.6.0, P0.7.0 and P0.8.0; tests cover flow branches, process call order,
threshold boundaries, rental and currency paths, medicine traversal/filtering/aggregation,
container capacity and safe-box branches, bullet slot ordering, negative/rounded bullet
requirements, subtype combination, armor eligibility, durability threshold/formatting,
abnormal construction and event arguments.
`product_module_bridge.lua` receives `state.product` after payload execution, preserves
originals and rolls back partial installation. P0.0..P0.2 and P0.4..P0.6 are installed by
default (6/29 root methods). P0.3 is source tested but runtime installation
requires the original U0/U2 logger closures; without those it stays payload-owned. Source
exceptions propagate without retrying possibly non-reversible effects. P0.7 remains partial:
the bridge checks closure upvalues 2..5 for `ItemHelperTool`, debug logger, the identical
product table and error logger; if any capture is missing or mismatched the payload method
stays installed. Direct bridge tests verify both the capture indices and rollback at the P0.7
write. P0.8 conditionally captures its single error logger at debug upvalue 2; source takeover
requires that exact capture and rolls back the full method set if its write fails.

CI regenerates the full inventory, asserts exactly 296 entries, runs Phase D and Phase E
tests, checks ownership consistency and repeats the custom build for determinism. The
workflow uses `actions/checkout@v6`, whose action metadata specifies Node 24.

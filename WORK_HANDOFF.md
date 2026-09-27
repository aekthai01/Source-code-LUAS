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

Phase: `E1-full-payload-inventory-and-root-method-overlay`

- source size `367368`
- source SHA-256 `6f24a418885b30f6659d180f510a5bfe1fc191e9e4e545faeabbca0e4525227b`
- standard chunk size `298119`
- standard SHA-256 `eb50a2aa5855476cf05aeb6228e68881d939f40cf727c17467096d8cdb1fa7b5`
- custom chunk size `298119`
- custom SHA-256 `55e80c120edb8c4e53ebfeaa4826794e9e3255100f8e97e30fb2e7d7cfb012d9`

`validation_phase_d.json` is the machine-readable checkpoint.

## Runtime ownership

Source-owned after the byte-identical payload initializes:

- wrapper/bootstrap/auth/storage/login UI
- native post-login settings UI
- `no_recoil`
- `converge`
- `aim`
- `anti_shake`
- root P0.0..P0.2 and P0.4..P0.5 method overlay
- P0.3 source logic with conditional runtime ownership when original logger captures are available
- source `set_dongdong_feature_config` (`P0.29.73`)
- source `set_dongdong_aim_part` (`P0.29.77`)
- aim chain `P68 -> P67 -> P63 -> P66 -> P65`
- `P0.29.74..76` weapon/runtime refresh
- public visual entries and reconstructed visual scan/fashion/tick path

Still payload-owned:

- root P0.3 when original diagnostic U0/U2 closures are unavailable
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

## Phase E3 full inventory and root medicine methods

`FULL_PAYLOAD_PROTOTYPE_INDEX.json` is generated from the verified payload prototype,
constant and disassembly artifacts. It contains exactly 296 prototype paths. Generated
coverage is 77 source-owned, 218 payload-owned, 1 partially reconstructed, 0 verified
dead and 0 unknown. Static closure reachability does not assert runtime invocation.

`FULL_PAYLOAD_RECONSTRUCTION_MAP.md` records exact P0.0..P0.28 exports and the
`EquipTypeList` / `ContainerTypeList` fields. `src/spectra/product_module.lua` materializes
P0.0..P0.5; tests cover flow branches, process call order, threshold boundaries, rental and
currency paths, medicine traversal/filtering/aggregation, abnormal construction and event
arguments. `product_module_bridge.lua` receives `state.product` after payload execution,
preserves originals and rolls back partial installation. P0.0..P0.2 and P0.4..P0.5 are
installed by default (5/29 root methods). P0.3 is source tested but runtime installation
requires the original U0/U2 logger closures; without those it stays payload-owned. Source
exceptions propagate without retrying possibly non-reversible effects.

CI regenerates the full inventory, asserts exactly 296 entries, runs Phase D and Phase E
tests, checks ownership consistency and repeats the custom build for determinism. The
workflow uses `actions/checkout@v6`, whose action metadata specifies Node 24.

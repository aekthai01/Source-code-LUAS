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
python3 tools/validate_phase_d.py
```

GitHub Actions runs the same validation path and a second deterministic build.

## Current Phase D artifact

Phase: `D4-aim-source-runtime-takeover`

- source size `352444`
- source SHA-256 `3af199cf24137cd83fa2fc90f2238603051d3e9b719bfb7d27de804f069297f5`
- standard chunk size `289901`
- standard SHA-256 `63892e328fb3c883f65eae9b8fe1edf746eb8b12811602a9d940abc9cdc13662`
- custom chunk size `289901`
- custom SHA-256 `d8375155a5cae76a95cd6d72e0d1a17144771d5b9debff61c7c714e225ec00b9`

`validation_phase_d.json` is the machine-readable checkpoint.

## Runtime ownership

Source-owned after the byte-identical payload initializes:

- wrapper/bootstrap/auth/storage/login UI
- native post-login settings UI
- `no_recoil`
- `converge`
- `aim`
- `anti_shake`
- source `set_dongdong_feature_config` (`P0.29.73`)
- source `set_dongdong_aim_part` (`P0.29.77`)
- aim chain `P68 -> P67 -> P63 -> P66 -> P65`
- `P0.29.74..76` weapon/runtime refresh
- public visual entries and reconstructed visual scan/fashion/tick path

Still payload-owned:

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

Before delegating a failed source transaction, the bridge verifies every saved field and requires bone restoration to succeed when bone records are pending. Failed restoration retains snapshots and returns false without entering payload. `tests/aim_transaction.lua` covers field, partial and bone failures. Game runtime execution remains unverified.

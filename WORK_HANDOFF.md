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

- source size `350606`
- source SHA-256 `5e2ecdc0d98dfbb3c3226dce5e41c0ec0b29e26a944e8aca801dc012417c0774`
- standard chunk size `289167`
- standard SHA-256 `cba43702e0bac29d4baaaef2dab91e578c97e43b7d36f90838f1ead5e945efb5`
- custom chunk size `289167`
- custom SHA-256 `184caf21530481d4668a619415ebdf02ff7697719b84019ffab97b22b6e21df7`

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

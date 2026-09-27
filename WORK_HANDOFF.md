# Work handoff: SPECTRA Lua reconstruction

## Source of truth

Use `baseline_original.luac` only as the binary source of truth.

- baseline size: `180034`
- baseline SHA-256: `35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536`
- embedded payload size: `108533`
- embedded payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`

Do not continue from older experimental lifecycle-patched binaries.

## Work branch and full snapshot

Continue on branch `work/phase-d-aim-reconstruction`.

The repository root on `main` is a **partial readable mirror**, not a complete extraction of the project. Do not infer that a file is absent from the project merely because it is absent from the root tree.

The complete project snapshot is stored as:

- `spectra_rebuild_snapshot.tar.xz`
- original alias: `spectra_rebuild..tar.xz`
- Git blob: `d082ce7c82c0c7904b7ca83e811e86efb39772bf`
- GitHub-reported size: `342752` bytes

Extract the snapshot before doing cross-file work. The source workspace used to create this handoff was re-verified against `validation_phase_d.json`:

- `spectra_wrapper_phase_d_source.lua`: `302644` bytes, SHA-256 `66e728079d912dc93f45ed0e6929f126fc98e4a911d82479af9af4968f5116f1`
- `spectra_wrapper_phase_d.custom.luac`: `260725` bytes, SHA-256 `78017b01338c4a6fdaeded208350e0e31934ceff217b98e8c3fe2ce1e6235346`
- `embedded_payload.bin`: `108533` bytes, SHA-256 `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`

Readable overlay files on the Work branch may be newer/more complete than the partial mirror on `main`, but the extracted snapshot remains the complete project workspace.

## Current materialized checkpoint

Authoritative machine-readable state: `validation_phase_d.json`.

Current phase: `D4-recovery-public-visual-runtime-takeover`.

- phase-D source size: `302644`
- phase-D source SHA-256: `66e728079d912dc93f45ed0e6929f126fc98e4a911d82479af9af4968f5116f1`
- custom chunk size: `260725`
- custom chunk SHA-256: `78017b01338c4a6fdaeded208350e0e31934ceff217b98e8c3fe2ce1e6235346`
- game runtime validation: **not performed** (`game_runtime_test=false`)

## Runtime ownership now

Source-owned after the known-good embedded payload initializes:

- wrapper/bootstrap/auth/storage/login UI
- post-login `SystemSettingMainView` native settings UI
- `no_recoil`
- `converge`
- `set_ai_color`
- `set_real_player_color`
- `set_character_xray`
- visual actor/mesh scan `P0.29.78..98`
- visual fashion refresh `P0.29.104`
- visual tick/fallback `P0.29.106/107`

Still payload-owned:

- `aim`
- `anti_shake`
- the low-level aim mutation chain ending in `P0.29.65`
- remaining payload business/equipment functionality not yet reconstructed

A previous report-only claim that aim takeover had been completed was retracted because the referenced source files were not present in the delivered workspace. Do not treat that claim as completed work.

## Next task

Reconstruct aim/anti-shake from the actual payload bytecode and materialize it in source before takeover.

Primary target group:

- `P0.29.30..45`
- `P0.29.61..66`
- `P0.29.74..77`
- especially `P0.29.65` (842 instructions / 136 constants)

Useful extracted disassembly is already in `_aim_sections/` inside the full snapshot, and the full source evidence remains in `payload_disassembly.txt`, `payload_constants.json`, `payload_prototypes.json`, and related forensic files.

Requirements for the next migration:

1. Reconstruct replacement rules from bytecode rather than guessing field semantics.
2. Preserve separation of normal `WeaponAimAssistorTable` and Gamepad-specific paths.
3. Preserve `fire`/`ads` mode-specific logic, FOV/range/speed/lock-time behavior, bone remap, snapshot/restore, and revision/timing chain.
4. Add source files and regression tests before changing runtime ownership.
5. Keep unknown/unreconstructed behavior delegated to the embedded payload.
6. Re-run `tools/validate_phase_d.py` and keep `validation_phase_d.json` authoritative.
7. Do not claim game-runtime compatibility until the rebuilt custom chunk is actually tested in the DFM/game runtime.

## Build / validation

After extracting the snapshot:

```sh
python3 tools/build_phase_d.py
python3 tools/validate_phase_d.py
```

Relevant focused tests include:

```sh
texlua tests/mutation_runtime.lua .
texlua tests/payload_feature_bridge.lua .
texlua tests/visual_scan.lua .
texlua tests/payload_visual_bridge.lua .
texlua tests/native_settings_ui.lua .
texlua tests/smoke.lua .
texlua tests/protocol_fixture.lua .
```

## Key documentation

- `PHASE_A_REPORT.md`
- `PHASE_D_REPORT.md`
- `PAYLOAD_FUNCTION_CATALOG.md`
- `PAYLOAD_UI_MAP.md`
- `DATA_MUTATION_MAP.md`
- `VISUAL_SCAN_MAP.md`
- `WRAPPER_CALL_GRAPH.md`
- `RUNTIME_TEST_CHECKLIST.md`

When documentation conflicts with machine artifacts, verify against the baseline bytecode and `validation_phase_d.json`; do not propagate a report-only claim.

## New pre-bridge aim checkpoint (continuation)

After extracting the updated snapshot, inspect `AIM_MUTATION_MAP.md` and
`AIM_PROTOTYPE_INDEX.json`. `src/spectra/aim_mutation.lua` implements tested
`P0.29.65` field decisions and exact `R52` profile literals but is not called
by the active bridge. `aim`/`anti_shake` remain payload-owned until the recursive
walker, bone and refresh paths are reconstructed and checked end to end. Re-run
`python3 tools/build_phase_d.py && python3 tools/validate_phase_d.py` in the
extracted snapshot. The regenerated hashes are in `validation_phase_d.json`.

Validated static artifact for this continuation:

- source: 325801 bytes, SHA-256 `7256ac630ffe8ea24e0395b6d701ef0cd74294f01a364a8a893e2f44c84f90c9`
- custom chunk: 271745 bytes, SHA-256 `017789edb68eb257a96e001792f1f0b27398f6e9de585bdbf07c3a36834fde15`
- baseline/payload: original hashes unchanged; `game_runtime_test=false`

`P0.29.66` recursive field walker is now materialized and snapshot/restore tested,
but its outer `P0.29.67/68`, bone and refresh paths are not yet source-owned.

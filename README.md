# SPECTRA Lua reconstruction

## Source of truth

Use `baseline_original.luac` only as the binary source of truth.

- baseline size: `180034`
- baseline SHA-256: `35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536`
- embedded payload size: `108533`
- embedded payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`

Do not continue from older experimental lifecycle-patched binaries.

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
- low-level aim mutation chain ending in `P0.29.65`
- remaining payload business/equipment functionality not yet reconstructed

A previous report-only claim that aim takeover had been completed was retracted because the referenced source files were not present in the delivered workspace. Do not treat that claim as completed work.

## Next task

Reconstruct aim/anti-shake from the actual payload bytecode and materialize it in source before takeover.

Primary target group:

- `P0.29.30..45`
- `P0.29.61..66`
- `P0.29.74..77`
- especially `P0.29.65` (842 instructions / 136 constants)

Useful extracted disassembly is in `_aim_sections/`. Full evidence is in `payload_disassembly.txt`, `payload_constants.json`, and the other forensic exports.

Requirements:

1. Reconstruct replacement rules from bytecode rather than guessing field semantics.
2. Preserve separation of normal `WeaponAimAssistorTable` and Gamepad-specific paths.
3. Preserve `fire`/`ads` mode logic, FOV/range/speed/lock-time behavior, bone remap, snapshot/restore, and revision/timing chain.
4. Add source files and regression tests before changing runtime ownership.
5. Keep unknown/unreconstructed behavior delegated to embedded payload.
6. Re-run `tools/validate_phase_d.py`; keep `validation_phase_d.json` authoritative.
7. Do not claim game-runtime compatibility until the rebuilt custom chunk is tested in DFM/game runtime.

## Build / validation

```sh
python3 tools/build_phase_d.py
python3 tools/validate_phase_d.py
```

Focused tests:

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

- `WORK_HANDOFF.md`
- `PHASE_A_REPORT.md`
- `PHASE_D_REPORT.md`
- `PAYLOAD_FUNCTION_CATALOG.md`
- `PAYLOAD_UI_MAP.md`
- `DATA_MUTATION_MAP.md`
- `VISUAL_SCAN_MAP.md`
- `WRAPPER_CALL_GRAPH.md`
- `RUNTIME_TEST_CHECKLIST.md`

When documentation conflicts with machine artifacts, verify against baseline bytecode and `validation_phase_d.json`; do not propagate a report-only claim.

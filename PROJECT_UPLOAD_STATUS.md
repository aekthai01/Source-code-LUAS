# Project upload / Work handoff status

Repository: `aekthai01/Source-code-LUAS`

## Authoritative reverse-engineering baseline

- Lua baseline size: `180034` bytes
- baseline SHA-256: `35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536`
- embedded payload size: `108533` bytes
- embedded payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`

Do not continue from older experimental lifecycle-patched binaries.

## Current verified project state

Use `validation_phase_d.json` as the machine-readable state and `WORK_HANDOFF.md` as the continuation guide.

Current checkpoint: `D4-recovery-public-visual-runtime-takeover`.

Source-owned after the known-good payload initializes:

- bootstrap/auth/storage/login wrapper
- post-login native settings UI
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

A previous report-only claim that aim takeover was complete was retracted because its referenced source files were not present in the delivered workspace. Do not treat that claim as completed work.

## Next Work target

Continue Issue #1: reconstruct the aim/anti-shake chain from the actual payload bytecode, especially:

- `P0.29.30..45`
- `P0.29.61..66`
- `P0.29.74..77`
- `P0.29.65` (842 instructions / 136 constants)

Preserve the normal `WeaponAimAssistorTable` vs Gamepad-specific split, `fire`/`ads` behavior, FOV/range/speed/lock-time behavior, bone remapping, snapshots/restoration, and the observed revision/timing chain. Add source and regression tests before changing runtime ownership.

## Snapshot artifact

A binary XZ snapshot uploaded on `main` is available under both names:

- `spectra_rebuild..tar.xz` (original uploaded filename)
- `spectra_rebuild_snapshot.tar.xz` (clean alias; same Git blob)

Git blob SHA: `d082ce7c82c0c7904b7ca83e811e86efb39772bf`
GitHub-reported size: `342752` bytes.

The connector can verify that this is XZ data but cannot decode/read the binary tar contents as UTF-8. Therefore the repository's readable `WORK_HANDOFF.md`, `validation_phase_d.json`, source tree, reports, and Issue #1 remain the authoritative navigation layer; verify binary hashes after extraction before using a binary as a new source of truth.

## Staging directories

`.import/` and `.import2/` are incomplete chunk-staging history from the transfer process. They are not the authoritative project state and should not be used in preference to the readable repository files or `spectra_rebuild_snapshot.tar.xz`.

## Runtime-test truth

`game_runtime_test` remains `false` until the rebuilt custom Lua chunk is actually executed and validated inside the DFM/game runtime.

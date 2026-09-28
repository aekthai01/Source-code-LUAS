# Spectra Lua 5.3 Reconstruction

This repository tracks a bytecode-guided reconstruction of the Spectra wrapper and its embedded Lua payload. The active Phase D work reconstructs source-owned behavior while preserving validated payload identities and deterministic build outputs.

## Current workflow

- Reconstruct bounded prototype groups from bytecode evidence.
- Preserve exact ABI, call order, table shapes, return arity, and source capture identity.
- Regenerate forensic ownership metadata from generators rather than hand-editing generated reports.
- Validate focused regressions, full Phase D behavior, and deterministic compiler output before advancing ownership.

See `FULL_PAYLOAD_RECONSTRUCTION_MAP.md`, `RECONSTRUCTION_COVERAGE.md`, `ROOT_CAPTURE_MAP.md`, and `validation_phase_d.json` for the current generated checkpoint.

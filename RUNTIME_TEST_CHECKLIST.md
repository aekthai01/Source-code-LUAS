# Phase C runtime verification checklist

ใช้ `spectra_wrapper.custom.luac` จาก checkpoint นี้เท่านั้น

Expected artifact before runtime test:

- wrapper size: `180467`
- wrapper SHA-256: `44a7705e2593daea5903f89671c58266ffaa455e1533ddbbbfb8ed4bf4b072d1`
- embedded payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`

## A. Existing valid saved key

1. Start script with `SPECTRA_WY_71438_CARD` already populated.
2. Expected: no welcome/license popup before auth.
3. Expected: authentication succeeds and payload loads exactly once.
4. Expected: menu/features behave as baseline payload.

## B. First-time login

To force first-time state using a verified baseline API:

```lua
Facade.ConfigManager:SetUserString("SPECTRA_WY_71438_CARD", "")
```

1. Start/account-login transition.
2. Expected: no `ConfirmWindows` and no License UI during transition.
3. Enter Lobby.
4. Expected: License UI appears after Lobby readiness (baseline event delay retained at 0.6 s).
5. Enter valid license key and Unlock.
6. Expected: authentication succeeds, key is persisted, UI closes, payload loads once.

## C. Restart after first success

1. Restart with saved key from B.
2. Expected: auto-auth, no License UI, payload once.

## D. Manual reopen / stale widget

1. On a first-time/manual-login state, cause the engine to destroy/close the login widget if possible.
2. Call:

```lua
OpenSpectraLogin()
```

3. Expected: a stale `_s5/_s6` state does not block reopening.
4. Repeated call while a valid login widget exists should not create an unnecessary duplicate.

## E. Invalid saved key

1. Store a key that the server rejects.
2. Start and enter Lobby.
3. Expected: one automatic authentication request.
4. Expected: server rejection message is shown.
5. Expected: `SPECTRA_WY_71438_CARD` is cleared.
6. Expected: manual License UI becomes available after Lobby; no request loop.

## F. Network / response integrity failure

1. Test a transient network failure or an invalid/stale response condition.
2. Expected: saved key is **not** cleared merely because transport, freshness, or response-check validation failed.
3. Expected: no repeated request loop.

## G. Payload invariants

After any successful authentication:

- payload should execute once per wrapper state (`_s2` prevents double-load)
- wrapper should use embedded payload bytes unchanged
- no payload reconstruction/refactor has been introduced in this checkpoint

## Evidence to capture on failure

Record at minimum:

- whether Lobby was already active when the wrapper started
- whether `OpenSpectraLogin` exists and is callable
- `_x1._s1`, `_x1._s2`, `_x1._s5`, `_x1._s6`, `_x1._s7`
- `_x1._sb` error text if present
- whether `SPECTRA_WY_71438_CARD` remained populated
- whether the failure occurred before request, on server response, on UI creation, or during payload startup

Do not patch opcodes to work around a failed runtime test. Feed the observed state/error back into the clean source path and rebuild from the same baseline.

# Phase D3 runtime verification addendum

For D3 feature migration tests use `spectra_wrapper_phase_d.custom.luac`, not the Phase-C
artifact listed above.

Expected D3 artifact:

- wrapper size: `238497`
- wrapper SHA-256: `1cbe099f234415e9807dc90f0bdd381e1d600dc8af0c0c5790fdbb39633af349`
- embedded payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`

## H. Source-owned No Recoil

1. Authenticate and enter a state where a weapon is initialized.
2. Enable `No Recoil` from the reconstructed System Settings page.
3. Expected: recoil behavior changes as before; UI remains responsive.
4. Disable `No Recoil`.
5. Expected: values restore without restarting/reloading the payload.
6. Repeat enable -> disable once more to exercise snapshot recreation and restore.

## I. Source-owned Bullet Spread Control (`converge`)

1. Enable `Bullet Spread Control`.
2. Expected: spread/convergence behavior changes as before.
3. Disable it.
4. Expected: first-observed DataTable values are restored.
5. Switch weapon / refresh weapon state and repeat once to catch table-instance changes.

## J. Delegated Aim / Anti-Shake

1. Enable `Hip-Fire Aim` / `ADS Aim` individually.
2. Expected: behavior remains the same as the known-good embedded payload.
3. Verify the two modes remain mutually exclusive.
4. D3 does not claim source ownership of their low-level mutation path; a regression here
   should first be checked for bridge delegation/global replacement rather than rewriting
   `0.29.65` speculatively.

## K. Mixed toggle sequence

Exercise at least:

`No Recoil ON -> Spread ON -> Aim ON -> No Recoil OFF -> Aim OFF -> Spread OFF`

Expected: each D3-owned feature restores only its own snapshot; delegated aim state should
not be erased by disabling recoil/spread.

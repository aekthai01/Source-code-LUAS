# SPECTRA wrapper call graph — verified baseline

เอกสารนี้อ้างอิงเฉพาะ `baseline_original.luac` (SHA-256 `35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536`) และ `outer_disassembly.txt` / `outer_prototypes.json` ที่ extract จากไฟล์เดียวกัน

ชื่อด้านขวาเป็น **reconstructed semantic names** เพื่อให้อ่านได้ ไม่ใช่ debug symbol ต้นฉบับที่กู้คืนมา เพราะ baseline ไม่มี locvars/upvalue names/lineinfo เหลืออยู่

## 1. Root register binding ที่ใช้ resolve calls

ช่วงท้าย root prototype `0` สร้าง closures ดังนี้:

| Root register | Prototype | Reconstructed role |
|---|---:|---|
| `R6` | `0.0` | Base64 decode |
| `R7` | `0.32` | normalize card (เดิมเคยถือ `0.1`, ถูก overwrite ก่อน auth closure ถูกสร้าง) |
| `R8` | `0.2` | safe field/property lookup |
| `R9` | `0.3` | delay helper |
| `R10` | `0.4` | show tip via `_G.Module.CommonTips` |
| `R11` | `0.5` | ConfigManager lookup |
| `R12` | `0.6` | GetUserString |
| `R13` | `0.7` | SetUserString |
| `R14` | `0.8` | RC4 binary transform |
| `R15` | `0.9` | lower-case hex encoder |
| `R16` | `0.10` | hex decoder |
| `R21` | `0.29` export `md5` | MD5 function after crypto table initialization |
| `R22` | `0.14` | JSON parser |
| `R23` | `0.15` | bytes → string bridge |
| `R24` | `0.16` | HttpLoader fallback transport |
| `R25` | `0.17` | HttpDownloader primary transport |
| `R26` | `0.31` | active device-ID lookup (`0.18` was overwritten before auth closure creation) |
| `R27` | `0.19` | payload load-once |
| `R28` | `0.20` | close login UI |
| `R29` | `0.21` | server-message formatter |
| `R30` | `0.22` | authentication |
| `R31` | `0.23` | license UI opener |
| `R32` | `0.24` | welcome `ConfirmWindows` opener |
| `R33` | `0.25` | startup/retry routine |
| `R34` | `0.26` | Lobby listener registration |
| `R62` | `0.35` | request builder |
| `R63` | `0.36` | uppercase-byte hex encoder (`url_encode`) |
| `R64` | `0.30` | protected-call helper |
| `R65` | `0.33` | timestamp helper |
| `R67` | `0.34` | challenge helper |

Direct root initialization edges:

```text
root 0
 ├─ rawset(_G, "OpenSpectraControl", P0.27)
 ├─ rawset(_G, "OpenSpectraLogin",   P0.28)
 ├─ P0.26 register_lobby_listener()
 └─ P0.3 delay(0.8, P0.25 startup)
```

Evidence: root instructions `1095..1112`.

## 2. Baseline login/auth graph

```text
P0.26 register_lobby_listener
 └─ evtLobbyBusinessInit listener P0.26.0
     └─ P0.3 delay(0.6, P0.25 startup)

P0.25 startup
 ├─ if authenticated: return
 ├─ P0.24 open_welcome()
 └─ if open_welcome failed and _s8 < 60:
     └─ P0.3 delay(1, P0.25 startup)

P0.24 open_welcome (ConfirmWindows)
 ├─ Later callback P0.24.1
 │   └─ clear _s3/_s4
 └─ Unlock callback P0.24.0
     ├─ clear _s3/_s4
     └─ P0.3 delay(0.2, P0.23 open_license)

P0.27 OpenSpectraControl
 ├─ clear _s3/_s4
 └─ P0.24 open_welcome()

P0.28 OpenSpectraLogin
 ├─ clear _s3/_s4
 └─ P0.23 open_license()

P0.23 open_license
 ├─ GetUserString("SPECTRA_WY_71438_CARD") for initial input value
 ├─ AsyncShowUI(CommonRenamePopWindows, ...)
 └─ UI callback P0.23.1
     └─ Unlock callback P0.23.1.0
         ├─ read `_wt_WBP_inputBox:GetText()`
         └─ P0.22 authenticate(card)

P0.22 authenticate
 ├─ P0.32 normalize_card(card)
 ├─ P0.4 show_tip(...)
 ├─ P0.31 get_device_id()
 ├─ P0.35 build_request(card, device)
 └─ P0.17 HTTP transport(tag, url, P0.22.0 response_callback)

P0.17 primary HTTP transport
 ├─ import("HttpDownloader")
 ├─ OnByteSuccess callback P0.17.2
 ├─ OnFail callback P0.17.3
 └─ fallback closure P0.17.0
     └─ P0.16 HttpLoader fallback

P0.16 HttpLoader fallback
 ├─ require("DFM.YxFramework.Managers.Resource.HttpLoader")
 ├─ evtOnBatchComplete callback P0.16.1
 └─ completion P0.16.0
     ├─ evtOnBatchComplete:Unbind(...)
     ├─ loader:Release()
     └─ auth transport callback

P0.22.0 response_callback
 ├─ P0.10 hex_decode(response)
 ├─ P0.8 RC4(decrypted_bytes, _c2)
 ├─ P0.14 parse_json(plaintext)
 ├─ validate code == 73913
 ├─ validate abs(response_time - request_timestamp) <= 30
 ├─ P0.29.md5(tostring(response_time) .. _c1 .. request_value)
 ├─ validate response.check
 ├─ P0.7 SetUserString(_c6 .. "CARD", card)
 ├─ P0.20 close_login_ui()
 └─ P0.19 load_payload_once()
     ├─ P0.0 Base64 decode embedded payload
     ├─ load(bytes, "@spectra-product", "b", _G)
     └─ pcall(chunk)
```

### Directly evidenced critical edges

- `P0.25 → P0.24`: `P0.25` captures root `R32`, which is `P0.24`, and calls it at instructions `3..4`.
- `P0.25 → P0.3/P0.25`: it captures root `R9` (delay) and `R33` (itself), then calls `delay(1, startup)` at `14..17`.
- `P0.26.0 → P0.3/P0.25`: listener child captures parent upvalues resolving to root delay/startup and calls `delay(0.6, startup)`.
- `P0.24.0 → P0.3/P0.23`: Unlock child calls captured delay with `0.2` and captured license opener.
- `P0.28 → P0.23`: global manual login closure captures root `R31` and tailcalls it.
- `P0.23.1.0 → P0.22`: input callback captures the authentication closure and invokes it with the text read from `_wt_WBP_inputBox`.
- `P0.22 → P0.31/P0.35/P0.17`: authentication upvalues resolve to root `R26`, `R62`, `R25`; disassembly calls them in that order around request construction/dispatch.
- `P0.22.0 → P0.10/P0.8/P0.14/P0.7/P0.20/P0.19`: response child upvalues resolve through parent captures to these root registers and are invoked on decode/verify/success paths.
- `P0.17.0 → P0.16`: primary transport fallback closure captures root `R24` and tailcalls it.

## 3. Device-ID implementation reachability

Baseline contains two device-ID implementations:

- `P0.18`: older helper that can read/persist `_c6 .. "DEVICE"` (`SPECTRA_WY_71438_DEVICE`) and synthesize a `dfm-<time>-<random>` identifier.
- `P0.31`: later implementation with private config-table `DEVICE_ID`, engine bridges, player ID, and global device getter fallbacks.

The root first stores `P0.18` into `R26` at instruction `1043`, but **overwrites `R26` with `P0.31` at instruction `1079` before `P0.22` authentication is created at instruction `1088`**. Therefore the active authentication closure captures `P0.31`; `P0.18` is not on the active login/auth path in this baseline.

This distinction matters because treating `P0.18` as active would incorrectly introduce persistent synthetic device IDs into the clean wrapper.

## 4. Clean reconstruction graph

The rebuilt source intentionally changes only lifecycle orchestration while keeping protocol/payload behavior:

```text
Bootstrap.start
 ├─ install OpenSpectraLogin / OpenSpectraControl globals first
 ├─ Crypto.self_test
 ├─ ensure_lobby_watcher
 │   ├─ current-flow == Lobby -> on_lobby_ready
 │   ├─ bind evtLobbyBusinessInit
 │   └─ if event module unavailable: finite 1s bind retry, max 60
 └─ start_saved_key_auth
     ├─ saved key exists -> Auth.authenticate immediately, no popup
     └─ no key -> UI only after Lobby readiness

Auth.authenticate
 ├─ Runtime.get_device_id
 ├─ build_request with baseline constants/formula
 ├─ Transport.get
 └─ success
     ├─ Storage.set_card
     ├─ LoginUI.close
     └─ PayloadLoader.load_once

OpenSpectraLogin
 ├─ clear stale _s5/_s6 flags
 └─ LoginUI.open_license(force=true), which probes actual widget validity
```

The finite Lobby retry retries **event binding only**. It does not reopen UI and is not a replacement watchdog for `ConfirmWindows`.

## 5. Confidence / limits

- Prototype boundaries, closure captures, constants, opcodes and edges above are derived from the attached baseline bytecode.
- Semantic function names are reconstructed labels, not recovered original symbols.
- Stripped local names/comments cannot be recovered from this chunk.
- Engine-side behavior after the named APIs are invoked still requires DFM runtime testing; no sandbox result is presented as proof of engine execution.

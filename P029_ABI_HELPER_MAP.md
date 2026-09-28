# P0.29 ABI Helper Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

Names below are reconstructed semantic labels, not recovered stripped debug symbols.

The source-owned boundary is deliberately non-invasive: source-owned consumers call `src/spectra/aim_abi.lua` directly. Existing payload helper closures are not dynamically rebound; unreconstructed payload-owned callers may continue using captured payload copies.

| Prototype | P0.29 register | Params | Instructions | Upvalues | Children | Source symbol | Return contract | Retry order |
|---|---:|---:|---:|---:|---:|---|---|---|
| `0.29.2` | `R19` | 2 | 17 | 1 | 1 | `AimABI.get` | exactly one value: truthy field value or nil; false/nil/error collapse to nil | single protected lookup |
| `0.29.2.0` | `nested` | 0 | 7 | 2 | 0 | `AimABI.get nested protected lookup closure` | exactly one value: raw owner[key]; no nil guard; parent pcall owns exceptions | none |
| `0.29.3` | `R20` | 2 | 43 | 2 | 0 | `AimABI.self_first` | missing/both-fail: exactly false,nil; success: exactly true,result1,result2 | self-first pcall, then static pcall only after first exception |
| `0.29.4` | `R21` | 2 | 43 | 2 | 0 | `AimABI.static_first` | missing/both-fail: exactly false,nil; success: exactly true,result1,result2 | static-first pcall, then self pcall only after first exception |
| `0.29.12` | `R32` | 2 | 31 | 1 | 0 | `AimABI.call_optional_self` | all paths exactly two values; success true,result1; fallback failure false,error | self-first pcall, then static pcall only after first exception |

## Known source consumers

### `0.29.2`
- src/spectra/aim_refresh.lua: AimRefresh.collect_targets/refresh_methods/init_current_weapon
- src/spectra/aim_chain.lua: AimChain.walk_and_patch/apply_aim_row
- src/spectra/payload_feature_bridge.lua: default_dependencies read_field injection
- src/spectra/aim_mutation.lua: replacement consumes injected deps.read_field
- src/spectra/mutation_runtime.lua: canonical safe_get used throughout active P0.29.68 source path
- src/spectra/aim_runtime.lua: P0.29.71 fixed protected field reads

### `0.29.2.0`
- src/spectra/aim_abi.lua: nested raw owner[key] closure inside AimABI.get

### `0.29.3`
- src/spectra/aim_refresh.lua: invoke(self_first=true) used by collect_targets/refresh_methods

### `0.29.4`
- src/spectra/aim_refresh.lua: invoke(self_first=false) used by collect_targets/init_current_weapon

### `0.29.12`
- src/spectra/aim_refresh.lua: collect_targets FindComponentByClass optional-self call
- src/spectra/mutation_runtime.lua: get_data_table inherits exact P0.29.12 optional-self ABI
- src/spectra/aim_runtime.lua: P0.29.71 ClientBaseSetting.Get optional-self call

## Mechanically derived payload capture consumers

### `0.29.2`
- `0.29.3` `U0`: CALL@6
- `0.29.4` `U0`: CALL@6
- `0.29.5` `U1`: CALL@7
- `0.29.8` `U1`: CALL@10
- `0.29.11` `U1`: CALL@10
- `0.29.13` `U1`: CALL@8
- `0.29.15` `U0`: CALL@12
- `0.29.18` `U1`: CALL@12
- `0.29.19` `U0`: CALL@10, CALL@42
- `0.29.21` `U0`: CALL@6
- `0.29.27` `U8`: CALL@63
- `0.29.28` `U7`: CALL@49
- `0.29.29` `U7`: CALL@100
- `0.29.44` `U3`: CALL@34, CALL@55
- `0.29.47` `U1`: CALL@29
- `0.29.48` `U1`: CALL@20, CALL@48
- `0.29.49` `U1`: CALL@22, CALL@40
- `0.29.56` `U2`: CALL@27, CALL@52
- `0.29.57` `U1`: CALL@23, CALL@49
- `0.29.62` `U3`: CALL@40, CALL@44, CALL@87
- `0.29.63` `U1`: CALL@16, CALL@22, CALL@45, CALL@68, CALL@91
- `0.29.65` `U9`: CALL@311, CALL@327, CALL@343, CALL@359, CALL@375, CALL@391
- `0.29.66` `U8`: CALL@63
- `0.29.67` `U3`: capture observed; no direct call site proven by the local scan
- `0.29.71` `U2`: CALL@52, CALL@71, CALL@93
- `0.29.72` `U1`: capture observed; no direct call site proven by the local scan
- `0.29.74` `U1`: CALL@13, CALL@18, CALL@48, CALL@55, CALL@67, CALL@71, CALL@75, CALL@129
- `0.29.75` `U2`: CALL@37
- `0.29.76` `U2`: CALL@30, CALL@34
- `0.29.78` `U2`: CALL@32
- `0.29.84` `U2`: CALL@31, CALL@185, CALL@199, CALL@334
- `0.29.85` `U2`: CALL@79
- `0.29.87` `U6`: capture observed; no direct call site proven by the local scan
- `0.29.91` `U4`: CALL@27
- `0.29.98` `U1`: CALL@16
- `0.29.104` `U4`: CALL@47
- `0.29.105` `U2`: CALL@37, CALL@234, CALL@254

### `0.29.2.0`
- None at the direct P0.29 child-capture layer.

### `0.29.3`
- `0.29.6` `U1`: CALL@17
- `0.29.74` `U4`: CALL@38, CALL@92, CALL@101, CALL@147
- `0.29.75` `U3`: CALL@44
- `0.29.78` `U1`: CALL@21, CALL@61
- `0.29.84` `U3`: CALL@49, CALL@210, CALL@243, CALL@255, CALL@276, CALL@301
- `0.29.85` `U3`: CALL@98
- `0.29.86` `U3`: CALL@42
- `0.29.87` `U1`: CALL@28, CALL@38, CALL@71
- `0.29.92` `U1`: CALL@27, CALL@34, CALL@39, CALL@44
- `0.29.93` `U5`: CALL@60, CALL@92, CALL@104, CALL@109, CALL@114, CALL@134, CALL@147, CALL@157
- `0.29.94` `U3`: CALL@37, CALL@77, CALL@84, CALL@106, CALL@117, CALL@138, CALL@143, CALL@148
- `0.29.98` `U2`: CALL@20
- `0.29.104` `U2`: CALL@20, CALL@25, CALL@37, CALL@60, CALL@67
- `0.29.107` `U1`: CALL@11, CALL@27, CALL@38

### `0.29.4`
- `0.29.74` `U3`: CALL@30
- `0.29.76` `U1`: CALL@20, CALL@43
- `0.29.90` `U0`: CALL@8, TAILCALL@20

### `0.29.12`
- `0.29.13` `U2`: CALL@13
- `0.29.44` `U4`: CALL@59
- `0.29.48` `U2`: CALL@24
- `0.29.49` `U2`: CALL@27
- `0.29.56` `U3`: CALL@40
- `0.29.57` `U2`: CALL@36
- `0.29.71` `U3`: CALL@57
- `0.29.74` `U2`: CALL@20, CALL@81

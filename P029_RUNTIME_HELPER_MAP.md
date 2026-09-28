# P0.29 Runtime Helper Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

Names are reconstructed semantic labels, not recovered stripped symbols.

Payload closures are not dynamically rebound. Source-owned callers use exact source helpers directly.

| Prototype | Register | Params | Instructions | Upvalues | Source symbol | Return contract |
|---|---:|---:|---:|---:|---|---|
| `0.29.5` | `R22` | 2 | 15 | 2 | `P029RuntimeHelpers.is_function_field` | exactly one boolean: true only when protected field value has type function |
| `0.29.6` | `R23` | 1 | 33 | 2 | `P029RuntimeHelpers.object_name` | nil input returns exactly one empty string; successful/fallback tostring is a tail return |
| `0.29.8` | `R25` | 2 | 33 | 2 | `P029RuntimeHelpers.delay` | exactly zero values on every normal path |
| `0.29.11` | `R31` | 0 | 19 | 2 | `P029RuntimeHelpers.get_table_manager` | exactly one value: truthy Facade.TableManager or raw global TableManager fallback |
| `0.29.13` | `R33` | 1 | 20 | 3 | `P029RuntimeHelpers.get_data_table` | exactly one value: GetTable first result on success, otherwise nil |

## MutationRuntime integration

- `MutationRuntime.safe_get` reuses `AimABI.get`.
- `MutationRuntime.call_optional_self` reuses `AimABI.call_optional_self`.
- `MutationRuntime.get_table_manager` / `get_data_table` reuse P0.29.11 / P0.29.13 source helpers.

## Source consumers

### `0.29.5`
- src/spectra/visual_scan.lua: P0.29.81 is_mesh_component SetMaterial/SetOverlayMaterial predicates

### `0.29.6`
- src/spectra/visual_scan.lua: P0.29.85 is_ai_actor object-name normalization

### `0.29.8`
- src/spectra/payload_feature_bridge.lua: P0.29.77 delay dependency injection

### `0.29.11`
- src/spectra/mutation_runtime.lua: get_table_manager/get_data_table/apply_feature

### `0.29.13`
- src/spectra/mutation_runtime.lua: get_data_table/apply_feature
- src/spectra/aim_bones.lua: refresh_bone_table consumes MutationRuntime.get_data_table

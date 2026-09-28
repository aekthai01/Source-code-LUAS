# P0.29 Aim Runtime Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

This subsystem map source-owns `P0.29.71/.71.0` and `P0.29.72/.72.0`; adjacent P69/P70 ownership is unchanged; P73 is tracked by P029_FEATURE_CONTROL_MAP.

| Prototype | Parent register | Params | Instructions | Upvalues | Children | Source symbol | Return contract |
|---|---:|---:|---:|---:|---:|---|---|
| `0.29.71` | `R96` | 1 | 108 | 4 | 1 | `AimRuntime.set_native_aim_assist` | exactly one boolean on every reachable parent path; success path returns setter pcall success |
| `0.29.71.0` | `nested` | 0 | 6 | 2 | 0 | `AimRuntime.set_native_aim_assist nested assignment closure` | exactly zero values; parent pcall observes only success/error |
| `0.29.72` | `R97` | 1 | 22 | 3 | 1 | `AimRuntime.set_fire_assisted_aim_debug` | exactly one value: immediate P0.29.72.0 boolean result |
| `0.29.72.0` | `nested` | 0 | 76 | 3 | 0 | `AimRuntime.set_fire_assisted_aim_debug nested apply -> execute_console` | exactly one boolean on every path |

## P0.29.71.0 parent capture map

- `U0` <- P0.29.71 local R10 ClientBaseSetting instance
- `U1` <- P0.29.71 local R11 desired boolean

## P0.29.72.0 parent capture map

- `U0` <- P0.29.72 U0 environment
- `U1` <- P0.29.72 U1 / root R19 / P0.29.2
- `U2` <- P0.29.72 local R1 command string

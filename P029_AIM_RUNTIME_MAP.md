# P0.29 Aim Runtime Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

This checkpoint source-owns only `P0.29.72` and `P0.29.72.0`; adjacent P71/P73 ownership is unchanged.

| Prototype | Parent register | Params | Instructions | Upvalues | Children | Source symbol | Return contract |
|---|---:|---:|---:|---:|---:|---|---|
| `0.29.72` | `R97` | 1 | 22 | 3 | 1 | `AimRuntime.set_fire_assisted_aim_debug` | exactly one value: immediate P0.29.72.0 boolean result |
| `0.29.72.0` | `nested` | 0 | 76 | 3 | 0 | `AimRuntime.set_fire_assisted_aim_debug nested apply -> execute_console` | exactly one boolean on every path |

## P0.29.72.0 parent capture map

- `U0` <- P0.29.72 U0 environment
- `U1` <- P0.29.72 U1 / root R19 / P0.29.2
- `U2` <- P0.29.72 local R1 command string

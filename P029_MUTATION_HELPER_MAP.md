# P0.29 Mutation Helper Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

Names are reconstructed semantic labels. Payload copies are not dynamically rebound.

| Prototype | Root register | Params | Instructions | Captures | Source symbol | Return contract |
|---|---:|---:|---:|---|---|---|
| `0.29.10` | `R30` | 1 | 17 | environment only | `MutationRuntime.normalize_identifier` | tail-return string.gsub: exactly normalized string plus substitution count |
| `0.29.18` | `R38` | 1 | 40 | R19/0.29.2 | `MutationRuntime.table_extend` | exactly one value: table extension only on successful protected call yielding table, else original input |
| `0.29.49` | `R74` | 2 | 71 | R19/0.29.2, R32/0.29.12 | `MutationRuntime.array_get` | exactly one value: zero-based table read or protected userdata Get/helper Get with false preserved and nil fallback |

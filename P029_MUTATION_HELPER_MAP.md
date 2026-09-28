# P0.29 Mutation Helper Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

Names are reconstructed semantic labels. Payload copies are not dynamically rebound.

| Prototype | Root register | Params | Instructions | Captures | Source symbol | Return contract |
|---|---:|---:|---:|---|---|---|
| `0.29.10` | `R30` | 1 | 17 | environment only | `MutationRuntime.normalize_identifier` | tail-return string.gsub: exactly normalized string plus substitution count |
| `0.29.14` | `R34` | 1 | 27 | environment only | `MutationRuntime.p029_ensure_feature_snapshot` | exactly one snapshot table; captured state table identity |
| `0.29.15` | `R35` | 4 | 48 | R19/0.29.2, R34/0.29.14 | `MutationRuntime.p029_snapshot_set` | nil owner/key and unchanged paths exactly one boolean; assignment tailcalls pcall so success is one true and failure is false,error |
| `0.29.16` | `R36` | 1 | 11 | environment only | `MutationRuntime.p029_clear_feature_snapshot` | exactly zero returns after clearing captured state snapshot entry when snapshot root is a table |
| `0.29.18` | `R38` | 1 | 40 | R19/0.29.2 | `MutationRuntime.table_extend` | exactly one value: table extension only on successful protected call yielding table, else original input |
| `0.29.49` | `R74` | 2 | 71 | R19/0.29.2, R32/0.29.12 | `MutationRuntime.array_get` | exactly one value: zero-based table read or protected userdata Get/helper Get with false preserved and nil fallback |

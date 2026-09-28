# P0.29 Feature-Control Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

This bounded map source-owns only `P0.29.73`. P69/P70 remain payload-owned and P77 ownership/timing is unchanged.

The public name `set_dongdong_feature_config` is directly proven by the P0.29 bytecode export. Other labels are reconstructed semantics.

| Upvalue | Descriptor | Root register | Prototype | Reconstructed role / source symbol |
|---|---|---:|---|---|
| `U0` | `{"instack":1,"idx":0}` | `R0` | `n/a` | captured P0.29 invocation state containing custom_dongdong_toggle_state |
| `U1` | `{"instack":0,"idx":0}` | `outer environment` | `n/a` | environment |
| `U2` | `{"instack":1,"idx":85}` | `R85` | `0.29.60` | restore_bone_array_snapshots-equivalent / `MutationRuntime.restore_bone_array_snapshots` |
| `U3` | `{"instack":1,"idx":37}` | `R37` | `0.29.17` | restore_feature_snapshot-equivalent / `MutationRuntime.restore_feature_snapshot` |
| `U4` | `{"instack":1,"idx":93}` | `R93` | `0.29.68` | apply_feature-equivalent / `MutationRuntime.apply_feature` |
| `U5` | `{"instack":1,"idx":96}` | `R96` | `0.29.71` | set_native_aim_assist-equivalent / `AimRuntime.set_native_aim_assist` |
| `U6` | `{"instack":1,"idx":97}` | `R97` | `0.29.72` | set_fire_assisted_aim_debug-equivalent / `AimRuntime.set_fire_assisted_aim_debug` |

## Exact closure contract

- Parent closure: `R98`, `CLOSURE` instruction `1058`; 2 params, 81 instructions, 7 upvalues, 0 children.
- Source constructor: `FeatureControl.make_feature_config(captured_state, captured_deps)`; returned closure ABI is exactly `(feature, enabled)`.
- Capture lifetime: state and U2..U6-equivalent helper function identities are fixed at construction.
- Unsupported feature names still receive the literal-true-normalized toggle write and return exactly one `false`, with no restore/apply/native/debug call.
- Payload closure rebinding: `false`.

## P0.29.77 integration

- P77 remains source-owned; this checkpoint does not change its ownership.
- Timing remains `0.12`, `0.04`, `0.10`, `0.38`.
- Production P77 consumes the same exact P73 closure constructed once at takeover/install time.

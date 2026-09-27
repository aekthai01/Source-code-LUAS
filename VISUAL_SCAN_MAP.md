# Character Visual / X-Ray Reconstruction Map

Source of truth: `embedded_payload.bin`, SHA-256
`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

This checkpoint materializes and tests the visual chain `P0.29.78..P0.29.103`.
Prototype IDs are original bytecode structure identifiers. Semantic Lua helper names are
reconstructed names, not recovered debug names.

## Source ownership in this checkpoint

Source-owned public globals after the known-good payload initializes:

- `set_ai_color`
- `set_real_player_color`
- `set_character_xray`

The source bridge also replaces the payload-installed fashion refresh callback and tick callback after payload initialization. The old tick callback is unregistered through `LuaTickController`, and the old fashion delegate callback is removed before the source callback is added.

## Reconstructed prototype group

- `P0.29.78`: bounded Lua/ULuaArray traversal
- `P0.29.79`: unique object collection
- `P0.29.80`: array collection wrapper
- `P0.29.81`: mesh-component capability check
- `P0.29.82`: unique mesh insertion
- `P0.29.83`: mesh collection from table/userdata containers
- `P0.29.84`: character/component/child mesh traversal
- `P0.29.85`: AI/bot classification
- `P0.29.86`: character-class cache
- `P0.29.87`: world actor enumeration
- `P0.29.88`: red/green linear-color construction
- `P0.29.89`: FName/name conversion cache
- `P0.29.90`: vector parameter setter
- `P0.29.91`: X-Ray material loading/cache
- `P0.29.92`: original material/custom-depth restore
- `P0.29.93`: X-Ray material/depth application
- `P0.29.94`: normal dynamic-material color application
- `P0.29.95`: category restore
- `P0.29.96`: actor-scan state reset
- `P0.29.97`: rescan revision + delayed scan schedule
- `P0.29.98`: batched actor/mesh scanner
- `P0.29.99..103`: public visual entry points
- `P0.29.104`: `DFMCharacterItemFashionManager.OnSetMatTaskComplete` refresh hook
- `P0.29.106`: 0.25-second fallback scan loop when tick registration is unavailable
- `P0.29.107`: `LuaTickController` registration/throttled scan callback

## Exact timing / limits recovered

- rescan schedule: `0.0`, `0.08`, `0.24`, `0.6`, `1.2` seconds
- actor snapshot refresh threshold: 4 scan attempts
- mesh refresh threshold: 2 scan attempts
- X-Ray material retry threshold: 2 attempts
- normal-color retry threshold: 4 attempts
- scan batch: 8 actors
- traversal queue cap in `P0.29.84`: 32 queued objects
- table/container traversal caps: 64 / 128 / 256 depending on helper path

## X-Ray materials

- red: `/Game/MaterialLib/Materials/Character/ArmsEffect/MI_XrayOutLine_03_LQ_Red.MI_XrayOutLine_03_LQ_Red`
- green: `/Game/MaterialLib/Materials/Character/ArmsEffect/MI_Simple_XrayOutLine_Scout_Green.MI_Simple_XrayOutLine_Scout_Green`

X-Ray application preserves original materials once, sets overlay material, enables custom
depth, and uses stencil value `20`. Disable/restore resets overlay to nil, custom depth to
false, and stencil to `0`.

## Normal color parameters

The bytecode probes these exact vector parameter names:

`BaseColor`, `SkinColor`, `2UDyeColor`, `DyeColor`, `Color`, `TintColor`, `BaseColorTint`,
`BaseColorAdd`, `RootColor`, `TipColor`, `HighlightColor`, `MainColor`, `PrimaryColor`,
`BodyColor`, `CharacterColor`, `ColorTint`, `EmissiveColor`, `RimColor`, `FresnelColor`,
`OutlineColor`.

## Remaining visual boundary

The active public visual globals, immediate rescan scanner, fashion refresh hook, and periodic tick/fallback scan loop are source-owned after payload initialization. The original payload bytes still contain their dormant implementations because the payload remains byte-identical, but the source bridge replaces their active callbacks. Game-runtime execution is still required before claiming engine-level behavioral identity.

# Root P0 Capture Map

Source of truth: `embedded_payload.bin` SHA-256 `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

Logger roles below are inferred from actual child call sites, not from invented stripped names.

| Root register | Root value | Semantic role | Direct child upvalue captures |
|---|---|---|---|
| `R0` | `GenLocalLogFunc result #1` | `debug_logger` | P0.7 U2 |
| `R1` | `GenLocalLogFunc result #2` | `info_logger` | P0.3 U0, P0.10 U1, P0.12 U3, P0.24 U2, P0.26 U2, P0.27 U1, P0.28 U2 |
| `R2` | `GenLocalLogFunc result #3` | `error_logger` | P0.3 U2, P0.7 U4, P0.8 U1, P0.12 U0, P0.19 U0, P0.22 U5 |
| `R3` | `new root product table` | `product_table` | P0.0 U1, P0.1 U0, P0.2 U0, P0.3 U3, P0.4 U1, P0.7 U3, P0.11 U1, P0.12 U2, P0.14 U2, P0.15 U1, P0.18 U1, P0.19 U4, P0.20 U0, P0.21 U0, P0.22 U4, P0.25 U1 |
| `R4` | `require('DFM.StandaloneLua.BusinessTool.ItemHelperTool')` | `item_helper` | P0.7 U1, P0.19 U2, P0.22 U1, P0.28 U0 |
| `R5` | `require('DFM.StandaloneLua.BusinessTool.StructTool.ItemConfigTool')` | `item_config_tool` | P0.22 U2 |
| `R6` | `require('DFM.StandaloneLua.BusinessTool.StructTool.WeaponAssemblyTool')` | `weapon_assembly_tool` | P0.13 U2, P0.19 U3, P0.22 U3 |
| `R7` | `require('DFM.StandaloneLua.BusinessTool.WeaponHelperTool')` | `weapon_helper_tool` | none |
| `R8` | `require('DFM.StandaloneLua.BusinessTool.StructTool.ItemBaseTool')` | `item_base_tool` | P0.14 U1, P0.15 U2 |
| `R9` | `require('DFM.Business.Module.ArmedForceModule.Logic.ArmedForce.ArmedForceExpiredLogic')` | `armed_force_expired_logic` | P0.18 U2 |
| `R10` | `import('AmmoDataManager')` | `ammo_data_manager_module` | none |
| `R11` | `AmmoDataManager.Get()` | `ammo_data_manager` | P0.13 U1 |

## Semantic proof points

- `R0`: P0.7 U2 -> P0.7.0 inherited U3; called before '[Debug] Get Value = '
- `R1`: P0.3 U0 normal START/result/END diagnostics
- `R1`: P0.10 U1 equipment price diagnostics
- `R2`: P0.3 U2 rental-plan nil error
- `R2`: P0.7 U4 -> P0.7.0 inherited U6 negative checkValue error
- `R2`: P0.8 U1 -> P0.8.0 inherited U3 negative durability checkValue error
- `R3`: P0.3 U3 reads CheckEquipSlotValue
- `R3`: P0.7 U3 -> P0.7.0 inherited U4 reads GetMatchBulletNumByWeaponItem
- `R4`: P0.7 U1 -> P0.7.0 inherited U2 reads GetSubTypeById
- `R10`: root imports AmmoDataManager before fetching Get
- `R11`: root calls imported AmmoDataManager.Get() without self

## Source-only context contract

`src/spectra/product_context.lua` must recreate these root values directly from the runtime globals:

- call `GenLocalLogFunc(ELuaLogCategory.LuaMArmedForce)` once and preserve all three returned functions in R0/R1/R2 order;
- create a fresh source product table for R3;
- resolve the six exact `require` paths into R4..R9 in root bytecode order;
- call `import('AmmoDataManager')` for R10, then call its `Get` function with no implicit self for R11.

Payload-closure introspection is not part of this contract.

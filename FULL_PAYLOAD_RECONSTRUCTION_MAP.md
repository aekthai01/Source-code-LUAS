# Full Payload Reconstruction Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`. Prototype count: **296**.

The current compact ownership index is `FULL_PAYLOAD_PROTOTYPE_INDEX.json`. The prior verbose structural index is retained as `FULL_PAYLOAD_PROTOTYPE_INDEX_LEGACY_DETAILED.json`; bytecode constants/upvalues remain independently reproducible from the payload metadata files.

## Root capture/context layer

`ROOT_CAPTURE_MAP.json` derives P0 R0..R11 from root bytecode. `src/spectra/product_context.lua` recreates the three loggers, six required tools, AmmoDataManager import/Get result, and a fresh source product table without inspecting payload closures.

## Root public API P0.0..P0.28

| Prototype | Exact exported name | Ownership | Source-only dependency | Source |
|---|---|---|---|---|
| `P0.0` | `CheckEquipmentBeforEnterGameProcess` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.1` | `_CheckProcess` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.2` | `_CheckEquipmentValue` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.3` | `GetAllEquipmentValue` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.4` | `_CheckMedicine` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.5` | `_CheckUnCarryMedicine` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.6` | `_CheckContainer` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.7` | `_CheckBullet` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.8` | `_CheckDurabulity` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.9` | `CheckEquipSlotEmpty` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.10` | `CheckEquipSlotValue` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.11` | `DynamicGuidPriceFinishFetch` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.12` | `CheckRaidBulletEnough` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.13` | `GetMatchBulletNumByWeaponItem` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.14` | `_CheckNightFight` | `payload_owned` | `false` | `payload` |
| `P0.15` | `_CheckPlayerSuppliesForNightSpeicalType` | `payload_owned` | `false` | `payload` |
| `P0.16` | `_CheckSafeBoxExpiredStatus` | `payload_owned` | `false` | `payload` |
| `P0.17` | `_CheckKeyChainExpiredStatus` | `payload_owned` | `false` | `payload` |
| `P0.18` | `_CheckPropExpiredStatus` | `payload_owned` | `false` | `payload` |
| `P0.19` | `CheckPlayerBodyItemsByList` | `payload_owned` | `false` | `payload` |
| `P0.20` | `CheckNightVisionLimitByList` | `payload_owned` | `false` | `payload` |
| `P0.21` | `CheckThermalImagingLimitByList` | `payload_owned` | `false` | `payload` |
| `P0.22` | `CheckPlayerBodyItemsEntryQuality` | `payload_owned` | `false` | `payload` |
| `P0.23` | `CheckRentalConsumableID` | `payload_owned` | `false` | `payload` |
| `P0.24` | `_CheckPropinfoDownloadWithLog` | `payload_owned` | `false` | `payload` |
| `P0.25` | `_CheckItemWithCompsDownloaded` | `payload_owned` | `false` | `payload` |
| `P0.26` | `_CheckItemIdDownloaded` | `payload_owned` | `false` | `payload` |
| `P0.27` | `_CheckAllWeaponPartDownloaded` | `payload_owned` | `false` | `payload` |
| `P0.28` | `GetNeedDownloadCategaryKey` | `payload_owned` | `false` | `payload` |

Exact root fields: `EquipTypeList`, `ContainerTypeList`.

## P0.0..P0.13 source-only preparation

- All fourteen public methods P0.0..P0.13 receive source-owned captures and helpers; none use `debug.getupvalue`.
- P0.3 uses source `info_logger` (R1) and `error_logger` (R2).
- P0.7/P0.7.0 use source `ItemHelperTool` (R4), `debug_logger` (R0), `error_logger` (R2), and the owning product table passed by the source constructor.
- P0.8/P0.8.0 use source `error_logger` (R2).
- P0.10 uses source `info_logger` (R1) as the price logger.
- P0.11 uses the P0.11 U0 globals environment and U1 captured source R3; its one argument is a truthiness gate, and the R3 child call is plain and zero-argument.
- P0.12 maps U0 to R2 error_logger, U1 to root globals, U2 to R3 product table and U3 to R1 info_logger; its nested P0.12.0 callback captures the slot group, matchModeID, product table, enough flag, logger and abnormal-data table.
- P0.13 uses root R11 AmmoDataManager plus R6 WeaponAssemblyTool; parent 0.13 and nested 0.13.0 map to this independent source. It preserves the four-container bullet scan and raw-prop open returns without substituting a generic inventory scan.
- `ProductModule.create(context, globals)` creates/binds P0.0..P0.13 on the same source R3 product table and emits exact `EquipTypeList` / `ContainerTypeList` order.
- The transitional payload overlay remains restorable; P0.0..P0.13 neither inspect nor call payload closures and do not extract payload upvalues.

## Current ownership

- Source-owned: **91**
- Payload-owned: **205**
- Partially reconstructed: **0**
- Unknown: **0**
- Root methods source-owned: **14 / 29**

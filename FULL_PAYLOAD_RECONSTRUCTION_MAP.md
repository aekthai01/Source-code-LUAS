# Full Payload Reconstruction Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`. Prototype count: **296**.

The current compact ownership index is `FULL_PAYLOAD_PROTOTYPE_INDEX.json`. The prior verbose structural index is retained as `FULL_PAYLOAD_PROTOTYPE_INDEX_LEGACY_DETAILED.json`; bytecode constants/upvalues remain independently reproducible from the payload metadata files.

## Root capture/context layer

`ROOT_CAPTURE_MAP.json` derives P0 R0..R13 from root bytecode. `src/spectra/product_context.lua` recreates the three loggers, six required tools, AmmoDataManager import/Get result, and a fresh source product table; `product_constructor.lua` allocates independent R12/R13 per-product download-log sets without inspecting payload closures.

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
| `P0.14` | `_CheckNightFight` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.15` | `_CheckPlayerSuppliesForNightSpeicalType` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.16` | `_CheckSafeBoxExpiredStatus` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.17` | `_CheckKeyChainExpiredStatus` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.18` | `_CheckPropExpiredStatus` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.19` | `CheckPlayerBodyItemsByList` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.20` | `CheckNightVisionLimitByList` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.21` | `CheckThermalImagingLimitByList` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.22` | `CheckPlayerBodyItemsEntryQuality` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.23` | `CheckRentalConsumableID` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.24` | `_CheckPropinfoDownloadWithLog` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.25` | `_CheckItemWithCompsDownloaded` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.26` | `_CheckItemIdDownloaded` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.27` | `_CheckAllWeaponPartDownloaded` | `source_owned` | `true` | `src/spectra/product_module.lua` |
| `P0.28` | `GetNeedDownloadCategaryKey` | `source_owned` | `true` | `src/spectra/product_module.lua` |

Exact root fields: `EquipTypeList`, `ContainerTypeList`.

## P0.0..P0.28 source-only root API

- All twenty-nine public methods P0.0..P0.28 receive source-owned captures and helpers; none use `debug.getupvalue`.
- P0.3 uses source `info_logger` (R1) and `error_logger` (R2).
- P0.7/P0.7.0 use source `ItemHelperTool` (R4), `debug_logger` (R0), `error_logger` (R2), and the owning product table passed by the source constructor.
- P0.8/P0.8.0 use source `error_logger` (R2).
- P0.10 uses source `info_logger` (R1) as the price logger.
- P0.11 uses the P0.11 U0 globals environment and U1 captured source R3; its one argument is a truthiness gate, and the R3 child call is plain and zero-argument.
- P0.12 maps U0 to R2 error_logger, U1 to root globals, U2 to R3 product table and U3 to R1 info_logger; its nested P0.12.0 callback captures the slot group, matchModeID, product table, enough flag, logger and abnormal-data table.
- P0.13 uses root R11 AmmoDataManager plus R6 WeaponAssemblyTool; parent 0.13 and nested 0.13.0 map to this independent source. It preserves the four-container bullet scan and raw-prop open returns without substituting a generic inventory scan.
- P0.14 uses root R8 ItemBaseTool plus source R3 product. It preserves pairs value traversal, two matchModeIDList reads, dynamic R3 helper lookup, and exact LackNight abnormal shape.
- P0.15 uses source R3 EquipTypeList/ContainerTypeList plus root R8 ItemBaseTool. It preserves ipairs order, plain two-argument support-helper ABI, early returns, and exact false on a complete miss.
- P0.16/P0.17 preserve distinct ExpiredStatus gates, Inventory SELF calls, slot subtypes and four-field abnormal records.
- P0.18 uses source R3 traversal lists plus root R9 ArmedForceExpiredLogic with a plain one-argument CheckExpired ABI and exact three-field ExpiredProp record.
- P0.19/P0.19.0 use source R3 traversal lists plus R2/R4/R6 captures, one-result receiver raw-prop semantics, static expansion ABI, matched-map dedupe and engine `table.keys` ordering.
- P0.20/P0.21 remain distinct exports and tail-forward every return through a dynamic source R3 `CheckPlayerBodyItemsByList` lookup.
- P0.22/P0.22.0/P0.22.1/P0.22.2 preserve setdefault(false,true), strict comparators, exact three-slot result state and static R4/R5/R6 helper ABIs.
- P0.23 preserves the RentalVoucherDoNotMeetEntryRequirements gate, ArmedForce SELF call and exact four-field abnormal record with an empty `param` table.
- P0.24/P0.26 capture independent R12/R13 log sets allocated once per product root; P0.27 has no dedupe. P0.25/P0.25.0 preserve shipping traversal and non-shipping early return with dynamic R3 helper lookup.
- P0.28/P0.28.0 preserve static R4 item helper calls, raw prop priority, the first-component recursive tailcall, and the parent one-result clamp.
- `ProductModule.create(context, globals)` creates/binds P0.0..P0.28 on the same source R3 product table and emits exact `EquipTypeList` / `ContainerTypeList` order.
- The transitional payload overlay remains restorable; P0.0..P0.28 neither inspect nor call payload closures and do not extract payload upvalues.
- Root public API migration is complete; full payload reconstruction is NOT complete. Payload-owned prototypes (predominantly under P0.29) remain.
- P0.29 ABI helpers 2/2.0/3/4/12 and runtime helpers 5/6/8/11/13 are source-owned for source consumers without dynamically rebinding payload-owned closure copies.

## Current ownership

- Source-owned: **130**
- Payload-owned: **166**
- Partially reconstructed: **0**
- Unknown: **0**
- Root methods source-owned: **29 / 29**

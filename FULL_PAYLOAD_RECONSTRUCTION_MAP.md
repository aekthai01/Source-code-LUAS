# Full Payload Reconstruction Map

Evidence payload SHA-256: `a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`. Prototype count verified from all three machine artifacts: `296`.

All prototype names without a recovered public root export are reconstructed descriptions. The index omits unresolved/dynamic call edges rather than guessing.

## Root public API P0.0..P0.28

| Prototype | Exact exported name | Ownership | Source |
|---|---|---|---|
| `P0.0` | `CheckEquipmentBeforEnterGameProcess` | `source_owned` | `src/spectra/product_module.lua` |
| `P0.1` | `_CheckProcess` | `source_owned` | `src/spectra/product_module.lua` |
| `P0.2` | `_CheckEquipmentValue` | `source_owned` | `src/spectra/product_module.lua` |
| `P0.3` | `GetAllEquipmentValue` | `partially_reconstructed` | `src/spectra/product_module.lua` |
| `P0.4` | `_CheckMedicine` | `source_owned` | `src/spectra/product_module.lua` |
| `P0.5` | `_CheckUnCarryMedicine` | `source_owned` | `src/spectra/product_module.lua` |
| `P0.6` | `_CheckContainer` | `source_owned` | `src/spectra/product_module.lua` |
| `P0.7` | `_CheckBullet` | `partially_reconstructed` | `src/spectra/product_module.lua` |
| `P0.8` | `_CheckDurabulity` | `payload_owned` | `payload` |
| `P0.9` | `CheckEquipSlotEmpty` | `payload_owned` | `payload` |
| `P0.10` | `CheckEquipSlotValue` | `payload_owned` | `payload` |
| `P0.11` | `DynamicGuidPriceFinishFetch` | `payload_owned` | `payload` |
| `P0.12` | `CheckRaidBulletEnough` | `payload_owned` | `payload` |
| `P0.13` | `GetMatchBulletNumByWeaponItem` | `payload_owned` | `payload` |
| `P0.14` | `_CheckNightFight` | `payload_owned` | `payload` |
| `P0.15` | `_CheckPlayerSuppliesForNightSpeicalType` | `payload_owned` | `payload` |
| `P0.16` | `_CheckSafeBoxExpiredStatus` | `payload_owned` | `payload` |
| `P0.17` | `_CheckKeyChainExpiredStatus` | `payload_owned` | `payload` |
| `P0.18` | `_CheckPropExpiredStatus` | `payload_owned` | `payload` |
| `P0.19` | `CheckPlayerBodyItemsByList` | `payload_owned` | `payload` |
| `P0.20` | `CheckNightVisionLimitByList` | `payload_owned` | `payload` |
| `P0.21` | `CheckThermalImagingLimitByList` | `payload_owned` | `payload` |
| `P0.22` | `CheckPlayerBodyItemsEntryQuality` | `payload_owned` | `payload` |
| `P0.23` | `CheckRentalConsumableID` | `payload_owned` | `payload` |
| `P0.24` | `_CheckPropinfoDownloadWithLog` | `payload_owned` | `payload` |
| `P0.25` | `_CheckItemWithCompsDownloaded` | `payload_owned` | `payload` |
| `P0.26` | `_CheckItemIdDownloaded` | `payload_owned` | `payload` |
| `P0.27` | `_CheckAllWeaponPartDownloaded` | `payload_owned` | `payload` |
| `P0.28` | `GetNeedDownloadCategaryKey` | `payload_owned` | `payload` |

Exact root fields: `EquipTypeList`, `ContainerTypeList`.

## P0.0..P0.7 source boundary

- `P0.0` retains the recovered `CheckMainFlowSOL` result branch, a second `GetCurrentGameFlow` call only on false, Lobby equality return, reset, `_CheckProcess`, and changed event order.
- `P0.1` calls the ten recovered checks in bytecode order and then `SortEquipAbnormal`.
- `P0.2` reads current equipment value and both map thresholds, uses strict `<` / `>` comparisons with zero-threshold guards and config switches, and emits the two recovered abnormal record shapes.
- `P0.3` keeps challenge currency selection, rental and slot sum paths, two-value return, and value-changed event. Its P0.3 U0/U2 diagnostic closures are taken from the original payload closure when the runtime exposes them; otherwise that method remains payload-owned.
- `P0.4` reads current medicine types before `table.values(EDispensingMedicineType)`, dispatches through the captured module table's current `_CheckUnCarryMedicine` field (P0.5), and adds `LackMedicine` only for a nonempty result list.
- `P0.5` uses `ipairs` order, `GetEquipmentCheckData(LackMedicine, type)`, the exact `switch` and `table.contains(current, type)` gates, maximum key aggregation, and ordered list appends without deduplication.
- `P0.6` collects `ChestHangingContainer`, `BagContainer`, and `Pocket` capacities in bytecode order, adds `1e-6` to each total/free value, applies the strict rounded-ratio comparison, selects the challenge/player safe-box group, and walks item collections through nested `P0.6.0`.
- `P0.7` and nested `P0.7.0` reconstruct left weapon, right weapon, then pistol checks; preserve captured helper/logger calls, strict insufficient-ammo comparison, negative check-value logging, maximum abnormal key, equal-subtype slot handling, and location order. The method bridge installs P0.7 only when the original closure's ItemHelperTool, both loggers, and identical product table are available; otherwise it leaves the payload method in place.
- The method bridge preserves originals and restores its writes on install failure. It rethrows source exceptions without retrying payload code because earlier operations may already have caused side effects.

## Current ownership groups

Source-owned prototypes: `79`; payload-owned: `214`; partially reconstructed: `3`; unknown: `0`.

`FULL_PAYLOAD_PROTOTYPE_INDEX.json` is the per-prototype authority. The method-level runtime bridge owns P0.0..P0.2 and P0.4..P0.6. P0.3 remains conditional on recovered logger captures; P0.7 is conditionally source-installable because its captured upvalues must match the original closure.

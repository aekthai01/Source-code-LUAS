# Payload Function Catalog

Source of truth: `embedded_payload.bin`, SHA-256
`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

Lua local/debug names are stripped. Prototype IDs are structural identifiers and source
helper names are reconstructed descriptions unless an exact public/global name is stated.

## Root module methods: exact bytecode strings

1. `CheckEquipmentBeforEnterGameProcess`
2. `_CheckProcess`
3. `_CheckEquipmentValue`
4. `GetAllEquipmentValue`
5. `_CheckMedicine`
6. `_CheckUnCarryMedicine`
7. `_CheckContainer`
8. `_CheckBullet`
9. `_CheckDurabulity`
10. `CheckEquipSlotEmpty`
11. `CheckEquipSlotValue`
12. `DynamicGuidPriceFinishFetch`
13. `CheckRaidBulletEnough`
14. `GetMatchBulletNumByWeaponItem`
15. `_CheckNightFight`
16. `_CheckPlayerSuppliesForNightSpeicalType`
17. `_CheckSafeBoxExpiredStatus`
18. `_CheckKeyChainExpiredStatus`
19. `_CheckPropExpiredStatus`
20. `CheckPlayerBodyItemsByList`
21. `CheckNightVisionLimitByList`
22. `CheckThermalImagingLimitByList`
23. `CheckPlayerBodyItemsEntryQuality`
24. `CheckRentalConsumableID`
25. `_CheckPropinfoDownloadWithLog`
26. `_CheckItemWithCompsDownloaded`
27. `_CheckItemIdDownloaded`
28. `_CheckAllWeaponPartDownloaded`
29. `GetNeedDownloadCategaryKey`

Exact root fields include `EquipTypeList` and `ContainerTypeList`.

## Full prototype inventory / Phase E1

`FULL_PAYLOAD_PROTOTYPE_INDEX.json` contains all 296 prototype paths with parent/child
structure, constants, upvalues, conservative direct calls, bytecode global/table references,
current ownership, static reachability, source mapping, evidence and confidence.
`FULL_PAYLOAD_RECONSTRUCTION_MAP.md` maps each of the exact root exports above to its
prototype. Current root overlay coverage is 3/29 source-owned methods; P0.3 is partial
because its original diagnostic upvalues are stripped and only installed when recovered
from the payload closure. See `RECONSTRUCTION_COVERAGE.md` for machine-generated totals.

The source for P0.0..P0.3 is in `src/spectra/product_module.lua`. P0.0-P0.2 are installed
through a rollback-capable module overlay after payload initialization. P0.3 source tests
cover challenge currency, rental value, slot summation and event arguments. Its bridge
installation requires original U0/U2 logger closures; absent captures leave the payload
method intact.

## Exact imported/required namespaces observed at payload root

- `DFM.StandaloneLua.BusinessTool.ItemHelperTool`
- `DFM.StandaloneLua.BusinessTool.StructTool.ItemConfigTool`
- `DFM.StandaloneLua.BusinessTool.StructTool.WeaponAssemblyTool`
- `DFM.StandaloneLua.BusinessTool.WeaponHelperTool`
- `DFM.StandaloneLua.BusinessTool.StructTool.ItemBaseTool`
- `DFM.Business.Module.ArmedForceModule.Logic.ArmedForce.ArmedForceExpiredLogic`
- `AmmoDataManager`

## Exact post-login public/global API

| Exact symbol | Prototype | Current runtime status |
| --- | --- | --- |
| `set_dongdong_feature_config` | `P0.29.73` | reconstructed source after payload init |
| `set_dongdong_aim_part` | `P0.29.77` | reconstructed source after payload init |
| `set_ai_color` | `P0.29.101` | reconstructed source after payload init |
| `set_real_player_color` | `P0.29.102` | reconstructed source after payload init |
| `set_character_xray` | `P0.29.103` | reconstructed source after payload init |
| `install_character_color_setting_hooks` | `P0.29.105` | reconstructed source installer |
| `InstallDongDongNativeSettingPage` | aliases `P0.29.105` | reconstructed source installer alias |

The feature API recognizes exactly:

- `no_recoil`
- `converge`
- `aim`
- `anti_shake`

Enabling `aim` or `anti_shake` preserves their mutual exclusivity.

## Aim reconstruction inventory

`AIM_PROTOTYPE_INDEX.json` contains the current implementation/ownership map:
**26 primary requested prototypes plus nested callbacks, 39 indexed entries total**.
The detailed pre-takeover structural metadata is archived in
`AIM_PROTOTYPE_INDEX_LEGACY_DETAILED.json`.

Current source-owned aim path includes:

| Prototype group | Source |
| --- | --- |
| `P0.29.30..43` | `src/spectra/aim_mutation.lua` |
| `P0.29.44` | `src/spectra/mutation_runtime.lua` |
| `P0.29.45`, `P0.29.61..64` | `src/spectra/aim_bones.lua` |
| `P0.29.65` | `src/spectra/aim_mutation.lua` |
| `P0.29.66..67` | `src/spectra/aim_chain.lua` |
| `P0.29.68` | `src/spectra/mutation_runtime.lua` |
| `P0.29.74..76` | `src/spectra/aim_refresh.lua` |
| `P0.29.77` | `src/spectra/feature_control.lua` |

`P0.29.68` is mapped with the reconstructed descriptive name `apply_feature`. Its
38-instruction behavior uses the captured feature-table list, `ipairs`, `P13` lookup,
raw table identity dedupe, `P67` dispatch and boolean aggregation. It does not add an
active-mode check or internal `pcall`.

`P0.29.65` uses `row_id` as its final source parameter. Differential fixtures cover
major ADS/fire branches, ordinary versus Gamepad assistor behavior, all six profile IDs,
and setting boundary/invalid conversion behavior.

`P0.29.74..76` reuse reconstructed `P2/P3/P4/P12` ABI semantics instead of generic local
helpers.

## Transactional public feature ownership

After the embedded payload initializes, `payload_feature_bridge.lua` preserves the
payload `set_dongdong_feature_config` and `set_dongdong_aim_part`, then installs the two
source entries as a pair.

- missing dependency: payload globals unchanged
- install failure after the first replacement: both globals rolled back
- source mutation failure: source state/snapshots restored, then saved payload called
- delayed `P77` callbacks call the captured source `P73`, preventing hybrid ownership

Unknown/unreconstructed feature keys continue to delegate to the saved payload function.

## Exact aim refresh method-name probes

- `RefreshAimAssistorConfig`
- `ReloadAimAssistorConfig`
- `RebuildAimAssistorConfig`
- `RefreshAimingConfig`
- `ReloadAimingConfig`
- `RebuildAimingConfig`
- `RefreshAimingData`
- `ReloadAimingData`
- `RebuildAimingData`
- `UpdateAimingData`
- `ApplyAimingData`
- `OnAimingDataChanged`
- `RefreshWeaponData`
- `ReloadWeaponData`
- `RebuildWeaponData`
- `UpdateWeaponData`
- `ApplyWeaponData`
- `OnWeaponDataChanged`

## Native settings UI hooks

`P0.29.105` hooks these exact methods on
`DFM.Business.Module.SystemSettingModule.UI.SystemSettingMainView`:

1. `_InitDynamicBtns`
2. `SetSelectedModePanel`
3. `OnInitExtraData`
4. `OnShowBegin`
5. `OnActivate`
6. `_FetchSettingSystemByTab`
7. `_UpdateSysetemSettingPanel`
8. `OnHideBegin`
9. `OnClose`

The spelling `_UpdateSysetemSettingPanel` is preserved from the payload.

## Visual source ownership

The reconstructed source owns the public visual entries plus the actor/mesh scan,
fashion refresh and periodic tick/fallback path represented by `P0.29.78..107` where
mapped in the Phase D documents.

## Runtime caveat

`game_runtime_test=false` remains authoritative. Source/CI ownership means the code path
is installed in the rebuilt wrapper; it does not mean the custom chunk has been executed
inside the real DFM/game runtime.

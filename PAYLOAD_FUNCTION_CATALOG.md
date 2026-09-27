# Payload Function Catalog

Source of truth: `embedded_payload.bin`, SHA-256
`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

This catalog deliberately separates **symbols present in bytecode** from names assigned
by reconstruction. Lua local/debug names were stripped, so unnamed prototypes cannot be
presented as recovered original function names.

## Root module methods: exact bytecode strings

The root payload table installs these method names verbatim:

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

Exact data-table fields installed on the root module:

- `EquipTypeList`
- `ContainerTypeList`

## Exact imported/required namespaces seen at payload root

- `DFM.StandaloneLua.BusinessTool.ItemHelperTool`
- `DFM.StandaloneLua.BusinessTool.StructTool.ItemConfigTool`
- `DFM.StandaloneLua.BusinessTool.StructTool.WeaponAssemblyTool`
- `DFM.StandaloneLua.BusinessTool.WeaponHelperTool`
- `DFM.StandaloneLua.BusinessTool.StructTool.ItemBaseTool`
- `DFM.Business.Module.ArmedForceModule.Logic.ArmedForce.ArmedForceExpiredLogic`
- `AmmoDataManager` via `import`, followed by `AmmoDataManager.Get()`

## Post-login feature API: exact global/public names

These names occur verbatim in payload prototype `0.29` and are assigned executable
closures there:

| Exact symbol | Prototype | Verified role |
|---|---:|---|
| `set_dongdong_feature_config` | `0.29.73` | Toggle/apply `no_recoil`, `converge`, `aim`, `anti_shake`; `aim` and `anti_shake` are mutually exclusive |
| `set_dongdong_aim_part` | `0.29.77` | Increment aim-part revision and schedule reapplication after 0.12 s |
| `set_ai_color` | `0.29.101` | Normalize/set AI highlight color and refresh character coloring |
| `set_real_player_color` | `0.29.102` | Normalize/set real-player color and refresh character coloring |
| `set_character_xray` | `0.29.103` | Enable/disable character X-Ray; disabling restores tracked mesh/material state |
| `install_character_color_setting_hooks` | `0.29.105` | Install the native `SystemSettingMainView` feature page hooks |
| `InstallDongDongNativeSettingPage` | aliases `0.29.105` | Global installer alias created via `rawset(_G, ...)` |

### Exact state globals used by the feature API

- `custom_dongdong_toggle_state`
- `custom_dongdong_aim_part_revision`
- `custom_dongdong_native_aim_state`
- `custom_ai_color_enabled`
- `custom_ai_color_key`
- `custom_ai_color_name`
- `custom_ai_color_last_key`
- `custom_real_color_key`
- `custom_real_color_name`
- `custom_character_xray_enabled`
- `custom_character_xray_meshes`
- `custom_character_xray_materials`
- `custom_character_color_attempt`
- `custom_character_color_active`
- `custom_character_fashion_refresh_hook`
- `custom_dongdong_api_settings`
- `__AUTHOR_XRAY_UI_TICK`

### Exact feature keys

`set_dongdong_feature_config` recognizes only these four keys:

- `no_recoil`
- `converge`
- `aim`
- `anti_shake`

`aim` and `anti_shake` are made mutually exclusive when enabling either one.

### Exact observed refresh/apply method-name probes

The payload probes these engine method names while refreshing aim/weapon state:

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

### Exact engine hooks used for character color/X-Ray

- `DFMCharacterItemFashionManager.OnSetMatTaskComplete`
- `LuaTickController:Get():RegisterTick(...)`
- prior `_G.__AUTHOR_XRAY_UI_TICK` is unregistered before replacement

## Native settings UI installer: exact hooks

Prototype `0.29.105` hooks exactly these nine methods on
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

`_UpdateSysetemSettingPanel` is intentionally spelled exactly as it appears in the
payload.

## Reconstructed helper names, not original symbols

The following names are used only in `src/spectra/native_settings_ui.lua` to make
prototype `0.29.105` readable. They are semantic names assigned from observed behavior;
the original local names are not recoverable from this stripped bytecode:

- `ensure_sub_ui_ids`
- `unwrap_cpp_instance`
- `get_from_weak`
- `make_margin`
- `slot_as_grid_slot`
- `loc_text`
- `configure_title_widget`
- `hide_title_line`
- `create_widget`
- `finish_title_load`
- `load_title_class_async`
- `add_grid_child`
- `cleanup_custom_page`
- `create_two_button`
- `set_full_width`
- `create_four_button`
- `create_slider`
- `build_page`
- `remove_existing_direct_tab`
- `add_custom_tab`
- `is_custom_tab_request`
- `safe_call_original`

Those helper names must not be interpreted as recovered source identifiers.

## Important distinction: `OpenSpectraControl`

The outer wrapper's exact global `OpenSpectraControl` does **not** open the post-login
feature page. In the baseline outer chunk it resets wrapper UI state and invokes the
welcome `ConfirmWindows` path. The post-login feature UI is installed by
`InstallDongDongNativeSettingPage` / prototype `0.29.105` inside the embedded payload.

This distinction is important because conflating the two would reconstruct the wrong
lifecycle even if the names looked convenient.

## Phase D2 reconstructed public entries

| Prototype | Exact exported/public role | Source status |
|---|---|---|
| `0.29.73` | `set_dongdong_feature_config` | reconstructed in `feature_control.lua`; D3 source owns `no_recoil`/`converge`, other keys delegate to payload |
| `0.29.77` | `set_dongdong_aim_part` | reconstructed in `feature_control.lua`; runtime takeover pending helper chain |
| `0.29.99` | color key normalization helper | reconstructed in `character_visuals.lua` |
| `0.29.100` | AI color normalization helper | reconstructed in `character_visuals.lua` |
| `0.29.101` | `set_ai_color` | reconstructed entry logic; runtime takeover pending rescan helpers |
| `0.29.102` | `set_real_player_color` | reconstructed entry logic; runtime takeover pending rescan helpers |
| `0.29.103` | `set_character_xray` | reconstructed entry logic; runtime takeover pending mesh/rescan helpers |

The helper labels used in the new source such as `restore_feature_snapshot`, `apply_feature`, `restore_mesh_category`, and `rescan_character_colors` are **reconstructed names**, not recovered original local names.

### D2 helper prototypes now represented in source

`0.29.0`, `0.29.71`, `0.29.72`, `0.29.92`, `0.29.95`, and `0.29.96` are reconstructed in `aim_runtime.lua` / `visual_runtime.lua`. Their helper names in source are reconstructed labels; the prototype IDs and engine/API strings are baseline-derived.

## Phase D3 mutation/runtime ownership

D3 adds source representations for the following stripped payload helpers. Names on the
right are reconstruction labels, not recovered local identifiers:

| Prototype | Reconstructed role | Runtime status |
|---|---|---|
| `0.29.10` | normalize identifier | source-owned dependency |
| `0.29.11` | resolve TableManager | source-owned dependency |
| `0.29.12` | protected optional-self call | source-owned dependency |
| `0.29.13` | resolve DataTable | source-owned dependency |
| `0.29.14`-`0.29.17` | feature snapshot create/write/clear/restore | source-owned dependency |
| `0.29.18`-`0.29.20` | TableExtend / field / iteration helpers | source-owned dependency |
| `0.29.21`-`0.29.26` | generic zero + recoil range/group/row mutation | source-owned for `no_recoil` |
| `0.29.29` | spread/dispersion/bloom recursive mutation | source-owned for `converge` |
| `0.29.44`, `0.29.46`, `0.29.48`-`0.29.60` | bone-name/array snapshot + restoration layer | source represented; aim takeover pending |
| `0.29.67` | per-DataTable row dispatcher | source-owned for D3-routed features |
| `0.29.68` | feature DataTable resolver/deduper | source-owned for D3-routed features |

After payload initialization, `payload_feature_bridge.lua` replaces the exact global
`set_dongdong_feature_config` with a dispatcher. The reconstructed source owns only
`no_recoil` and `converge`; `aim`, `anti_shake`, and unsupported keys delegate to the
captured original payload closure. This is deliberate, not an incomplete claim of full
feature takeover.

The replacement chain including `0.29.65` (842 instructions, 136 constants) is
materialized as source. The remaining D4 blocker is the full `P67` behavior and
transactional bridge with failure/rollback tests. `aim` and `anti_shake` runtime
behavior remains original-payload-owned.

## Materialized visual reconstruction status

`P0.29.78..98` are now represented in `src/spectra/visual_scan.lua`. Public exact globals
`set_ai_color`, `set_real_player_color`, and `set_character_xray` are published by
`src/spectra/payload_visual_bridge.lua` after the byte-identical payload initializes.
The post-`P0.29.103` periodic/fashion-refresh chain remains payload-owned.

### Aim reconstruction continuation

`src/spectra/aim_mutation.lua` now contains a readable `P0.29.65` replacement
function and the bytecode `R52` profile matrix (IDs `1`, `1001`, `1002`, `1003`,
`11001`, `1004`). The prototype structural index and branch-level return rules are
in `AIM_PROTOTYPE_INDEX.json` and `AIM_MUTATION_MAP.md`. Source function names are
reconstructed descriptive names, not original debug symbols. This source is bundled
for validation but has no active aim runtime caller yet. The `P0.29.66` walker,
aim-only `P0.29.67` branch and general `P0.29.68` dispatcher are source materialized;
the complete bridge remains payload-owned.

`P0.29.66` recursive field traversal is now materialized in `aim_mutation.lua`
with an inert source function and a snapshot/restore regression. It is not
connected to the active feature bridge.

The aim-only `P0.29.67` row branch is present with an explicit required
`P0.29.63` dependency. `aim_bones.lua` materializes `P0.29.45/61..64`;
`P0.29.68` dispatcher source is tested, while the active bridge delegates to payload.

The prototype index includes 39 top-level/nested entries and conservative
resolved CALL edges. Source bone remap/AI array/restore/refresh lives in
`aim_bones.lua`; active aim ownership is unchanged.

`aim_refresh.lua` contains inert `P0.29.74..76` source and focused Lua tests;
active aim/anti_shake remain payload-owned.

The source aim row helper is now callable by the source P67 dispatcher, and a
Gamepad fixture exercises P68/P67/P63/P66/P65 with field and bone restoration.
This covers one meaningful path; the full P67 error paths and transactional
P73/P77 dual-global bridge are still required before runtime takeover.

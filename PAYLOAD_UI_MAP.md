# Post-login Payload UI Map

Source of truth: embedded payload prototype `0.29.105`, especially child `0.29.105.17`.

## Where the UI lives

The feature UI is injected into the game's native `SystemSettingMainView`; it is not a
separate Spectra popup.

Exact dependencies referenced by the payload:

- `_G.UIName2ID`
- `_G.UITable`
- `_G.Facade.UIManager` or `_G.UIManager`
- `require("DFM.Business.Module.SystemSettingModule.UI.SystemSettingMainView")`
- `require("DFM.YxFramework.Managers.UI.Util.UIUtil")`
- `import("GridPanel")`
- `import("ScrollBox")`
- `import("WidgetBlueprintLibrary")`
- `import("WidgetLayoutLibrary")`

Exact `UIName2ID` keys:

- `SystemSettingMainView`
- `SettingBtnTwo`
- `SettingBtnFour`
- `SettingSlider`

Exact title asset:

`/Game/BluePrints/UI/UMG/Common/Library/WBP_TitleWithLine.WBP_TitleWithLine_C`

## Page title

Baseline payload constant: `@starrmods        `.

Reconstructed runtime title: `@DrkZeref`.

This is an **intentional user-requested divergence**, not a claim that the baseline
contained the new title. The old string remains only in forensic evidence/embedded
payload bytes because Phase D still embeds the known-good payload unchanged.

## Layout and controls

| Row | Column | Control | Options / range | Exact callback target |
|---:|---:|---|---|---|
| 0 | span 2 | Page title | `@DrkZeref` in reconstructed source | n/a |
| 1 | span 2 | `Combat` | section header | n/a |
| 2 | 0 | `No Recoil` | `Enable` / `Disable` | `set_dongdong_feature_config("no_recoil", ...)` |
| 2 | 1 | `Bullet Spread Control` | `Enable` / `Disable` | `set_dongdong_feature_config("converge", ...)` |
| 3 | 0 | `Hip-Fire Aim` | `Enable` / `Disable` | `set_dongdong_feature_config("aim", ...)` |
| 3 | 1 | `ADS Aim` | `Enable` / `Disable` | `set_dongdong_feature_config("anti_shake", ...)` |
| 4 | span 2 | `Visuals` | section header | n/a |
| 5 | 0 | `Bot Highlight` | `Enable` / `Disable` | `set_ai_color(...)` |
| 5 | 1 | `Bot Color` | `Red` / `Green` | `set_ai_color(...)` |
| 6 | 0 | `Player Color` | `Red` / `Green` | `set_real_player_color(...)` |
| 6 | 1 | `Player X-Ray` | `Enable` / `Disable` | `set_character_xray(...)` |
| 7 | span 2 | `Aim Settings` | section header | n/a |
| 8 | span 2 | `Target Bone` | `Head`, `Chest`, `Legs`, `Point & Shoot` | set aim-part state + `set_dongdong_aim_part()` |
| 9 | span 2 | `Aim Speed` | 1..100, default 50 | `_G.custom_aim_speed` |
| 10 | span 2 | `Aim FOV` | 1..360, default 90 | `_G.custom_aim_range` |
| 11 | span 2 | `Aim Distance` | 1..500, default 150 | `_G.custom_aim_distance` |
| 12 | span 2 | `Aim Lock Delay` | 1..100, default 1 | `_G.custom_aim_lock_time` |

Feature controls: **13**. Title/header widgets: **4**.

## Target-bone state

Exact normalized keys used by payload:

1. `head`
2. `chest`
3. `leg`
4. `free`

A stored `miss` value is normalized to `free`. Default is `head`.

Exact display mapping:

- `head` -> `Head`
- `chest` -> `Chest`
- `leg` -> `Legs`
- `free` -> `Point & Shoot`

## Color state

AI color keys are normalized to `red`, `green`, or `none`.

- default AI color: `red`
- default real-player color: `green`
- Bot Highlight is enabled when AI color is not `none`
- enabling Bot Highlight restores `custom_ai_color_last_key`, falling back to `red`
- disabling Bot Highlight sets AI color to `none`
- changing Bot Color records `custom_ai_color_last_key`; it applies immediately only
  while highlighting is enabled
- Player Color always calls `set_real_player_color`

`custom_character_xray_enabled` defaults to true when nil in the baseline payload.

## Localization/title behavior

The baseline calls `NewLuaLocText(text, "DongDongNativeSetting", key)`.

Observed localization keys:

- `PageTitle`
- `FunctionSection`
- `ColorSection`
- `AdjustSection`

Observed font style IDs:

- page title: `Header4_32pt`
- section title: `Header3_28pt`

The payload hides `Line_113` using `ESlateVisibility.Collapsed` for the page-title
widget.

After page construction it attempts, under protected calls:

- `_wtResetPanel:Visible()`
- `_wtResourceFixBtn:Collapsed()`
- `_ShowCloudBtn()`

The apparently odd visibility behavior is preserved because it is what the baseline
actually does.

## Native navigation integration

The custom navigation row ID reuses `UIName2ID.SettingBtnTwo` exactly as the payload
does.

The tab descriptor contains:

- `keyText = PAGE_TITLE`
- `__dongdong_native_direct = true`

When direct mode is true it is inserted at index 1 and registered via
`UIManager:RegSwitchSubUI(view, navlist)`.

For the custom tab, `_FetchSettingSystemByTab` sets:

`view._tabType = tonumber(requested or 0) + 1`

then removes the normal child UI from `view._wtRootMain` and builds the custom page.
`_UpdateSysetemSettingPanel` checks the custom selection using `_tabType - 1`.

`OnHideBegin` and `OnClose` clean up the injected grid/scroll UI and clear source-side
references.

## Reconstruction status

`src/spectra/native_settings_ui.lua` is a readable source reconstruction of prototype
`0.29.105`. It installs the same nine hooks and delegates feature actions to the still
embedded, byte-identical payload globals. This is deliberate: UI/lifecycle is migrated
first while no-recoil/aim/X-Ray internals remain known-good until their own Phase D
reconstruction groups are validated.

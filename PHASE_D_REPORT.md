# Phase D Reconstruction Report

## D1: Native post-login settings UI

Status: source reconstructed, compiled, locally validated; game-runtime execution still
pending.

Reconstructed prototype group:

- `0.29.105` (`install_character_color_setting_hooks` /
  `InstallDongDongNativeSettingPage`)
- its 33 child closures used for native settings-page construction and hook wrappers

Editable source:

- `src/spectra/native_settings_ui.lua`
- `src/spectra/payload_ui_bridge.lua`

The bridge runs only after the original embedded payload has successfully executed. It
then performs a transactional takeover of the nine `SystemSettingMainView` wrappers.
Dependencies are resolved before replacing the known-good payload wrappers. If source
installation cannot reach all nine hooks, the attempted source hooks are rolled back
and the previous payload wrappers are restored.

The payload itself remains byte-identical. This gives a narrow failure boundary: D1 can
be disabled/reverted without changing crypto, authentication, feature logic, or payload
bytes.

## Exact UI/function inventory

See:

- `PAYLOAD_FUNCTION_CATALOG.md`
- `PAYLOAD_UI_MAP.md`

These files distinguish literal bytecode symbols from semantic names assigned during
reconstruction.

## Intentional divergence

The baseline payload page-title constant is `@starrmods        `. The reconstructed
source UI uses `@DrkZeref` as explicitly required. No other feature label, engine API,
UI ID, callback name, range, or state key was intentionally changed in D1.

## D1 validation

`tools/validate_phase_d.py` verifies:

- baseline size/hash
- embedded payload size/hash
- exact 801-fragment Base64 payload embedding
- custom <-> standard Lua 5.3 opcode round trip
- Lua 5.3 / `size_t=4` target chunk structure
- required UI strings and nine hook method names
- functional mocked native-settings UI construction
- 13 controls + 4 title/header widgets
- callback routing into original payload feature globals
- existing wrapper smoke tests
- deterministic authentication protocol fixture

It writes `validation_phase_d.json`.

Current D1 custom artifact:

- `spectra_wrapper_phase_d.custom.luac`
- size: 208,172 bytes
- SHA-256: `ad668a891a573fba40e2e112650d2060d0c3e85498c4ae60cedef6e1ca512d97`

## Remaining Phase D groups

D1 does **not** claim that the whole payload has been reconstructed. The next behavior
groups are:

1. public feature-control API around prototypes `0.29.73`, `0.29.77`,
   `0.29.101`-`0.29.104`, `0.29.107`;
2. aim/recoil/spread data mutation and restoration helpers beneath that API;
3. character color/X-Ray mesh/material traversal, fashion-refresh hook, and tick path;
4. remaining payload business/equipment module methods and their external module calls.

Each group should be migrated only after its dependencies and state transitions can be
matched against the bytecode. Stripped locals will continue to receive explicitly
reconstructed names rather than fabricated "original" ones.

## Phase D2 — public feature/control entry points

Reconstructed as editable Lua source, with stripped helper names explicitly reconstructed rather than claimed original:

- `P0.29.73` → public `set_dongdong_feature_config`
- `P0.29.77` → public `set_dongdong_aim_part`
- `P0.29.99` → color normalization helper
- `P0.29.100` → AI color normalization helper
- `P0.29.101` → public `set_ai_color`
- `P0.29.102` → public `set_real_player_color`
- `P0.29.103` → public `set_character_xray`

Source files:

- `src/spectra/feature_control.lua`
- `src/spectra/character_visuals.lua`

`P0.29.77` timing/revision chain is reconstructed as observed: `0.12 -> 0.04 -> 0.10 -> 0.38`, guarded by `custom_dongdong_aim_part_revision`; it clears `custom_dongdong_bone_array_snapshots` and `custom_dongdong_bone_name_pool`, and writes build revision `v62-character-color-refresh-skin-mesh` before reapplying the active aim mode.

Runtime takeover for these public functions is intentionally **not enabled yet**. Their lower-level mutation/rescan helpers are captured local prototypes in the original payload. Replacing the globals before those helpers are reconstructed would change working behavior. The native settings UI takeover from D1 remains enabled.

### D2 helper layer completed in source

Additional helper prototypes reconstructed and unit-tested:

- `P0.29.71` native `ClientBaseSetting.bIsAimAssistOpen` save/apply/restore behavior
- `P0.29.72` `weapon.FireAssistedAimingDebugEnable` command, immediate + 0.35s + 1.2s replay
- `P0.29.0` weak-key mesh table constructor
- `P0.29.92` material/overlay/custom-depth snapshot restore
- `P0.29.95` category-specific mesh restore/removal
- `P0.29.96` character scan cursor/snapshot reset

Remaining blocker before public feature globals can safely be replaced is the data-table mutation/snapshot path (`P0.29.17`, `P0.29.60`, `P0.29.67`, `P0.29.68` and dependencies) plus the character rescan/actor-mesh traversal path (`P0.29.97`, `P0.29.98` and dependencies).

## Phase D3 — reversible data-table mutation + partial runtime takeover

D3 closes the source dependency chain for `no_recoil` and `converge` and moves those two
features from shadow/source-only reconstruction to actual runtime ownership after the
known-good payload initializes.

New editable sources:

- `src/spectra/mutation_runtime.lua`
- `src/spectra/payload_feature_bridge.lua`
- `DATA_MUTATION_MAP.md`

Reconstructed prototypes represented in the mutation runtime:

- snapshot/table helpers `0.29.10` through `0.29.26` where applicable (`0.29.27/28` are
  not claimed here), plus recursive converge `0.29.29`;
- bone-array helper group `0.29.44`, `0.29.46`, `0.29.48`-`0.29.60` represented in source;
- table dispatcher `0.29.67` and feature DataTable dispatcher `0.29.68`.

The public bridge captures the exact payload global `set_dongdong_feature_config` and
routes only `no_recoil` and `converge` into the reconstructed `0.29.73` orchestration +
D3 mutation backend. `aim`, `anti_shake`, and unknown keys continue to call the original
payload function.

A control-flow correction was made during D3 audit for `0.29.29`: at PCs 38-43,
`force == true` forces zeroing for every numeric/boolean descendant; with `force == false`
a `spread`/`dispersion`/`bloom` key begins forced recursion. Unit tests explicitly cover
this nested behavior and snapshot restoration.

D3 validation additionally checks:

- exact candidate table counts (`no_recoil=4`, `converge=7`, `aim=20`);
- the recovered 114-entry userdata field probe list;
- `no_recoil` mutation and reverse restoration;
- `converge` nested forced mutation and reverse restoration;
- DataTable alias deduplication by table identity;
- generic `0.29.22` recursive zero helper;
- bone-array snapshot/restore table path;
- bridge routing: source for `no_recoil`/`converge`, original payload for `aim`;
- all prior wrapper, protocol, UI, visual and aim helper tests.

Current D3 custom artifact:

- `spectra_wrapper_phase_d.custom.luac`
- size: 238,497 bytes
- SHA-256: `1cbe099f234415e9807dc90f0bdd381e1d600dc8af0c0c5790fdbb39633af349`

`game_runtime_test` remains `false`; userdata/TableManager behavior has been matched to
bytecode and mocked locally but cannot be declared engine-verified in this sandbox.

### Next reconstruction boundary

The source bridge intentionally does not own `aim` / `anti_shake` yet. Their active path
uses the aim mutation group ending in `0.29.65`; `0.29.65` alone contains 842
instructions and 136 constants with `fire`/`ads`, FOV/range/speed/lock-time and table-type
specific replacements. That group is the D4 boundary and will be migrated only after its
replacement rules are represented and regression-tested.

## D4 recovery checkpoint — materialized visual runtime takeover

A consistency audit found that a previously described aim-takeover D4 state was not
materialized in the delivered workspace: the report referenced `aim_mutation.lua`,
`aim_refresh.lua`, and an expanded feature bridge that were absent from the actual files.
That claim is retracted. Work resumed from the last verifiable D3 package instead of treating
an undocumented state as source of truth.

This recovery checkpoint adds a fully materialized reconstruction of `P0.29.78..98` and
publishes the already reconstructed `P0.29.99..103` visual APIs through a transactional bridge.
After payload initialization, source now owns `set_ai_color`, `set_real_player_color`, and
`set_character_xray`. The original payload's later background/tick visual path remains active
until its post-103 prototypes are reconstructed.

New editable files:

- `src/spectra/visual_scan.lua`
- `src/spectra/payload_visual_bridge.lua`
- `VISUAL_SCAN_MAP.md`

Validation includes dedicated visual scanner and visual bridge tests in addition to all D3
regressions. `game_runtime_test` remains false because the DFM runtime is unavailable here.

### Visual background takeover completion

The same recovery checkpoint now also materializes `P0.29.104`, `P0.29.106`, and `P0.29.107`.
The source bridge removes the old fashion delegate callback, installs a source callback, unregisters
the prior `__AUTHOR_XRAY_UI_TICK`, and registers the source tick callback. The exact throttling
interval is 0.25 seconds; fallback mode resets the actor snapshot every 10 attempts and wraps the
attempt counter after 600. This means the active visual public API, immediate rescan, fashion
refresh, and periodic scan path are all source-owned after payload initialization.

## Phase D continuation: aim replacement source, pre-bridge

`AIM_MUTATION_MAP.md` and `AIM_PROTOTYPE_INDEX.json` now record bytecode evidence for
`P0.29.30..45`, `61..66`, and `74..77`. `src/spectra/aim_mutation.lua` materializes
`P0.29.65` replacement decisions and the six parent `R52` profile records extracted
from `proto_0_29.txt:388..934`. `tests/aim_mutation.lua` checks ADS versus fire,
ordinary versus Gamepad path, profile IDs, and return flags. Existing revision tests
now reject stale delayed callbacks. Build and static validation compile the new source.
The source bridge still delegates `aim` and `anti_shake` to the embedded payload:
`P0.29.66/67/68` row walking, `61..64` bone mutation and `74..76` refresh have not
been wired and compared end to end. This is a partial reconstruction checkpoint,
not aim/anti_shake runtime takeover. `game_runtime_test` remains false.

The follow-up source implementation includes `P0.29.66` recursive field
walking with a snapshot/restore regression and a `ConeFilterBones` exclusion.
The general `P0.29.68` dispatcher is now source materialized and tested; the
complete `P0.29.67` behavior and aim runtime bridge remain payload-owned.

The aim-specific `P0.29.67` row branch is now source materialized, including
`AimAssistorId` and exact row-name profile fallbacks. It requires an explicit `P0.29.63`
bone-updater dependency and remains inactive; the source updater is now available
in `aim_bones.lua`. A regression checks that a missing dependency prevents invocation.

`aim_bones.lua` now materializes `P0.29.45/61..64` with focused target-part
remap, AI group and restore tests. It is compiled and tested but is not called
by the active bridge.

The current forensic index now resolves conservative call edges for 39 related
prototypes including nested callbacks. The source `P0.29.45/61..64` bone group
passes Lua regression tests. `P0.29.74..76` weapon refresh is materialized;
transactional bridge takeover remains outstanding.

`aim_refresh.lua` now materializes the `P0.29.74..76` object collection,
refresh method list and `InitWeapon`/delayed `InitAmmos` sequence. Focused Lua
mock tests pass, but the source is inert until the complete bridge handoff and
bytecode behavior comparison are validated. Its field/call ABI now uses explicit
`P0.29.2/3/4/12` reconstructed helpers; regression tests cover retry ordering.

The full source, fixtures, baseline and payload, build/validator tools, and forensic
metadata are now in the Git tree. A clean archive of the staged Git tree builds and
validates without unpacking the forensic snapshot. `P0.29.68` has 38 instructions:
it indexes the configured feature list, iterates with `ipairs`, resolves each name
through `P13`, deduplicates on the raw resolved table identity, dispatches to `P67`,
and returns whether a dispatch returned truthy. It does not catch dispatch errors
or check the toggle itself. A Gamepad DataTable fixture now reaches source P67,
P63, P66, P65 and verifies bone and field restoration; ordinary AimAssistor
fire mode's no-direct-field branch remains distinct. This source does not imply
aim/anti_shake takeover.

# Phase D data mutation map

Source of truth: `embedded_payload.bin` SHA-256
`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`.

This document describes the current source-owned data mutation layer after the Phase D
aim migration gate passed. Prototype IDs refer to payload bytecode structure; helper
names in source are reconstructed descriptions unless stated otherwise.

## Runtime ownership after payload initialization

| Feature key | Public entry | Runtime owner |
| --- | --- | --- |
| `no_recoil` | `set_dongdong_feature_config` | reconstructed source |
| `converge` | `set_dongdong_feature_config` | reconstructed source |
| `aim` | `set_dongdong_feature_config` | reconstructed source |
| `anti_shake` | `set_dongdong_feature_config` | reconstructed source |

Unsupported feature keys still delegate to the captured payload implementation.

`src/spectra/payload_feature_bridge.lua` captures both payload globals used by the aim
control path. The source bridge installs `P73`/`P77` together and rolls both globals
back if installation is incomplete. Runtime failures restore source-owned mutation
state before delegating to the known-good payload closure.

## Snapshot/table layer

`src/spectra/mutation_runtime.lua` represents the reversible mutation helpers around:

- `P0.29.10..26` where applicable
- `P0.29.29`
- bone-array snapshot support used by `P0.29.44` and related helpers
- generic table dispatch `P0.29.67`
- feature table dispatch `P0.29.68`

Feature snapshot writes record the original value before assignment and restore in
reverse order. Transactional regressions cover write failure, snapshot failure,
recursive-child failure, bone failure and partial mutation rollback.

## `no_recoil`

Candidate table aliases:

1. `WeaponBase/WeaponRecoilTable`
2. `weaponBase/weaponrecoiltable`
3. `WeaponRecoilTable`
4. `/Game/DataTables/WeaponBase/WeaponRecoilTable`

The reconstructed source mutates the recovered recoil groups and restores their first
observed values when the feature is disabled.

## `converge`

Candidate table aliases:

1. `WeaponBase/WeaponSpreadTable`
2. `weaponBase/weaponspreadtable`
3. `WeaponSpreadTable`
4. `/Game/DataTables/WeaponBase/WeaponSpreadTable`
5. `WeaponBase/WeaponMainAttributeTable`
6. `weaponBase/weaponmainattributetable`
7. `WeaponMainAttributeTable`

The recursive helper preserves the recovered forced-recursion semantics for spread,
dispersion and bloom descendants.

## Aim table dispatch

`P0.29.68` walks the configured feature table list with `ipairs`, resolves each name
through reconstructed `P13`, deduplicates by the raw resolved table object identity,
and dispatches to `P67`. Alias names that resolve to the same DataTable are applied once.

The aim configuration list contains the recovered aliases for:

- `WeaponAimAssistorTable`
- `WeaponAimAssistorTableForGamepad`
- `WeaponAssistedAimingTable`
- `WeaponAssistedAimingGroupTable`
- `WeaponBulletTable`

`P68` itself does not check whether a toggle is active and does not wrap `P67` in an
internal `pcall`.

## Aim row mutation chain

```text
P68
 ↓
P67
 ↓
P63 bone handling
 ↓
P66 recursive walker
 ↓
P65 replacement
```

`P67` uses `AimAssistorId` when available and falls back to exact row names:

```text
Default   -> 1
NewRow    -> 1001
NewRow_0  -> 1002
NewRow_1  -> 1003
NewRow_2  -> 11001
NewRow_3  -> 1004
```

The walker keeps the recovered depth limit of 13 and skips
`ConeFilterBones` / `ConeFilterBonesOfAI`. Table and userdata reads use the
reconstructed ABI where required; the `P2` false-to-nil behavior is not replaced by
the more permissive generic safe getter.

## Bone mutation and restoration

`src/spectra/aim_bones.lua` represents `P0.29.45` and `P0.29.61..64`.
It snapshots bone arrays before remapping, patches AI/filter structures, restores prior
arrays, and refreshes the aim-assistor table path. Duplicate bindings are tracked so a
single underlying array can be restored through multiple aliases.

## Weapon/runtime refresh

`src/spectra/aim_refresh.lua` represents `P0.29.74..76` and reuses reconstructed
`P2/P3/P4/P12` call semantics. Focused tests cover self/static ordering, fallback order,
protected calls, nil handling and duplicate side-effect risk.

## Phase E3 equipment-check root path

| Prototype | Exact payload export | Reconstructed source | Runtime owner |
|---|---|---|---|
| `P0.0` | `CheckEquipmentBeforEnterGameProcess` | `product_module.lua` | source |
| `P0.1` | `_CheckProcess` | `product_module.lua` | source |
| `P0.2` | `_CheckEquipmentValue` | `product_module.lua` | source |
| `P0.3` | `GetAllEquipmentValue` | `product_module.lua` | partial; needs original U0/U2 diagnostic closures |
| `P0.4` | `_CheckMedicine` | `product_module.lua` | source |
| `P0.5` | `_CheckUnCarryMedicine` | `product_module.lua` | source |
| `P0.6` | `_CheckContainer` | `product_module.lua` | source |
| `P0.6.0` | `add_medicine_types_from_items` (reconstructed descriptive name) | `product_module.lua` | source |
| `P0.7` | `_CheckBullet` | `product_module.lua` | partially reconstructed; captured dependency gate |
| `P0.7.0` | `inspect_bullet_slot` (reconstructed descriptive name) | `product_module.lua` | partially reconstructed with P0.7 |
| `P0.8` | `_CheckDurabulity` | `product_module.lua` | partially reconstructed; captured logger gate |
| `P0.8.0` | `check_durability_slot` (reconstructed descriptive name) | `product_module.lua` | partially reconstructed with P0.8 |
| `P0.9` | `CheckEquipSlotEmpty` | `product_module.lua` | source |

P0.4 reads `Field:GetMedicineType()` before enumerating `EDispensingMedicineType`
through the captured `table.values`, then passes both values through the captured module
table's current `_CheckUnCarryMedicine` field (P0.5). It only emits
`LackMedicine` when P0.5 returns a nonempty missing-type list; the location is formatted
from ordered descriptions joined with `CommonConfig.Loc.Comma`.

P0.5 walks the supplied enum values with `ipairs`, fetches each
`GetEquipmentCheckData(LackMedicine, medicine_type)`, and retains a row only when it
exists, its switch is truthy, and `table.contains(carried_types, medicine_type)` is false.
It accumulates the maximum row key and appends medicine types/descriptions in traversal
order. There is no deduplication instruction in the prototype.

P0.6 reads the storage-space record before scanning `ChestHangingContainer`,
`BagContainer`, and `Pocket` in that order. Each capacity and remaining-space value gets
`1e-6` before summation. It adds the storage abnormal only when the normalized free-space
ratio is strictly below the normalized setting. The safe-box path chooses
`ESlotGroup.SOLChallenge` only when challenge mode and that enum value are truthy, otherwise
`ESlotGroup.Player`; its `HasUnnecessaryItems` comparison is also strict. Nested P0.6.0
walks item collections with `pairs`, selecting `EItemType.Medicine` items whose Health
feature and `medicineType` are both truthy, and calls `Field:AddMedicineType`.
Both config branches proceed for nonnegative `checkValue` and skip negative values. A
zero storage threshold still invokes both decimal helpers before the strict comparison;
a zero safe-box threshold can add an abnormal when used capacity is positive.

P0.7 captures the current slot-group ID once, then inspects `MainWeaponLeft`,
`MainWeaponRight`, and `Pistrol` in that order. Nested P0.7.0 fetches each slot's item,
converts its ID through the captured `ItemHelperTool.GetSubTypeById`, and looks up
`GetEquipmentCheckData(LackBullet, subtype)`. Missing/disabled rows pass; rounded negative
requirements call the captured error logger and pass; otherwise the captured debug logger runs
before `GetMatchBulletNumByWeaponItem(item, slot_group_id)`. Only a strict `matched < rounded`
comparison fails and contributes `key`, subtype, deficit, and formatted location. Root P0.7
combines failed slot enums in left/right/pistol order, deduplicates equal-subtype left/right
descriptions by keeping the left description, keeps both when subtypes differ, and uses the
maximum failing row key. Tests cover those branch and ordering rules. The runtime bridge installs
P0.7 only when it recovers the original closure's ItemHelperTool, both loggers, and the exact
module table identity; otherwise the payload closure remains active.

P0.8 captures the current slot-group ID once, then checks `Helmet` followed by
`BreastPlate`. Nested P0.8.0 returns true for an absent item, missing Equipment feature,
non-helmet/non-breastplate feature, missing check record, disabled switch, negative
`checkValue` (after calling the captured error logger), or durability above the normalized
threshold. It calls `GetEquipmentCheckData(InsufficientDurability, slot_type)` only for
Helmet/BreastPlate equipment features. For enabled nonnegative settings, it forwards every
return from `GetDurabilityPercent()` into `MathUtil.GetTheSecondDecimal`, normalizes the
setting separately, and fails inclusively when normalized current durability is `<=` the
normalized setting. The failure location calls `string.format(abnormalDesc,
SlotNameMapping[slot_type], GetRoundingNum(checkValue * 100))`. Root P0.8 appends failed slot
types and locations in Helmet/BreastPlate order, uses the maximum failing row key, and emits
one `InsufficientDurability` abnormal. The bridge installs P0.8 only when original closure
upvalue 2 (P0.8 U1) is a function; otherwise the payload closure stays active.

P0.9 takes the public slot-type argument, reads the current slot-group ID, calls
`InventoryServer:GetSlot(slot_type, group_id)`, and then calls `GetEquipItem`. It returns
exactly `(true)` when the slot has no item and `(false, item)` when occupied. The bridge
passes the public argument through and preserves the one-value/two-value return arity.

P0.2 reads both map values from `GetMapNeedValue`, requests `GetEquipmentCheckData(type, 0)`
for each abnormal type, and only adds records when the corresponding switch is enabled,
the threshold is nonzero, and the strict bytecode comparison passes (`current < minimum`,
`maximum < current`). It writes the recovered `key`, `abnormalType`, `loc`, and `param`
fields. The source re-reads Field/config paths between the lower and upper checks because
P0.2 does so in its instruction stream.

P0.3's source preserves challenge/unbound currency selection, rental preset price, the
seven slot checks, the missing-rental-plan zero fallback, `evtAllEquipmentValueChanged`
arguments, and the `(total_value, currency_type)` return. P0.0..P0.9 exports and all other
prototype ownership are machine-indexed in `FULL_PAYLOAD_PROTOTYPE_INDEX.json`.

## Runtime checkpoint

Current deterministic hashes and test results are authoritative in
`validation_phase_d.json`. Baseline and embedded payload bytes remain unchanged.
`game_runtime_test=false` remains unchanged until the rebuilt custom chunk is actually
executed in the DFM/game runtime.

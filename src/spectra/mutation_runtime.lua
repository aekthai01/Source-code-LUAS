local S = ...
assert(type(S) == "table", "spectra module table required")
local ABI = assert(S.AimABI, "AimABI required")
local RuntimeHelpers = assert(S.P029RuntimeHelpers, "P0.29 runtime helpers required")

-- Phase D3 reconstruction of the data-table mutation/snapshot layer used by
-- P0.29.17 / P0.29.60 / P0.29.67 / P0.29.68 and the no_recoil/converge
-- branches beneath them. Names below are semantic reconstruction names unless
-- an exact global/field string is noted.
local M = {}
S.MutationRuntime = M

M.PROTOTYPES = {
    normalize_identifier = "0.29.10",
    get_table_manager = "0.29.11",
    call_with_optional_self = "0.29.12",
    get_data_table = "0.29.13",
    ensure_feature_snapshot = "0.29.14",
    snapshot_set = "0.29.15",
    clear_feature_snapshot = "0.29.16",
    restore_feature_snapshot = "0.29.17",
    table_extend = "0.29.18",
    get_extended_field = "0.29.19",
    iterate_table = "0.29.20",
    zero_scalar_field = "0.29.21",
    zero_recursive = "0.29.22",
    patch_random_range = "0.29.23",
    patch_random_collection = "0.29.24",
    patch_recoil_group = "0.29.25",
    apply_no_recoil_row = "0.29.26",
    converge_recursive = "0.29.29",
    canonical_bone_name = "0.29.44",
    make_name = "0.29.46",
    array_len = "0.29.48",
    array_get = "0.29.49",
    ensure_bone_name_pool = "0.29.50",
    ensure_bone_array_snapshots = "0.29.51",
    binding_key = "0.29.52",
    add_binding = "0.29.53",
    snapshot_bone_array = "0.29.54",
    resolve_bone_value = "0.29.55",
    array_set_verified = "0.29.56",
    array_set_raw = "0.29.57",
    restore_binding = "0.29.58",
    restore_record_bindings = "0.29.59",
    restore_bone_array_snapshots = "0.29.60",
    apply_table = "0.29.67",
    apply_feature = "0.29.68",
}

M.FEATURE_TABLES = {
    no_recoil = {
        "WeaponBase/WeaponRecoilTable",
        "weaponBase/weaponrecoiltable",
        "WeaponRecoilTable",
        "/Game/DataTables/WeaponBase/WeaponRecoilTable",
    },
    converge = {
        "WeaponBase/WeaponSpreadTable",
        "weaponBase/weaponspreadtable",
        "WeaponSpreadTable",
        "/Game/DataTables/WeaponBase/WeaponSpreadTable",
        "WeaponBase/WeaponMainAttributeTable",
        "weaponBase/weaponmainattributetable",
        "WeaponMainAttributeTable",
    },
    aim = {
        "WeaponBase/WeaponAimAssistorTable",
        "weaponBase/weaponaimassistortable",
        "WeaponAimAssistorTable",
        "/Game/DataTables/WeaponBase/WeaponAimAssistorTable",
        "WeaponBase/WeaponAimAssistorTableForGamepad",
        "weaponBase/weaponaimassistortableforgamepad",
        "WeaponAimAssistorTableForGamepad",
        "/Game/DataTables/WeaponBase/WeaponAimAssistorTableForGamepad",
        "WeaponBase/WeaponAssistedAimingTable",
        "weaponBase/weaponassistedaimingtable",
        "WeaponAssistedAimingTable",
        "/Game/DataTables/WeaponBase/WeaponAssistedAimingTable",
        "WeaponBase/WeaponAssistedAimingGroupTable",
        "weaponBase/weaponassistedaiminggrouptable",
        "WeaponAssistedAimingGroupTable",
        "/Game/DataTables/WeaponBase/WeaponAssistedAimingGroupTable",
        "WeaponBase/WeaponBulletTable",
        "weaponBase/weaponbullettable",
        "WeaponBulletTable",
        "/Game/DataTables/WeaponBase/WeaponBulletTable",
    },
    anti_shake = {
        "WeaponBase/WeaponRecoilTable",
        "weaponBase/weaponrecoiltable",
        "WeaponRecoilTable",
        "/Game/DataTables/WeaponBase/WeaponRecoilTable",
    },
}


M.CONVERGE_FIELDS = {
    "bLimitSpreadRecoverSpeed", "DistributionInSpreadFunc", "DistributionInSpreadType",
    "ExtraSpread", "FireSpreadExtraRecoverCurve", "FireSpreadFactor", "FireSpreadItems",
    "FireSpreadRecoverSpeed", "LuaDisplaySpreadFactor", "LuaDisplaySpreadUIFactor",
    "Spread", "SpreadId", "SpreadMax", "SpreadMaxFinal", "SpreadRecoverSpeed",
    "EnableSpringGunKick", "RecoilShakePitch", "RecoilShakePitchWithCurve",
    "RecoilShakeYaw", "RecoilShakeYawWithCurve", "SideAimingRecoilShakeFactor",
    "SpringGunKick", "WeaponDataSpringGunKick", "WeaponRecoilShake",
    "WeaponRecoilShakeElementConfig", "WeaponRecoilShakeManualCurveConfigs",
    "WeaponRecoilShakeWithCurve", "bTakeEffect", "ZoomingInConfig", "ActiveTrackingConfig",
    "CrosshairDampingConfig", "CrosshairFollowingConfig", "ShootingConfig", "AngleThreshold",
    "ConeAngleBase", "ConeAnglePower", "ConeHeightBase", "ConeHeightPower",
    "ConeFilterActorsMaxNum", "CdTime", "DeltaTime", "EffectiveFOVRange", "InRangeA",
    "InRangeB", "IntervalTime", "LockonTime", "Outer2InnerRangeForRayChecker", "OutRangeA",
    "OutRangeB", "PitchFactor", "PitchFactorAds", "PitchFactorHip", "PitchFactorLockonAds",
    "PitchFactorLockonHip", "PitchRateAds", "PitchRateHip", "PlayerInputAwayTargetAngle",
    "PlayerInputAwayTargetValue", "PlayerInputRecordTime", "RangeScale", "YawFactor",
    "YawFactorAds", "YawFactorHip", "YawFactorLockonAds", "YawFactorLockonHip",
    "YawRateAds", "YawRateHip", "ConeFilterBones", "ConeFilterBonesOfAI", "EnableDistanceMin",
    "EnableDistanceMax", "AssistedBoxMinRadius", "AssistedBoxMaxRadius",
    "AssistedBoxVerticalScale", "PauseTimeAfterFire", "HorizontalRecoilSpeed",
    "VerticalRecoilSpeed", "RecoilSpeedTouchParam", "RecoilReduceActivationTime",
    "EnableDistanceMinForRotateSticky", "EnableDistanceMaxForRotateSticky",
    "AssistedBoxMinRadiusForRotateSticky", "AssistedBoxMaxRadiusForRotateSticky",
    "AssistedBoxVerticalScaleForRotateSticky", "StickyParam", "MagneticCDSeconds",
    "MagneticEnableFocusSeconds", "EnableDistanceMinForMagneticSticky",
    "EnableDistanceMaxForMagneticSticky", "AssistedBoxMinRadiusForMagneticSticky",
    "AssistedBoxMaxRadiusForMagneticSticky", "AssistedBoxVerticalScaleForMagneticSticky",
    "HorizontalRecoilSpeedForZoomIn", "VerticalRecoilSpeedForZoomIn", "RecoilSpeedDistanceCurve",
    "Radius", "bPreventMissEnable", "PreventMissAddBulletRadiusDelta", "PreventMissNumber",
    "PreventMissTime", "AimingSingleId", "AimingAutoId", "AimingBurstId", "AimingSingleIdPVE",
    "AimingAutoIdPVE", "AimingBurstIdPVE", "Head", "Neck", "Spine2", "Hips", "LeftLeg",
    "RightLeg", "X", "Y",
}

local safe_get = ABI.get
local call_optional_self = ABI.call_optional_self
M.safe_get = safe_get
M.call_optional_self = call_optional_self

function M.normalize_identifier(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

M.get_table_manager = RuntimeHelpers.get_table_manager
M.get_data_table = RuntimeHelpers.get_data_table

-- Exact P0.29 snapshot-helper closure family. P0.29 is constructed with _G as
-- its captured state; P14/P16 capture that R0 identity and P15 captures the
-- fixed P2/P14 sibling closures. Compatibility functions below remain state-
-- explicit for older source layers, while ownership evidence targets these
-- exact closures.
local snapshot_state_029 = _G
local snapshot_safe_get_029_2 = safe_get

local function ensure_feature_snapshot_029_14(feature)
    local snapshots = snapshot_state_029.custom_dongdong_feature_snapshots
    if type(snapshots) ~= "table" then
        snapshots = {}
        snapshot_state_029.custom_dongdong_feature_snapshots = snapshots
    end
    local snapshot = snapshots[feature]
    if type(snapshot) ~= "table" then
        snapshot = { records = {}, seen = {} }
        snapshots[feature] = snapshot
    end
    return snapshot
end

local ensure_feature_snapshot_capture_029_14 = ensure_feature_snapshot_029_14
local function snapshot_set_029_15(feature, object, key, value)
    if object == nil or key == nil then return false end
    local previous = snapshot_safe_get_029_2(object, key)
    if previous == value then return true end
    local snapshot = ensure_feature_snapshot_capture_029_14(feature)
    local identity = tostring(object) .. "\0" .. tostring(key)
    if snapshot.seen[identity] ~= true then
        snapshot.seen[identity] = true
        snapshot.records[#snapshot.records + 1] = {
            object = object,
            key = key,
            value = previous,
        }
    end
    return pcall(function() object[key] = value end)
end

local function clear_feature_snapshot_029_16(feature)
    local snapshots = snapshot_state_029.custom_dongdong_feature_snapshots
    if type(snapshots) == "table" then snapshots[feature] = nil end
end

M.p029_ensure_feature_snapshot = ensure_feature_snapshot_029_14
M.p029_snapshot_set = snapshot_set_029_15
M.p029_clear_feature_snapshot = clear_feature_snapshot_029_16

function M.table_extend(value)
    if type(value) ~= "userdata" then return value end
    local fn = safe_get(value, "TableExtend")
    if type(fn) ~= "function" then return value end
    local ok, extended = pcall(fn, value)
    if not ok then ok, extended = pcall(fn) end
    if ok and type(extended) == "table" then return extended end
    return value
end

function M.get_extended_field(owner, key)
    if owner == nil then return nil end
    local value = safe_get(owner, key)
    if type(value) == "userdata" then
        local extended = M.table_extend(value)
        if type(extended) == "table" then
            if type(owner) == "table" then pcall(function() owner[key] = extended end) end
            value = extended
        end
    elseif type(owner) == "table" then
        local again = safe_get(owner, key)
        if type(again) == "table" then value = again end
    end
    return value
end

function M.iterate_table(value, callback)
    value = M.table_extend(value)
    if type(value) ~= "table" or type(callback) ~= "function" then return false end
    return pcall(function()
        for key, item in pairs(value) do callback(value, key, item) end
    end)
end

function M.ensure_feature_snapshot(state, feature)
    local snapshots = state.custom_dongdong_feature_snapshots
    if type(snapshots) ~= "table" then
        snapshots = {}
        state.custom_dongdong_feature_snapshots = snapshots
    end
    local snapshot = snapshots[feature]
    if type(snapshot) ~= "table" then
        snapshot = { records = {}, seen = {} }
        snapshots[feature] = snapshot
    end
    return snapshot
end

function M.snapshot_set(state, feature, object, key, value)
    if object == nil or key == nil then return false end
    local previous = safe_get(object, key)
    if previous == value then return true end
    local snapshot = M.ensure_feature_snapshot(state, feature)
    local identity = tostring(object) .. "\0" .. tostring(key)
    if snapshot.seen[identity] ~= true then
        snapshot.seen[identity] = true
        snapshot.records[#snapshot.records + 1] = { object = object, key = key, value = previous }
    end
    return pcall(function() object[key] = value end)
end

function M.clear_feature_snapshot(state, feature)
    local snapshots = state.custom_dongdong_feature_snapshots
    if type(snapshots) == "table" then snapshots[feature] = nil end
end

function M.restore_feature_snapshot(state, feature)
    local snapshots = state.custom_dongdong_feature_snapshots
    if type(snapshots) ~= "table" then return false end
    local snapshot = snapshots[feature]
    if type(snapshot) ~= "table" or type(snapshot.records) ~= "table" then
        snapshots[feature] = nil
        return false
    end
    local restored = false
    for index = #snapshot.records, 1, -1 do
        local record = snapshot.records[index]
        if type(record) == "table" and record.object ~= nil and record.key ~= nil then
            if pcall(function() record.object[record.key] = record.value end) then restored = true end
        end
    end
    snapshots[feature] = nil
    return restored
end

function M.zero_scalar_field(state, feature, owner, key)
    local value = M.get_extended_field(owner, key)
    if type(value) == "number" then
        M.snapshot_set(state, feature, owner, key, 0.0)
        return true
    elseif type(value) == "boolean" then
        M.snapshot_set(state, feature, owner, key, false)
        return true
    end
    return false
end

function M.zero_recursive(state, feature, value, depth, seen)
    value = M.table_extend(value)
    depth = tonumber(depth) or 0
    if value == nil or depth > 9 then return end
    local t = type(value)
    if t ~= "table" and t ~= "userdata" then return end
    seen = seen or {}
    if seen[value] then return end
    seen[value] = true
    if t ~= "table" then return end
    M.iterate_table(value, function(owner, key, child)
        if type(child) == "number" then
            M.snapshot_set(state, feature, owner, key, 0.0)
        elseif type(child) == "boolean" then
            M.snapshot_set(state, feature, owner, key, false)
        else
            local extended = M.table_extend(child)
            if type(extended) == "table" and extended ~= child then
                pcall(function() owner[key] = extended end)
            end
            M.zero_recursive(state, feature, extended, depth + 1, seen)
        end
    end)
end

function M.patch_random_range(state, feature, value)
    value = M.table_extend(value)
    if value == nil then return end
    M.zero_scalar_field(state, feature, value, "MinValue")
    M.zero_scalar_field(state, feature, value, "MaxValue")
    local random_values = M.get_extended_field(value, "RandomValues")
    M.iterate_table(random_values, function(_, _, child)
        child = M.table_extend(child)
        if child ~= nil then
            M.zero_scalar_field(state, feature, child, "MinValue")
            M.zero_scalar_field(state, feature, child, "MaxValue")
        end
    end)
end

function M.patch_random_collection(state, feature, value)
    value = M.table_extend(value)
    M.iterate_table(value, function(owner, key, item)
        if type(item) == "number" then
            M.snapshot_set(state, feature, owner, key, 0.0)
            return
        end
        item = M.table_extend(item)
        M.patch_random_range(state, feature, item)
        M.zero_scalar_field(state, feature, item, "Horizontal")
        M.zero_scalar_field(state, feature, item, "Vertical")
        M.zero_scalar_field(state, feature, item, "Percent")
        M.zero_scalar_field(state, feature, item, "Probability")
        M.zero_scalar_field(state, feature, item, "AmplitudeMin")
        M.zero_scalar_field(state, feature, item, "AmplitudeMax")
    end)
end

function M.patch_recoil_group(state, feature, value)
    value = M.table_extend(value)
    if value == nil then return end
    M.patch_random_range(state, feature, M.get_extended_field(value, "HorizontalRandomRecoil"))
    M.patch_random_collection(state, feature, M.get_extended_field(value, "HorizontalRandomRecoils"))
    M.zero_scalar_field(state, feature, value, "HorizontalScale")
    M.patch_random_range(state, feature, M.get_extended_field(value, "VerticalRandomRecoil"))
    M.patch_random_collection(state, feature, M.get_extended_field(value, "VerticalRandomRecoils"))
    M.zero_scalar_field(state, feature, value, "VerticalScale")
    M.patch_random_collection(state, feature, M.get_extended_field(value, "HorizontalRecoils"))
    M.patch_random_collection(state, feature, M.get_extended_field(value, "VerticalRecoils"))
end

function M.apply_no_recoil_row(state, row)
    row = M.table_extend(row)
    if row == nil then return end
    for _, key in ipairs({
        "SingleOrBurstShootRecoil", "SingleOrBurstShootRecoils",
        "ContinueShootRecoil", "ContinueShootRecoils",
        "ContinueShootRecoilLoop", "ContinueShootRecoilLoops",
    }) do
        M.patch_recoil_group(state, "no_recoil", M.get_extended_field(row, key))
    end
    for _, key in ipairs({ "SideAimingRecoilFactor", "SideAimingRecoilFactors" }) do
        local value = M.table_extend(M.get_extended_field(row, key))
        if value ~= nil then
            M.zero_scalar_field(state, "no_recoil", value, "Horizontal")
            M.zero_scalar_field(state, "no_recoil", value, "Vertical")
        end
    end
    M.patch_random_collection(state, "no_recoil", M.get_extended_field(row, "HorizontalRecoils"))
    M.patch_random_collection(state, "no_recoil", M.get_extended_field(row, "VerticalRecoils"))
end

function M.converge_recursive(state, owner, key, value, depth, seen, force)
    depth = tonumber(depth) or 0
    if depth > 10 then return end
    local normalized = M.normalize_identifier(key)
    local spread_like = string.find(normalized, "spread", 1, true) ~= nil
        or string.find(normalized, "dispersion", 1, true) ~= nil
        or string.find(normalized, "bloom", 1, true) ~= nil
    -- P0.29.29 PCs 38..43: force=true makes every numeric/boolean descendant
    -- eligible for zeroing; otherwise a spread/dispersion/bloom field starts
    -- forced recursion for its descendants.
    local should_zero = force == true or spread_like

    if should_zero then
        if type(value) == "number" then
            M.snapshot_set(state, "converge", owner, key, 0.0)
            return
        elseif type(value) == "boolean" then
            M.snapshot_set(state, "converge", owner, key, false)
            return
        end
    end

    value = M.table_extend(value)
    local t = type(value)
    if t ~= "table" and t ~= "userdata" then return end
    seen = seen or {}
    if seen[value] then return end
    seen[value] = true

    if t == "table" then
        M.iterate_table(value, function(child_owner, child_key, child_value)
            M.converge_recursive(state, child_owner, child_key, child_value, depth + 1, seen, should_zero)
        end)
        return
    end

    for _, field in ipairs(M.CONVERGE_FIELDS) do
        local child = safe_get(value, field)
        if child ~= nil then
            M.converge_recursive(state, value, field, child, depth + 1, seen, should_zero)
        end
    end
end

local KNOWN_BONES = { rightleg=true, leftleg=true, spine2=true, head=true, neck=true, hips=true }

function M.canonical_bone_name(value)
    local normalized = M.normalize_identifier(value)
    if KNOWN_BONES[normalized] then return normalized end
    local t = type(value)
    if t == "table" or t == "userdata" then
        for _, key in ipairs({ "Value", "value", "Name", "name", "BoneName", "boneName" }) do
            local candidate = safe_get(value, key)
            candidate = M.normalize_identifier(candidate)
            if KNOWN_BONES[candidate] then return candidate end
        end
        for _, key in ipairs({ "ToString", "GetName", "ToName" }) do
            local fn = safe_get(value, key)
            local ok, result = call_optional_self(fn, value)
            if ok then
                local candidate = M.normalize_identifier(result)
                if KNOWN_BONES[candidate] then return candidate end
            end
        end
    end
    for _, bone in ipairs({ "rightleg", "leftleg", "spine2", "head", "neck", "hips" }) do
        if string.find(normalized, bone, 1, true) ~= nil then return bone end
    end
    return nil
end

function M.make_name(exemplar, name)
    if type(exemplar) == "string" then return name end
    for _, global_name in ipairs({ "FName", "Name", "MakeLiteralName", "StringToName", "Conv_StringToName" }) do
        local fn = rawget(_G, global_name)
        if type(fn) == "function" then
            local ok, result = pcall(fn, name)
            if ok and result ~= nil then return result end
        end
    end
    return name
end

function M.array_len(array)
    if type(array) == "table" then return #array end
    if type(array) ~= "userdata" then return 0 end
    local fn = safe_get(array, "Num")
    local ok, value = call_optional_self(fn, array)
    if ok then return math.max(0, math.floor(tonumber(value) or 0)) end
    local helper = rawget(_G, "ULuaArrayHelper")
    fn = safe_get(helper, "Num")
    ok, value = call_optional_self(fn, helper, array)
    if ok then return math.max(0, math.floor(tonumber(value) or 0)) end
    return 0
end

function M.array_get(array, index0)
    if type(array) == "table" then return array[index0 + 1] end
    if type(array) ~= "userdata" then return nil end
    local index1 = index0 + 1
    local fn = safe_get(array, "Get")
    local ok, value = call_optional_self(fn, array, index1)
    if ok and value ~= nil then return value end
    local helper = rawget(_G, "ULuaArrayHelper")
    fn = safe_get(helper, "Get")
    ok, value = call_optional_self(fn, helper, array, index1)
    if ok then return value end
    return nil
end

function M.array_set_raw(array, index0, value)
    local index1 = index0 + 1
    if type(array) == "table" then return pcall(function() array[index1] = value end) end
    if type(array) ~= "userdata" then return false end
    local fn = safe_get(array, "Set")
    local ok = false
    if type(fn) == "function" then
        ok = select(1, call_optional_self(fn, array, index1, value))
        if ok then return true end
    end
    local helper = rawget(_G, "ULuaArrayHelper")
    fn = safe_get(helper, "Set")
    if type(fn) == "function" then
        ok = select(1, call_optional_self(fn, helper, array, index1, value))
        if ok then return true end
    end
    return pcall(function() array[index1] = value end)
end

function M.ensure_bone_name_pool(state)
    local pool = state.custom_dongdong_bone_name_pool
    if type(pool) ~= "table" then pool = {}; state.custom_dongdong_bone_name_pool = pool end
    return pool
end

function M.ensure_bone_array_snapshots(state)
    local snapshots = state.custom_dongdong_bone_array_snapshots
    if type(snapshots) ~= "table" then
        snapshots = { records = {}, seen = {} }
        state.custom_dongdong_bone_array_snapshots = snapshots
    end
    if type(snapshots.records) ~= "table" then snapshots.records = {} end
    if type(snapshots.seen) ~= "table" then snapshots.seen = {} end
    return snapshots
end

function M.binding_key(binding)
    if type(binding) ~= "table" then return "" end
    return table.concat({ tostring(binding.owner), tostring(binding.key), tostring(binding.parent_array),
        tostring(binding.parent_index), tostring(binding.parent_owner), tostring(binding.parent_key) }, "\0")
end

function M.add_binding(record, binding)
    if type(record) ~= "table" or type(binding) ~= "table" then return end
    if binding.owner == nil or binding.key == nil then return end
    if type(record.bindings) ~= "table" then record.bindings = {} end
    if type(record.binding_seen) ~= "table" then record.binding_seen = {} end
    local key = M.binding_key(binding)
    if record.binding_seen[key] then return end
    record.binding_seen[key] = true
    record.bindings[#record.bindings + 1] = binding
end

function M.snapshot_bone_array(state, array, binding)
    local t = type(array)
    if t ~= "table" and t ~= "userdata" then return nil end
    local snapshots = M.ensure_bone_array_snapshots(state)
    local record = snapshots.seen[array]
    if type(record) == "table" then
        M.add_binding(record, binding)
        return record
    end
    local count = M.array_len(array)
    if count <= 0 then return nil end
    record = { array=array, count=count, values={}, bindings={}, binding_seen={} }
    local pool = M.ensure_bone_name_pool(state)
    for index0 = 0, count - 1 do
        local value = M.array_get(array, index0)
        record.values[index0 + 1] = value
        local canonical = M.canonical_bone_name(value)
        if canonical ~= nil and pool[canonical] == nil then pool[canonical] = value end
    end
    M.add_binding(record, binding)
    snapshots.seen[array] = record
    snapshots.records[#snapshots.records + 1] = record
    return record
end

function M.resolve_bone_value(state, exemplar, desired)
    local pool = M.ensure_bone_name_pool(state)
    local key = M.canonical_bone_name(desired)
    local existing = pool[key]
    if existing ~= nil then return existing end
    return M.make_name(exemplar, desired)
end

function M.array_set_verified(state, array, index0, exemplar, desired)
    local replacement = M.resolve_bone_value(state, exemplar, desired)
    if not M.array_set_raw(array, index0, replacement) then return false end
    local current = M.array_get(array, index0)
    return M.canonical_bone_name(current) == M.canonical_bone_name(desired)
end

function M.restore_binding(binding, array)
    if type(binding) ~= "table" or binding.owner == nil or binding.key == nil then return false end
    local ok = pcall(function() binding.owner[binding.key] = array end)
    if binding.parent_array ~= nil and binding.parent_index ~= nil and binding.parent_value ~= nil then
        if M.array_set_raw(binding.parent_array, binding.parent_index, binding.parent_value) then ok = true end
    end
    if binding.parent_owner ~= nil and binding.parent_key ~= nil then
        if pcall(function() binding.parent_owner[binding.parent_key] = binding.parent_array end) then ok = true end
    end
    return ok
end

function M.restore_record_bindings(record)
    if type(record) ~= "table" or type(record.bindings) ~= "table" then return false end
    local restored = false
    for _, binding in ipairs(record.bindings) do
        if M.restore_binding(binding, record.array) then restored = true end
    end
    return restored
end

function M.restore_bone_array_snapshots(state)
    local snapshots = state.custom_dongdong_bone_array_snapshots
    if type(snapshots) ~= "table" or type(snapshots.records) ~= "table" then return false end
    local restored = false
    for _, record in ipairs(snapshots.records) do
        if type(record) == "table" and record.array ~= nil and type(record.values) == "table" then
            local record_restored = false
            local count = tonumber(record.count) or 0
            for index0 = 0, count - 1 do
                local original = record.values[index0 + 1]
                local canonical = M.canonical_bone_name(original)
                if canonical ~= nil and M.array_set_verified(state, record.array, index0, original, canonical) then
                    record_restored = true
                end
            end
            if record_restored and M.restore_record_bindings(record) then restored = true end
        end
    end
    local count = tonumber(state.custom_dongdong_aim_bone_restore_count) or 0
    state.custom_dongdong_aim_bone_restore_count = count + (restored and 1 or 0)
    return restored
end

local function apply_row_source(state, feature, root, key, row, table_name, handlers)
    row = M.table_extend(row)
    if type(row) ~= "table" then return false end
    local current = safe_get(root, key)
    if row ~= current then pcall(function() root[key] = row end) end
    if feature == "no_recoil" then
        M.apply_no_recoil_row(state, row)
    elseif feature == "converge" then
        M.converge_recursive(state, root, key, row, 0, {}, false)
    elseif feature == "anti_shake" then
        if not handlers or type(handlers.anti_shake) ~= "function" then return false end
        handlers.anti_shake(row)
    elseif feature == "aim" then
        if not handlers or type(handlers.aim) ~= "function" then return false end
        handlers.aim(root, key, row, table_name)
    else
        return false
    end
    return true
end

function M.apply_table(state, feature, table_value, table_name, handlers)
    local root = M.table_extend(table_value)
    if type(root) ~= "table" then return false end
    local success = false
    M.iterate_table(root, function(owner, key, row)
        if apply_row_source(state, feature, owner, key, row, table_name, handlers) then success = true end
    end)
    return success
end

-- P0.29.68: R27[feature], ipairs order, P13 lookup, raw identity dedupe,
-- P67 dispatch. Descriptive reconstructed name, not an original debug symbol.
-- Dependencies allow exercising the two captured closures without an engine.
function M.apply_feature(state, feature, handlers, captured)
    local names = M.FEATURE_TABLES[feature]
    if type(names) ~= "table" then return false end
    local success, seen = false, {}
    for _, name in ipairs(names) do
        local table_value = (captured and captured.get_data_table or M.get_data_table)(name)
        if table_value ~= nil and seen[table_value] ~= true then
            seen[table_value] = true
            local apply = captured and captured.apply_table or function(f, value, key)
                return M.apply_table(state, f, value, key, handlers)
            end
            if apply(feature, table_value, name) then success = true end
        end
    end
    return success
end

function M.get_catalog()
    return { prototypes=M.PROTOTYPES, feature_tables=M.FEATURE_TABLES, converge_field_count=#M.CONVERGE_FIELDS }
end

return M

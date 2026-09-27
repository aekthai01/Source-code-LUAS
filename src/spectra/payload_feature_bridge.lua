local S = ...
assert(type(S) == "table", "spectra module table required")
local M = {}
S.PayloadFeatureBridge = M

M.PROTOTYPE_GROUP = { "0.29.17", "0.29.26", "0.29.29", "0.29.63", "0.29.65", "0.29.66", "0.29.67", "0.29.68", "0.29.73", "0.29.77" }
-- Aim/anti-shake ownership is enabled only after the gated source-chain,
-- differential, ABI, rollback and deterministic CI checkpoint passed.
M.AIM_TAKEOVER_ENABLED = true

local installed = false
local original_feature_config
local original_aim_part
local last_error

local function source_modules()
    return S.Runtime, S.FeatureControl, S.MutationRuntime, S.AimChain,
        S.AimBones, S.AimABI, S.AimRefresh, S.AimRuntime
end

local function get_global(name)
    return rawget(_G, name)
end

local function call_saved(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    last_error = tostring(a)
    return false
end

local OWNED_TOGGLE_KEYS = {"aim", "anti_shake", "no_recoil", "converge"}
local function capture_toggles()
    local toggles = rawget(_G, "custom_dongdong_toggle_state")
    local snapshot = { exists = type(toggles) == "table" }
    if snapshot.exists then
        for _, key in ipairs(OWNED_TOGGLE_KEYS) do snapshot[key] = toggles[key] end
    end
    return snapshot
end

local function restore_toggles(snapshot)
    if not snapshot or snapshot.exists ~= true then
        rawset(_G, "custom_dongdong_toggle_state", nil)
        return
    end
    local toggles = rawget(_G, "custom_dongdong_toggle_state")
    if type(toggles) ~= "table" then
        toggles = {}
        rawset(_G, "custom_dongdong_toggle_state", toggles)
    end
    for _, key in ipairs(OWNED_TOGGLE_KEYS) do toggles[key] = snapshot[key] end
end

local function rollback_feature(feature)
    local Mutation = S.MutationRuntime
    if type(Mutation) ~= "table" then return false end
    local ok = true
    local function attempt(fn, ...)
        if type(fn) ~= "function" then ok = false; return end
        local called = pcall(fn, ...)
        if not called then ok = false end
    end
    if feature == "aim" or feature == "anti_shake" then
        attempt(Mutation.restore_bone_array_snapshots, _G)
        attempt(Mutation.restore_feature_snapshot, _G, "anti_shake")
        attempt(Mutation.restore_feature_snapshot, _G, "aim")
        rawset(_G, "custom_dongdong_bone_array_snapshots", nil)
        rawset(_G, "custom_dongdong_bone_name_pool", nil)
    else
        attempt(Mutation.restore_feature_snapshot, _G, feature)
    end
    return ok
end

local function default_dependencies(overrides)
    overrides = type(overrides) == "table" and overrides or {}
    local Runtime, _, Mutation, AimChain, AimBones, AimABI, AimRefresh, AimRuntime = source_modules()
    local deps = {}
    local function choose(name, fn) deps[name] = overrides[name] or fn end

    choose("restore_feature_snapshot", function(feature)
        return Mutation.restore_feature_snapshot(_G, feature)
    end)
    choose("restore_bone_array_snapshots", function()
        return Mutation.restore_bone_array_snapshots(_G)
    end)
    choose("apply_feature", function(feature)
        if feature == "aim" then
            local transaction = {}
            local function fail(err)
                if transaction.failure == nil then
                    transaction.failure = tostring(err or "source aim transaction failed")
                end
                return false
            end
            local aim_deps = {
                normalize_identifier = Mutation.normalize_identifier,
                read_field = AimABI.get,
                report_failure = fail,
                patch_bones = function(row)
                    local ok, result = pcall(AimBones.patch_row, _G, row)
                    if not ok then return fail(result) end
                    return result
                end,
                snapshot_set = function(snapshot_feature, owner, key, value)
                    local called, ok = pcall(Mutation.snapshot_set, _G,
                        snapshot_feature, owner, key, value)
                    if not called then return fail(ok) end
                    if not ok then return fail("source aim field write failed") end
                    return true
                end,
            }
            local handlers = {
                aim = function(owner, key, row, table_name)
                    local ok, result = pcall(AimChain.apply_aim_row, _G, aim_deps,
                        owner, key, row, table_name)
                    if not ok then return fail(result) end
                    return result
                end,
            }
            local result = Mutation.apply_feature(_G, feature, handlers)
            if transaction.failure ~= nil then error(transaction.failure, 0) end
            return result
        end
        return Mutation.apply_feature(_G, feature)
    end)
    choose("set_native_aim_assist", function(enabled)
        return AimRuntime.set_native_aim_assist(_G, enabled)
    end)
    choose("set_fire_assisted_aim_debug", function(enabled)
        return AimRuntime.set_fire_assisted_aim_debug(Runtime.delay, enabled)
    end)
    choose("delay", Runtime.delay)
    choose("init_current_weapon", function()
        return AimRefresh.init_current_weapon(Runtime.delay)
    end)
    choose("refresh_aiming_runtime", AimRefresh.refresh_methods)
    return deps
end

local function dependencies_ready(aim_enabled)
    local Runtime, FeatureControl, Mutation, AimChain, AimBones, AimABI, AimRefresh, AimRuntime = source_modules()
    local required = {
        {Runtime, "delay"}, {FeatureControl, "set_dongdong_feature_config"},
        {Mutation, "apply_feature"}, {Mutation, "restore_feature_snapshot"},
    }
    if aim_enabled then
        required[#required+1] = {FeatureControl, "set_dongdong_aim_part"}
        required[#required+1] = {Mutation, "restore_bone_array_snapshots"}
        required[#required+1] = {AimChain, "apply_aim_row"}
        required[#required+1] = {AimBones, "patch_row"}
        required[#required+1] = {AimABI, "get"}
        required[#required+1] = {AimRefresh, "init_current_weapon"}
        required[#required+1] = {AimRefresh, "refresh_methods"}
        required[#required+1] = {AimRuntime, "set_native_aim_assist"}
        required[#required+1] = {AimRuntime, "set_fire_assisted_aim_debug"}
    end
    for _, item in ipairs(required) do
        if type(item[1]) ~= "table" or type(item[1][item[2]]) ~= "function" then
            return false, "missing reconstructed dependency: " .. item[2]
        end
    end
    return true
end

local function source_owned(feature, aim_enabled)
    if feature == "no_recoil" or feature == "converge" then return true end
    return aim_enabled and (feature == "aim" or feature == "anti_shake")
end

local function run_feature_strict(feature, enabled, deps)
    local FeatureControl = S.FeatureControl
    local before = capture_toggles()
    local ok, result = pcall(FeatureControl.set_dongdong_feature_config, _G, deps, feature, enabled)
    if ok then return result end
    rollback_feature(feature)
    restore_toggles(before)
    error(result, 0)
end

local function make_feature_entry(aim_enabled, deps)
    return function(feature, enabled)
        if not source_owned(feature, aim_enabled) then
            return call_saved(original_feature_config, feature, enabled)
        end
        local before = capture_toggles()
        local ok, result = pcall(run_feature_strict, feature, enabled, deps)
        if ok then return result end
        last_error = tostring(result)
        local rolled_back = rollback_feature(feature)
        restore_toggles(before)
        if not rolled_back then return false end
        return call_saved(original_feature_config, feature, enabled)
    end
end

local function make_aim_part_entry(deps)
    return function(...)
        local args = {n=select("#", ...), ...}
        local fallback_used = false
        local function fallback(reason)
            if fallback_used then return false end
            fallback_used = true
            last_error = tostring(reason or "source aim-part failure")
            -- Preserve the toggle state that exists when the delayed failure
            -- actually occurs. Restoring the state from P77 entry could undo a
            -- legitimate user switch that happened between callbacks.
            local current = capture_toggles()
            local rolled_back = rollback_feature("aim")
            restore_toggles(current)
            if not rolled_back then return false end
            return call_saved(original_aim_part, table.unpack(args, 1, args.n))
        end

        local p77_deps = {}
        for key, value in pairs(deps) do p77_deps[key] = value end
        p77_deps.set_feature_config = function(feature, enabled)
            return run_feature_strict(feature, enabled, p77_deps)
        end
        local base_delay = deps.delay
        p77_deps.delay = function(seconds, callback)
            return base_delay(seconds, function()
                local ok, err = pcall(callback)
                if not ok then fallback(err) end
            end)
        end

        local ok, result = pcall(S.FeatureControl.set_dongdong_aim_part, _G, p77_deps)
        if not ok then return fallback(result) end
        return result
    end
end

function M.takeover_after_payload_load(options)
    if installed then return true end
    options = type(options) == "table" and options or {}
    local aim_enabled = options.force_aim_takeover == true or M.AIM_TAKEOVER_ENABLED == true
    local ready, why = dependencies_ready(aim_enabled)
    if not ready then return false, why end

    local feature_original = get_global("set_dongdong_feature_config")
    local aim_original = get_global("set_dongdong_aim_part")
    if type(feature_original) ~= "function" then return false, "original feature function missing" end
    if aim_enabled and type(aim_original) ~= "function" then return false, "original aim-part function missing" end

    local deps = default_dependencies(options.deps)
    local feature_entry = make_feature_entry(aim_enabled, deps)
    local aim_entry = aim_enabled and make_aim_part_entry(deps) or nil
    local setter = options.set_global or function(name, value) rawset(_G, name, value) end

    original_feature_config = feature_original
    original_aim_part = aim_original
    local ok, err = pcall(setter, "set_dongdong_feature_config", feature_entry)
    if not ok then
        last_error = tostring(err)
        return false, last_error
    end
    if aim_enabled then
        ok, err = pcall(setter, "set_dongdong_aim_part", aim_entry)
        if not ok then
            rawset(_G, "set_dongdong_feature_config", feature_original)
            rawset(_G, "set_dongdong_aim_part", aim_original)
            last_error = tostring(err)
            return false, last_error
        end
    end
    installed = true
    last_error = nil
    return true
end

function M.restore_original()
    if installed and type(original_feature_config) == "function" then
        rawset(_G, "set_dongdong_feature_config", original_feature_config)
    end
    if installed and type(original_aim_part) == "function" then
        rawset(_G, "set_dongdong_aim_part", original_aim_part)
    end
    installed = false
    return true
end

function M.status()
    local aim_owned = installed and M.AIM_TAKEOVER_ENABLED == true
    return {
        installed = installed,
        partial_takeover = {no_recoil=installed, converge=installed,
            aim=aim_owned, anti_shake=aim_owned},
        original_feature_config = original_feature_config,
        original_aim_part = original_aim_part,
        last_error = last_error,
    }
end

return M

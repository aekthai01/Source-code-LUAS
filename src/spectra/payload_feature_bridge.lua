local S = ...
assert(type(S) == "table", "spectra module table required")
local FeatureControl = assert(S.FeatureControl, "FeatureControl required")
local Mutation = assert(S.MutationRuntime, "MutationRuntime required")
local M = {}
S.PayloadFeatureBridge = M

M.PROTOTYPE_GROUP = { "0.29.17", "0.29.26", "0.29.29", "0.29.67", "0.29.68" }

local original_feature_config
local installed = false

local function call_original(...)
    if type(original_feature_config) ~= "function" then return false end
    local ok, value = pcall(original_feature_config, ...)
    if ok then return value end
    return false
end

function M.takeover_after_payload_load()
    if installed then return true end
    original_feature_config = rawget(_G, "set_dongdong_feature_config")
    if type(original_feature_config) ~= "function" then return false, "original feature function missing" end

    local deps = {
        restore_feature_snapshot = function(feature)
            return Mutation.restore_feature_snapshot(_G, feature)
        end,
        apply_feature = function(feature)
            return Mutation.apply_feature(_G, feature)
        end,
        -- These branches are not reached by the D3 source-owned features.
        restore_bone_array_snapshots = function()
            return Mutation.restore_bone_array_snapshots(_G)
        end,
        set_native_aim_assist = function() return false end,
        set_fire_assisted_aim_debug = function() return false end,
    }

    rawset(_G, "set_dongdong_feature_config", function(feature, enabled)
        if feature == "no_recoil" or feature == "converge" then
            return FeatureControl.set_dongdong_feature_config(_G, deps, feature, enabled)
        end
        return call_original(feature, enabled)
    end)
    installed = true
    return true
end

function M.restore_original()
    if installed and type(original_feature_config) == "function" then
        rawset(_G, "set_dongdong_feature_config", original_feature_config)
    end
    installed = false
    return true
end

function M.status()
    return { installed=installed, partial_takeover={no_recoil=true, converge=true, aim=false, anti_shake=false} }
end

return M

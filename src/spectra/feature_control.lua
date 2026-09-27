local S = ...
assert(type(S) == "table", "spectra module table required")

-- Phase D2 source reconstruction of payload prototypes P0.29.73 and P0.29.77.
-- Engine/data-table mutation helpers are explicit dependencies because their original
-- implementations live in sibling stripped prototypes and are reconstructed separately.
local M = {}
S.FeatureControl = M

M.BUILD_REVISION = "v62-character-color-refresh-skin-mesh"
M.PROTOTYPES = {
    set_dongdong_feature_config = "0.29.73",
    set_dongdong_aim_part = "0.29.77",
}

local function ensure_state(state)
    local toggles = state.custom_dongdong_toggle_state
    if type(toggles) ~= "table" then
        toggles = {}
        state.custom_dongdong_toggle_state = toggles
    end
    return toggles
end

local function need(deps, name)
    local fn = deps and deps[name]
    assert(type(fn) == "function", "missing reconstructed dependency: " .. name)
    return fn
end

function M.set_dongdong_feature_config(state, deps, feature, enabled)
    assert(type(state) == "table", "state table required")
    local toggles = ensure_state(state)

    if feature == "aim" or feature == "anti_shake" then
        if enabled == true then
            toggles[feature] = true
            if feature == "aim" then
                toggles.anti_shake = false
            else
                toggles.aim = false
            end
        else
            toggles[feature] = false
        end

        need(deps, "restore_bone_array_snapshots")()
        need(deps, "restore_feature_snapshot")("anti_shake")
        need(deps, "restore_feature_snapshot")("aim")

        local active = toggles.aim == true or toggles.anti_shake == true
        if active then need(deps, "apply_feature")("aim") end
        need(deps, "set_native_aim_assist")(active)
        need(deps, "set_fire_assisted_aim_debug")(toggles.aim == true)
        return true
    end

    toggles[feature] = enabled == true
    if feature ~= "no_recoil" and feature ~= "converge" then
        return false
    end

    need(deps, "restore_feature_snapshot")(feature)
    if enabled == true then need(deps, "apply_feature")(feature) end
    return true
end

function M.set_dongdong_aim_part(state, deps)
    assert(type(state) == "table", "state table required")
    local delay = need(deps, "delay")
    local set_feature = deps.set_feature_config or function(feature, enabled)
        return M.set_dongdong_feature_config(state, deps, feature, enabled)
    end

    local revision = (tonumber(state.custom_dongdong_aim_part_revision) or 0) + 1
    state.custom_dongdong_aim_part_revision = revision

    delay(0.12, function()
        if revision ~= state.custom_dongdong_aim_part_revision then return end
        local toggles = type(state.custom_dongdong_toggle_state) == "table" and state.custom_dongdong_toggle_state or {}
        local mode
        if toggles.aim == true then mode = "aim"
        elseif toggles.anti_shake == true then mode = "anti_shake" end
        if mode == nil then return end

        set_feature(mode, false)
        state.custom_dongdong_bone_array_snapshots = nil
        state.custom_dongdong_bone_name_pool = nil
        state.custom_dongdong_bone_cache_revision = M.BUILD_REVISION

        delay(0.04, function()
            set_feature(mode, true)
            delay(0.1, function()
                if revision ~= state.custom_dongdong_aim_part_revision then return end
                local initialized = need(deps, "init_current_weapon")()
                if not initialized then need(deps, "refresh_aiming_runtime")() end

                delay(0.38, function()
                    local current = type(state.custom_dongdong_toggle_state) == "table" and state.custom_dongdong_toggle_state or {}
                    if mode == "aim" and current.aim == true then
                        set_feature("aim", true)
                    elseif mode == "anti_shake" and current.anti_shake == true then
                        set_feature("anti_shake", true)
                    end
                end)
            end)
        end)
    end)
    return true
end

function M.get_catalog()
    return { prototypes = M.PROTOTYPES, build_revision = M.BUILD_REVISION }
end

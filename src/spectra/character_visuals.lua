local S = ...
assert(type(S) == "table", "spectra module table required")

-- Phase D2 source reconstruction of public visual-entry prototypes P0.29.99..103.
-- Lower-level mesh scanning/material mutation remains an explicit dependency for the next group.
local M = {}
S.CharacterVisuals = M
M.PROTOTYPES = {
    normalize_color = "0.29.99",
    normalize_ai_color = "0.29.100",
    set_ai_color = "0.29.101",
    set_real_player_color = "0.29.102",
    set_character_xray = "0.29.103",
}

M.COLOR_NAMES = { red = "红色", green = "绿色", none = "不着色" }

function M.normalize_color(value)
    if value == "green" then return "green" end
    return "red"
end

function M.normalize_ai_color(value)
    if value == "none" or value == "off" or value == "disabled" then return "none" end
    return M.normalize_color(value)
end

local function need(deps, name)
    local fn = deps and deps[name]
    assert(type(fn) == "function", "missing reconstructed dependency: " .. name)
    return fn
end

function M.set_ai_color(state, deps, value)
    local key = M.normalize_ai_color(value)
    if key == "none" then need(deps, "restore_mesh_category")("ai") end
    state.custom_ai_color_enabled = key ~= "none"
    state.custom_ai_color_key = key
    state.custom_ai_color_name = M.COLOR_NAMES[key]
    need(deps, "rescan_character_colors")()
end

function M.set_real_player_color(state, deps, value)
    local key = M.normalize_color(value)
    state.custom_real_color_key = key
    state.custom_real_color_name = M.COLOR_NAMES[key]
    need(deps, "rescan_character_colors")()
end

function M.set_character_xray(state, deps, enabled)
    state.custom_character_xray_enabled = enabled == true
    if state.custom_character_xray_enabled then
        local meshes = state.custom_character_xray_meshes or {}
        for mesh, snapshot in pairs(meshes) do
            need(deps, "restore_mesh_snapshot")(mesh, snapshot)
        end
        state.custom_character_xray_meshes = need(deps, "new_weak_mesh_table")()
    end
    need(deps, "rescan_character_colors")()
end

function M.get_catalog() return { prototypes = M.PROTOTYPES } end

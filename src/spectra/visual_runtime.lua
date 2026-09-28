local S = ...
assert(type(S) == "table", "spectra module table required")
local M = {}
S.VisualRuntime = M
M.PROTOTYPES = { new_weak_mesh_table="0.29.0", restore_mesh_snapshot="0.29.92", restore_mesh_category="0.29.95", reset_scan_state="0.29.96" }

local function safe_get(obj,key)
    if obj==nil then return nil end
    local ok,v=pcall(function() return obj[key] end); if ok then return v end
end
local function call_method(obj,name,...)
    local fn=safe_get(obj,name); if type(fn)~="function" then return false,nil end
    local ok,a=pcall(fn,obj,...); if ok then return true,a end
    return pcall(fn,...)
end

function M.new_weak_mesh_table() return setmetatable({}, {__mode="k"}) end

function M.restore_mesh_snapshot(mesh, snapshot)
    if mesh == nil or type(snapshot) ~= "table" then return end
    if type(snapshot.materials) == "table" then
        for index, material in pairs(snapshot.materials) do
            call_method(mesh, "SetMaterial", index, material == false and false or material)
        end
    end
    call_method(mesh, "SetOverlayMaterial", nil)
    call_method(mesh, "SetRenderCustomDepth", false)
    call_method(mesh, "SetCustomDepthStencilValue", 0)
end

function M.restore_mesh_category(state, category)
    local meshes = state.custom_character_xray_meshes or {}
    for mesh, snapshot in pairs(meshes) do
        if type(snapshot) == "table" and snapshot.category == category then
            M.restore_mesh_snapshot(mesh, snapshot)
            meshes[mesh] = nil
        end
    end
end

function M.reset_scan_state(state)
    state.custom_character_scan_actor_snapshot = nil
    state.custom_character_scan_actor_cursor = 1
    state.custom_character_scan_actor_snapshot_attempt = -1
    state.custom_character_scan_actor_snapshot_character = nil
end

return M

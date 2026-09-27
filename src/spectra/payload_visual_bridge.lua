local S = ...
assert(type(S)=="table","spectra module table required")
local CV=assert(S.CharacterVisuals,"CharacterVisuals required")
local VS=assert(S.VisualScan,"VisualScan required")
local VR=assert(S.VisualRuntime,"VisualRuntime required")
local Runtime=assert(S.Runtime,"Runtime required")
local M={}; S.PayloadVisualBridge=M
local original={}; local installed=false

local function deps()
    return {
        restore_mesh_category=function(category) return VS.restore_mesh_category(_G,category) end,
        restore_mesh_snapshot=VS.restore_mesh_snapshot,
        new_weak_mesh_table=VR.new_weak_mesh_table,
        rescan_character_colors=function() return VS.rescan_character_colors(_G,Runtime.delay) end,
    }
end
function M.takeover_after_payload_load()
    if installed then return true end
    original.set_ai_color=rawget(_G,"set_ai_color")
    original.set_real_player_color=rawget(_G,"set_real_player_color")
    original.set_character_xray=rawget(_G,"set_character_xray")
    if type(original.set_ai_color)~="function" or type(original.set_real_player_color)~="function" or type(original.set_character_xray)~="function" then
        return false,"original visual globals missing"
    end
    local d=deps()
    rawset(_G,"set_ai_color",function(v) return CV.set_ai_color(_G,d,v) end)
    rawset(_G,"set_real_player_color",function(v) return CV.set_real_player_color(_G,d,v) end)
    rawset(_G,"set_character_xray",function(v) return CV.set_character_xray(_G,d,v) end)
    local hook_ok=VS.install_fashion_refresh_hook(_G,Runtime.delay)
    local tick_ok=VS.install_tick(_G)
    if not tick_ok then VS.fallback_scan_loop(_G,Runtime.delay,0) end
    _G._spectra_visual_hook_source_owned = hook_ok == true
    _G._spectra_visual_tick_source_owned = tick_ok == true
    installed=true; return true
end
function M.restore_original()
    if installed then for k,v in pairs(original) do if type(v)=="function" then rawset(_G,k,v) end end end
    installed=false; return true
end
function M.status() return {installed=installed, public_visuals_source_owned=installed, fashion_hook_source_owned=_G._spectra_visual_hook_source_owned==true, tick_source_owned=_G._spectra_visual_tick_source_owned==true} end
return M

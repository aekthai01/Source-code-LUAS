local root=assert(arg[1],"root path required")
local S={}; assert(loadfile(root.."/src/spectra/character_visuals.lua"))(S); local M=assert(S.CharacterVisuals)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
eq(M.normalize_color("green"),"green"); eq(M.normalize_color("anything"),"red")
eq(M.normalize_ai_color("off"),"none"); eq(M.normalize_ai_color("disabled"),"none"); eq(M.normalize_ai_color("green"),"green")
local state={custom_character_xray_meshes={m1={id=1}}}; local calls={}
local deps={
 restore_mesh_category=function(k) calls[#calls+1]="cat:"..k end,
 rescan_character_colors=function() calls[#calls+1]="rescan" end,
 restore_mesh_snapshot=function(m,s) calls[#calls+1]="restore:"..m end,
 new_weak_mesh_table=function() return {fresh=true} end,
}
M.set_ai_color(state,deps,"none"); eq(state.custom_ai_color_enabled,false); eq(state.custom_ai_color_key,"none"); eq(state.custom_ai_color_name,"不着色")
M.set_real_player_color(state,deps,"green"); eq(state.custom_real_color_key,"green"); eq(state.custom_real_color_name,"绿色")
M.set_character_xray(state,deps,true); eq(state.custom_character_xray_enabled,true); eq(state.custom_character_xray_meshes.fresh,true)
print("character-visuals: ok")

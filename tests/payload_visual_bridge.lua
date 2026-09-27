local root=assert(arg[1]); local S={}
S.Runtime={delay=function(_,cb) cb(); return true end}
assert(loadfile(root..'/src/spectra/visual_runtime.lua'))(S)
assert(loadfile(root..'/src/spectra/visual_scan.lua'))(S)
assert(loadfile(root..'/src/spectra/character_visuals.lua'))(S)
local orig_ai=function() return 'orig-ai' end
local orig_real=function() return 'orig-real' end
local orig_x=function() return 'orig-x' end
_G.set_ai_color=orig_ai; _G.set_real_player_color=orig_real; _G.set_character_xray=orig_x
local rescans=0
_G.DFMCharacterItemFashionManager={Get=function() return {OnSetMatTaskComplete={Add=function(self,cb,owner) return 'h' end}} end}
_G.LuaTickController={Get=function() return {RegisterTick=function(self,cb) return true end,UnregisterTick=function() end} end}
S.VisualScan.rescan_character_colors=function() rescans=rescans+1 end
S.VisualScan.restore_mesh_category=function() end
S.VisualScan.restore_mesh_snapshot=function() end
assert(loadfile(root..'/src/spectra/payload_visual_bridge.lua'))(S)
local ok=S.PayloadVisualBridge.takeover_after_payload_load(); assert(ok==true)
assert(_G.set_ai_color~=orig_ai and _G.set_real_player_color~=orig_real and _G.set_character_xray~=orig_x)
_G.set_ai_color('green'); assert(_G.custom_ai_color_key=='green' and _G.custom_ai_color_enabled==true)
_G.set_real_player_color('red'); assert(_G.custom_real_color_key=='red')
_G.set_character_xray(false); assert(_G.custom_character_xray_enabled==false)
assert(rescans==3)
local st=S.PayloadVisualBridge.status(); assert(st.installed and st.public_visuals_source_owned and st.fashion_hook_source_owned and st.tick_source_owned)
S.PayloadVisualBridge.restore_original(); assert(_G.set_ai_color==orig_ai and _G.set_real_player_color==orig_real and _G.set_character_xray==orig_x)
print('payload-visual-bridge: ok')

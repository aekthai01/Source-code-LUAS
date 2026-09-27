local root=assert(arg[1]); local S={}; assert(loadfile(root.."/src/spectra/visual_runtime.lua"))(S); local M=S.VisualRuntime
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local weak=M.new_weak_mesh_table(); eq(getmetatable(weak).__mode,"k")
local mesh={calls={}}; setmetatable(mesh,{__index=function(t,k) return function(self,...) self.calls[#self.calls+1]={k,...} end end})
local state={custom_character_xray_meshes={[mesh]={category="ai",materials={[0]="m0",[1]=false}}}}
M.restore_mesh_category(state,"ai"); eq(state.custom_character_xray_meshes[mesh],nil); eq(mesh.calls[1][1],"SetMaterial"); eq(mesh.calls[#mesh.calls][1],"SetCustomDepthStencilValue")
M.reset_scan_state(state); eq(state.custom_character_scan_actor_cursor,1); eq(state.custom_character_scan_actor_snapshot_attempt,-1)
print("visual-runtime: ok")

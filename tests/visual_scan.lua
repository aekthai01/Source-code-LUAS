local root=assert(arg[1]); local S={}
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root .. "/src/spectra/p029_runtime_helpers.lua"))(S)
assert(loadfile(root..'/src/spectra/visual_scan.lua'))(S)
local V=S.VisualScan

local function mesh()
  local m={materials={[0]='orig0',[1]='orig1'}, overlay='origOverlay', depth=false, stencil=0, params={}}
  function m:GetNumMaterials() return 2 end
  function m:GetMaterial(i) return self.materials[i] end
  function m:SetMaterial(i,v) self.materials[i]=v end
  function m:SetOverlayMaterial(v) self.overlay=v end
  function m:SetRenderCustomDepth(v) self.depth=v end
  function m:SetCustomDepthStencilValue(v) self.stencil=v end
  function m:CreateAndSetMaterialInstanceDynamic(i) return self.materials[i] end
  function m:SetVectorParameterValueOnMaterials(k,v) self.params[tostring(k)]=v end
  return m
end

local m=mesh(); assert(V.is_mesh_component(m)==true)
local actor={Mesh=m}; function actor:GetName() return 'BP_DFMCharacter_C_77' end
assert(V.is_ai_actor(actor)==false)
local ai={Mesh=mesh(),bIsAI=true}; function ai:GetName() return 'SomeBot' end
assert(V.is_ai_actor(ai)==true)
local meshes=V.collect_character_meshes(actor); assert(#meshes>=1 and meshes[1]==m)

_G.isvalid=function() return true end
_G.slua={dontCallLoadObject=function(path) return 'MAT:'..path end}
local state={custom_character_xray_enabled=true,custom_character_xray_materials={},custom_character_xray_meshes=setmetatable({}, {__mode='k'})}
V.apply_xray_mesh(state,m,0,'red','real')
assert(m.depth==true and m.stencil==20 and tostring(m.materials[0]):find('MAT:',1,true))
local snap=state.custom_character_xray_meshes[m]; assert(type(snap)=='table' and snap.category=='real')
V.restore_mesh_snapshot(m,snap); assert(m.materials[0]=='orig0' and m.materials[1]=='orig1' and m.depth==false and m.stencil==0)

state.custom_character_xray_enabled=false; state.custom_character_normal_seen=setmetatable({}, {__mode='k'})
V.apply_normal_color(state,m,0,'green'); assert(m.depth==false and m.stencil==0 and next(m.params)~=nil)

local scheduled={}; local scan_calls=0; local old=V.scan_character_batch
V.scan_character_batch=function(_,attempt) scan_calls=scan_calls+1; assert(attempt==9) end
state.custom_character_color_attempt=9
V.rescan_character_colors(state,function(sec,cb) scheduled[#scheduled+1]={sec,cb}; return true end)
assert(#scheduled==5 and scheduled[1][1]==0 and scheduled[5][1]==1.2)
for _,e in ipairs(scheduled) do e[2]() end
assert(scan_calls==5)
V.scan_character_batch=old
print('visual-scan: ok')

-- P104 fashion refresh hook takeover.
local removed=0; local added=0; local captured
local delegate={}
function delegate:Remove() removed=removed+1 end
function delegate:Add(cb,owner) added=added+1; captured=cb; return 'h' end
_G.DFMCharacterItemFashionManager={Get=function() return {OnSetMatTaskComplete=delegate} end}
state.custom_character_fashion_refresh_hook={delegate=delegate,callback=function()end,owner={}}
V.rescan_character_colors=function() state._rescanned=(state._rescanned or 0)+1 end
assert(V.install_fashion_refresh_hook(state,function()end)==true)
assert(removed==2 and added==1 and type(captured)=='function')
captured(); assert(state._rescanned==1)

-- P107 tick: replace old global callback, throttle at 0.25 s, increment attempt.
local unreg,registered=0,nil
local controller={}
function controller:UnregisterTick(cb) unreg=unreg+1 end
function controller:RegisterTick(cb) registered=cb; return true end
_G.LuaTickController={Get=function() return controller end}
_G.__AUTHOR_XRAY_UI_TICK=function() end
local tick_scans=0
V.scan_character_batch=function(_,attempt) tick_scans=tick_scans+1; state._last_attempt=attempt end
assert(V.install_tick(state)==true and unreg==1 and registered==_G.__AUTHOR_XRAY_UI_TICK)
registered(0.10); registered(0.10); assert(tick_scans==0)
registered(0.06); assert(tick_scans==1 and state._last_attempt==10)
print('visual-background: ok')

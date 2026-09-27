local root = assert(arg[1], "root path required")
local S = {}
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
assert(loadfile(root .. "/src/spectra/feature_control.lua"))(S)
assert(loadfile(root .. "/src/spectra/payload_feature_bridge.lua"))(S)
local Mutation = assert(S.MutationRuntime)
local Bridge = assert(S.PayloadFeatureBridge)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end

local recoil_root={Default={SingleOrBurstShootRecoil={HorizontalScale=4,VerticalScale=6}}}
local spread_root={Default={Spread={X=9,Y=10},Other=77}}
local aliases={}
for _,n in ipairs(Mutation.FEATURE_TABLES.no_recoil) do aliases[n]=recoil_root end
for _,n in ipairs(Mutation.FEATURE_TABLES.converge) do aliases[n]=spread_root end
local manager={}
function manager:GetTable(name) return aliases[name] end
_G.Facade={TableManager=manager}
_G.custom_dongdong_toggle_state={}
_G.custom_dongdong_feature_snapshots=nil

local original_calls={}
local original=function(feature,enabled)
  original_calls[#original_calls+1]={feature,enabled}
  return "original:"..tostring(feature)..":"..tostring(enabled)
end
_G.set_dongdong_feature_config=original

truth(Bridge.takeover_after_payload_load(),"bridge takeover")
truth(_G.set_dongdong_feature_config ~= original,"global replaced")
eq(_G.set_dongdong_feature_config("no_recoil",true),true,"source no recoil enable")
eq(recoil_root.Default.SingleOrBurstShootRecoil.HorizontalScale,0.0,"source no recoil applied")
eq(#original_calls,0,"no recoil must not delegate")
eq(_G.set_dongdong_feature_config("no_recoil",false),true,"source no recoil disable")
eq(recoil_root.Default.SingleOrBurstShootRecoil.HorizontalScale,4,"source no recoil restored")

eq(_G.set_dongdong_feature_config("converge",true),true,"source converge enable")
eq(spread_root.Default.Spread.X,0.0,"source converge applied")
eq(#original_calls,0,"converge must not delegate")
eq(_G.set_dongdong_feature_config("converge",false),true,"source converge disable")
eq(spread_root.Default.Spread.X,9,"source converge restored")

local delegated=_G.set_dongdong_feature_config("aim",true)
eq(delegated,"original:aim:true","aim delegated return")
eq(#original_calls,1,"aim delegated once")
eq(original_calls[1][1],"aim","aim delegate feature")
eq(Bridge.status().partial_takeover.anti_shake,false,"anti shake not source owned")
truth(Bridge.restore_original(),"restore bridge")
eq(_G.set_dongdong_feature_config,original,"original restored")

print("payload-feature-bridge: ok")

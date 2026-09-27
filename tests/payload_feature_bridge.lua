local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/feature_control.lua"))(S)
S.Runtime = { delay=function(_, cb) cb(); return false end }
S.MutationRuntime = {
    apply_feature=function() return true end,
    restore_feature_snapshot=function() return true end,
    restore_bone_array_snapshots=function() return true end,
    snapshot_set=function() return true end,
    normalize_identifier=function(v) return tostring(v or ""):lower():gsub("[^%w]","") end,
}
S.AimChain = { apply_aim_row=function() return true end }
S.AimBones = { patch_row=function() return true end }
S.AimABI = { get=function(o,k) return o and o[k] or nil end }
S.AimRefresh = { init_current_weapon=function() return true end, refresh_methods=function() return true end }
S.AimRuntime = { set_native_aim_assist=function() return true end, set_fire_assisted_aim_debug=function() return true end }
assert(loadfile(root .. "/src/spectra/payload_feature_bridge.lua"))(S)
local Bridge=S.PayloadFeatureBridge
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function reset_globals(feature, aim)
  Bridge.restore_original()
  _G.set_dongdong_feature_config=feature
  _G.set_dongdong_aim_part=aim
  _G.custom_dongdong_toggle_state={aim=true,anti_shake=false,no_recoil=false,converge=false}
  _G.custom_dongdong_feature_snapshots=nil
  _G.custom_dongdong_bone_array_snapshots=nil
end
local original_feature_calls, original_aim_calls = {},0
local original_feature=function(feature,enabled)
  original_feature_calls[#original_feature_calls+1]={feature,enabled}
  return "payload:"..feature..":"..tostring(enabled)
end
local original_aim=function() original_aim_calls=original_aim_calls+1; return "payload-aim" end

eq(Bridge.AIM_TAKEOVER_ENABLED,true,"production aim gate")

-- Missing second payload entrypoint leaves both globals untouched.
reset_globals(original_feature,nil)
local ok=Bridge.takeover_after_payload_load()
eq(ok,false,"missing dependency install")
eq(_G.set_dongdong_feature_config,original_feature,"feature global unchanged")
eq(_G.set_dongdong_aim_part,nil,"aim global unchanged")

-- Halfway setter failure rolls the first replacement back.
reset_globals(original_feature,original_aim)
local writes=0
ok=Bridge.takeover_after_payload_load({set_global=function(name,value)
  writes=writes+1
  if writes==2 then error("halfway") end
  rawset(_G,name,value)
end})
eq(ok,false,"halfway install result")
eq(_G.set_dongdong_feature_config,original_feature,"feature rollback")
eq(_G.set_dongdong_aim_part,original_aim,"aim rollback")

-- Successful dual-global source ownership using the production gate.
reset_globals(original_feature,original_aim)
local queue, source_calls = {},{}
local deps={
  restore_bone_array_snapshots=function() source_calls[#source_calls+1]="restore-bones"; return true end,
  restore_feature_snapshot=function(k) source_calls[#source_calls+1]="restore:"..k; return true end,
  apply_feature=function(k) source_calls[#source_calls+1]="apply:"..k; return true end,
  set_native_aim_assist=function(v) source_calls[#source_calls+1]="native:"..tostring(v); return true end,
  set_fire_assisted_aim_debug=function(v) source_calls[#source_calls+1]="debug:"..tostring(v); return true end,
  delay=function(t,fn) queue[#queue+1]={t,fn}; return true end,
  init_current_weapon=function() source_calls[#source_calls+1]="init"; return true end,
  refresh_aiming_runtime=function() source_calls[#source_calls+1]="refresh"; return true end,
}
truth(Bridge.takeover_after_payload_load({deps=deps}),"dual install")
truth(_G.set_dongdong_feature_config~=original_feature,"feature replaced")
truth(_G.set_dongdong_aim_part~=original_aim,"aim-part replaced")
local status=Bridge.status()
eq(status.partial_takeover.aim,true,"status aim owned")
eq(status.partial_takeover.anti_shake,true,"status anti-shake owned")
eq(_G.set_dongdong_feature_config("aim",true),true,"source aim enable")
eq(#original_feature_calls,0,"source aim must not delegate on success")
eq(_G.custom_dongdong_toggle_state.aim,true,"aim active")
eq(_G.custom_dongdong_toggle_state.anti_shake,false,"exclusive")
_G.set_dongdong_feature_config("anti_shake",true)
eq(_G.custom_dongdong_toggle_state.aim,false,"aim disabled by anti-shake")
eq(_G.custom_dongdong_toggle_state.anti_shake,true,"anti-shake active")

-- P77 keeps its captured source P73 even if the public global is changed later.
_G.custom_dongdong_toggle_state={aim=true,anti_shake=false}
queue={}; source_calls={}
local source_aim_entry=_G.set_dongdong_aim_part
truth(source_aim_entry(),"source p77 scheduled")
local trap_calls=0
_G.set_dongdong_feature_config=function() trap_calls=trap_calls+1; error("hybrid global used") end
eq(queue[1][1],0.12,"p77 first delay")
queue[1][2](); eq(queue[2][1],0.04,"p77 second delay")
queue[2][2](); eq(queue[3][1],0.1,"p77 third delay")
queue[3][2](); eq(queue[4][1],0.38,"p77 final delay")
queue[4][2](); eq(trap_calls,0,"delayed callbacks retain source P73")

-- Delayed source failure rolls state back and delegates to the saved payload P77 once.
Bridge.restore_original(); reset_globals(original_feature,original_aim)
queue={}; original_aim_calls=0
local fail_deps={}
for k,v in pairs(deps) do fail_deps[k]=v end
fail_deps.delay=function(t,fn) queue[#queue+1]={t,fn}; return true end
fail_deps.init_current_weapon=function() error("init failed") end
truth(Bridge.takeover_after_payload_load({deps=fail_deps}),"reinstall for delayed failure")
_G.custom_dongdong_toggle_state={aim=true,anti_shake=false}
_G.set_dongdong_aim_part()
queue[1][2](); queue[2][2](); queue[3][2]()
eq(original_aim_calls,1,"payload p77 fallback exactly once")
eq(_G.custom_dongdong_toggle_state.aim,true,"toggle restored before payload fallback")

Bridge.restore_original()
print("payload-feature-bridge: ok")

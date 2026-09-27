local root = assert(arg[1], "root path required")
local S = {}
assert(loadfile(root .. "/src/spectra/feature_control.lua"))(S)
local M = assert(S.FeatureControl)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local state={custom_dongdong_toggle_state={aim=false,anti_shake=false,no_recoil=false,converge=false}}
local log={}
local queue={}
local function rec(n,...) log[#log+1]={n,...} end
local deps={
 restore_bone_array_snapshots=function() rec("restore_bones") end,
 restore_feature_snapshot=function(k) rec("restore",k) end,
 apply_feature=function(k) rec("apply",k) end,
 set_native_aim_assist=function(v) rec("native",v) end,
 set_fire_assisted_aim_debug=function(v) rec("debug",v) end,
 delay=function(t,fn) queue[#queue+1]={t,fn} end,
 init_current_weapon=function() rec("init_weapon"); return false end,
 refresh_aiming_runtime=function() rec("refresh_runtime"); return true end,
}
eq(M.set_dongdong_feature_config(state,deps,"aim",true),true,"aim enable")
eq(state.custom_dongdong_toggle_state.aim,true,"aim state")
eq(state.custom_dongdong_toggle_state.anti_shake,false,"anti exclusive")
eq(log[#log-1][1],"native","native call")
eq(log[#log][1],"debug","debug call")
eq(M.set_dongdong_feature_config(state,deps,"bogus",true),false,"unknown feature")
eq(state.custom_dongdong_toggle_state.bogus,true,"baseline stores unknown before reject")
log={}; state.custom_dongdong_toggle_state.aim=true
M.set_dongdong_aim_part(state,deps)
eq(queue[1][1],0.12,"first delay"); queue[1][2](); eq(queue[2][1],0.04,"second delay")
queue[2][2](); eq(queue[3][1],0.1,"third delay"); queue[3][2](); eq(queue[4][1],0.38,"fourth delay"); queue[4][2]()
eq(state.custom_dongdong_bone_array_snapshots,nil,"bone snapshots reset")
eq(state.custom_dongdong_bone_name_pool,nil,"bone pool reset")
eq(state.custom_dongdong_bone_cache_revision,M.BUILD_REVISION,"bone revision")
-- A later target-part change invalidates callbacks captured by an older revision.
queue={}; log={}; state.custom_dongdong_toggle_state.aim=true
M.set_dongdong_aim_part(state,deps)
local stale=queue[1][2]
M.set_dongdong_aim_part(state,deps)
stale()
eq(#queue,2,"stale revision did not enqueue reapply")
eq(#log,0,"stale revision did not mutate state")
print("feature-control: ok")

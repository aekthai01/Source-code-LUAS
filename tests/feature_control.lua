local root = assert(arg[1], "root path required")
local S = {}
assert(loadfile(root .. "/src/spectra/feature_control.lua"))(S)
local M = assert(S.FeatureControl)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end

local function harness(init_result, refresh_result)
    local state={custom_dongdong_toggle_state={aim=false,anti_shake=false,no_recoil=false,converge=false}}
    local queue, log = {}, {}
    local function rec(name, ...) log[#log+1]={name,...} end
    local deps={
        restore_bone_array_snapshots=function() rec("restore_bones"); return true end,
        restore_feature_snapshot=function(k) rec("restore",k); return true end,
        apply_feature=function(k) rec("apply",k); return true end,
        set_native_aim_assist=function(v) rec("native",v); return true end,
        set_fire_assisted_aim_debug=function(v) rec("debug",v); return true end,
        delay=function(t,fn) queue[#queue+1]={t,fn}; return true end,
        init_current_weapon=function() rec("init_weapon"); return init_result end,
        refresh_aiming_runtime=function() rec("refresh_runtime"); return refresh_result end,
    }
    local function run_delay(expected)
        local item=table.remove(queue,1)
        truth(item,"missing queued delay "..tostring(expected))
        eq(item[1],expected,"delay order")
        item[2]()
    end
    local function count(name)
        local n=0
        for _,entry in ipairs(log) do if entry[1]==name then n=n+1 end end
        return n
    end
    return state,deps,queue,log,run_delay,count
end

-- P73 exclusivity and mode transitions.
do
    local state,deps=harness(false,true)
    eq(M.set_dongdong_feature_config(state,deps,"aim",true),true,"aim enable")
    eq(state.custom_dongdong_toggle_state.aim,true,"aim state")
    eq(state.custom_dongdong_toggle_state.anti_shake,false,"anti exclusive")
    eq(M.set_dongdong_feature_config(state,deps,"anti_shake",true),true,"anti enable")
    eq(state.custom_dongdong_toggle_state.aim,false,"aim exclusive")
    eq(state.custom_dongdong_toggle_state.anti_shake,true,"anti state")
    eq(M.set_dongdong_feature_config(state,deps,"anti_shake",false),true,"anti disable")
    eq(state.custom_dongdong_toggle_state.anti_shake,false,"anti off")
    eq(M.set_dongdong_feature_config(state,deps,"bogus",true),false,"unknown feature")
    eq(state.custom_dongdong_toggle_state.bogus,true,"bytecode stores unknown toggle before reject")
end

-- Exact P77 0.12 -> 0.04 -> 0.10 -> 0.38 sequence; init failure refreshes.
do
    local state,deps,queue,log,run_delay,count=harness(false,true)
    state.custom_dongdong_toggle_state.aim=true
    truth(M.set_dongdong_aim_part(state,deps),"p77 schedule")
    run_delay(0.12); run_delay(0.04); run_delay(0.1); run_delay(0.38)
    eq(count("init_weapon"),1,"init attempted")
    eq(count("refresh_runtime"),1,"refresh fallback")
    eq(state.custom_dongdong_bone_array_snapshots,nil,"bone snapshots reset")
    eq(state.custom_dongdong_bone_name_pool,nil,"bone pool reset")
    eq(state.custom_dongdong_bone_cache_revision,M.BUILD_REVISION,"bone revision")
end

-- Init success suppresses refresh.
do
    local state,deps,queue,log,run_delay,count=harness(true,true)
    state.custom_dongdong_toggle_state.aim=true
    M.set_dongdong_aim_part(state,deps)
    run_delay(0.12); run_delay(0.04); run_delay(0.1)
    eq(count("init_weapon"),1,"init success attempted")
    eq(count("refresh_runtime"),0,"no refresh after init success")
end

-- Refresh returning false is not an exception and does not cancel final reassert.
do
    local state,deps,queue,log,run_delay,count=harness(false,false)
    state.custom_dongdong_toggle_state.aim=true
    M.set_dongdong_aim_part(state,deps)
    run_delay(0.12); run_delay(0.04); run_delay(0.1); run_delay(0.38)
    eq(count("refresh_runtime"),1,"refresh attempted once")
    eq(state.custom_dongdong_toggle_state.aim,true,"final reassert survives refresh false")
end

-- Revision change before 0.12 invalidates the old outer callback.
do
    local state,deps,queue,log,run_delay,count=harness(false,true)
    state.custom_dongdong_toggle_state.aim=true
    M.set_dongdong_aim_part(state,deps)
    M.set_dongdong_aim_part(state,deps)
    run_delay(0.12) -- stale first callback
    eq(#log,0,"stale 0.12 callback has no effects")
end

-- Revision change before the 0.10 callback invalidates init/final scheduling.
do
    local state,deps,queue,log,run_delay,count=harness(false,true)
    state.custom_dongdong_toggle_state.aim=true
    M.set_dongdong_aim_part(state,deps)
    run_delay(0.12); run_delay(0.04)
    M.set_dongdong_aim_part(state,deps) -- revision changes while old 0.10 is queued
    run_delay(0.1)
    eq(count("init_weapon"),0,"stale 0.10 callback skips init")
    eq(count("refresh_runtime"),0,"stale 0.10 callback skips refresh")
end

-- Toggle switch after 0.04 is respected by the final callback; captured aim is not reasserted.
do
    local state,deps,queue,log,run_delay,count=harness(true,true)
    state.custom_dongdong_toggle_state.aim=true
    M.set_dongdong_aim_part(state,deps)
    run_delay(0.12); run_delay(0.04)
    state.custom_dongdong_toggle_state.aim=false
    state.custom_dongdong_toggle_state.anti_shake=true
    run_delay(0.1); run_delay(0.38)
    eq(state.custom_dongdong_toggle_state.aim,false,"captured aim not reasserted")
    eq(state.custom_dongdong_toggle_state.anti_shake,true,"new toggle preserved")
end

-- Feature disabled before final reassert stays disabled.
do
    local state,deps,queue,log,run_delay,count=harness(true,true)
    state.custom_dongdong_toggle_state.anti_shake=true
    M.set_dongdong_aim_part(state,deps)
    run_delay(0.12); run_delay(0.04); run_delay(0.1)
    state.custom_dongdong_toggle_state.anti_shake=false
    run_delay(0.38)
    eq(state.custom_dongdong_toggle_state.anti_shake,false,"disabled mode stays off")
end

-- There is intentionally no revision guard in the final 0.38 callback. Once it
-- has been scheduled, a later revision does not suppress its current-toggle check.
do
    local state,deps,queue,log,run_delay,count=harness(true,true)
    state.custom_dongdong_toggle_state.aim=true
    M.set_dongdong_aim_part(state,deps)
    run_delay(0.12); run_delay(0.04); run_delay(0.1)
    local native_before=count("native")
    M.set_dongdong_aim_part(state,deps) -- increments revision after final was scheduled
    run_delay(0.38)
    truth(count("native")>native_before,"final callback still reasserts current aim")
end

print("feature-control: ok")

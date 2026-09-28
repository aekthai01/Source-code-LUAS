local root=assert(arg[1])
local ROOT_ENV=_G
local S={}
assert(loadfile(root.."/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root.."/src/spectra/p029_runtime_helpers.lua"))(S)
assert(loadfile(root.."/src/spectra/aim_runtime.lua"))(S)
local ABI,H,M=S.AimABI,S.P029RuntimeHelpers,S.AimRuntime

local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function packed(fn,...) return table.pack(fn(...)) end
local function restore_global(name,value) rawset(_G,name,value) end
local ORIGINAL={
  Timer=rawget(_G,"Timer"), UKismetSystemLibrary=rawget(_G,"UKismetSystemLibrary"),
  GetGameInstance=rawget(_G,"GetGameInstance"), import=rawget(_G,"import"),
  GetWorld=rawget(_G,"GetWorld"),
}
local function reset_engine()
  _G.Timer=nil; _G.UKismetSystemLibrary=nil; _G.GetGameInstance=nil; _G.import=nil; _G.GetWorld=nil
end
local function timer_queue()
  local q={}
  _G.Timer={DelayCall=function(seconds,callback)
    q[#q+1]={seconds=seconds,callback=callback}
  end}
  return q
end
local function install_console(execute,get_game_instance)
  _G.UKismetSystemLibrary={ExecuteConsoleCommand=execute}
  _G.GetGameInstance=get_game_instance or function() return {} end
end
local function one_child_case(label,setup,expected,check)
  reset_engine()
  local q=timer_queue()
  setup()
  local result=packed(M.set_fire_assisted_aim_debug,true)
  eq(result.n,1,label.." return arity")
  eq(result[1],expected,label.." result")
  eq(#q,2,label.." schedules twice")
  eq(q[1].seconds,0.35,label.." first schedule")
  eq(q[2].seconds,1.2,label.." second schedule")
  if check then check(q) end
end

-- Exact P71/P71.0 source-owned parent/child behavior.
local function reset_p71()
  reset_engine()
  ROOT_ENV.custom_dongdong_native_aim_state=nil
end
local function install_p71_object(object, world_value)
  local class={Get=function(self,world) return object end}
  ROOT_ENV.import=function(name) eq(name,"ClientBaseSetting","P71 import name"); return class end
  ROOT_ENV.GetWorld=function() return world_value==nil and {} or world_value end
  return class
end
local function p71_result(enabled)
  if enabled==nil then return packed(M.set_native_aim_assist) end
  return packed(M.set_native_aim_assist,enabled)
end

reset_p71()
local missing=p71_result(true)
eq(missing.n,1,"P71 missing import arity"); eq(missing[1],false,"P71 missing import")

reset_p71(); local world_after_import_error=0
ROOT_ENV.import=function() error("import failed") end
ROOT_ENV.GetWorld=function() world_after_import_error=world_after_import_error+1; return {} end
local both_pcalls=p71_result(true)
eq(both_pcalls.n,1,"P71 pcall failure arity"); eq(both_pcalls[1],false,"P71 import failure")
eq(world_after_import_error,1,"P71 GetWorld still called after import exception")

reset_p71(); ROOT_ENV.import=function() return nil end; ROOT_ENV.GetWorld=function() return {} end
local nil_class=p71_result(true); eq(nil_class.n,1,"P71 nil class arity"); eq(nil_class[1],false,"P71 nil class")
reset_p71(); local false_world_seen=false
local false_world_cfg={bIsAimAssistOpen=false,SaveDataConfig=function() end}
ROOT_ENV.import=function()
  return {Get=function(self,world) eq(world,false,"P71 false world forwarded"); false_world_seen=true; return false_world_cfg end}
end
ROOT_ENV.GetWorld=function() return false end
local false_world=p71_result(true)
eq(false_world.n,1,"P71 false world arity"); eq(false_world[1],true,"P71 false world accepted")
truth(false_world_seen,"P71 nil-only world gate")

reset_p71(); local getter_attempts=0; local retry_world={}
local retry_cfg={bIsAimAssistOpen=false,SaveDataConfig=function() end}
local retry_class
retry_class={Get=function(...)
  getter_attempts=getter_attempts+1
  local a=table.pack(...)
  if a.n==2 and a[1]==retry_class then error("self form rejected") end
  eq(a.n,1,"P71 static fallback arg count"); eq(a[1],retry_world,"P71 static fallback world")
  return retry_cfg
end}
ROOT_ENV.import=function() return retry_class end; ROOT_ENV.GetWorld=function() return retry_world end
local retried=p71_result(true)
eq(retried.n,1,"P71 P12 retry arity"); eq(retried[1],true,"P71 P12 retry result")
eq(getter_attempts,2,"P71 P12 self then static")

reset_p71(); local save_calls=0
local cfg={bIsAimAssistOpen=false,SaveDataConfig=function(self) save_calls=save_calls+1 end}
install_p71_object(cfg,{})
local enabled1=p71_result(true); eq(enabled1.n,1,"P71 enable arity"); eq(enabled1[1],true,"P71 enable")
eq(cfg.bIsAimAssistOpen,true,"P71 enabled value")
local state=ROOT_ENV.custom_dongdong_native_aim_state
eq(state.saved,true,"P71 saved marker"); eq(state.value,false,"P71 saved original false")
local enabled2=p71_result(true); eq(enabled2.n,1,"P71 repeated enable arity"); eq(enabled2[1],true)
eq(state.value,false,"P71 repeated enable does not overwrite snapshot")
local disabled=p71_result(false); eq(disabled.n,1,"P71 disable arity"); eq(disabled[1],true,"P71 disable")
eq(cfg.bIsAimAssistOpen,false,"P71 restored value"); eq(state.saved,false,"P71 saved marker cleared")
eq(save_calls,3,"P71 SaveDataConfig each successful setter attempt")

reset_p71(); local strict_cfg={bIsAimAssistOpen=true,SaveDataConfig=function() end}; install_p71_object(strict_cfg,{})
local strict_enable=p71_result(true); eq(strict_enable[1],true); strict_cfg.bIsAimAssistOpen=false
local strict_disable=p71_result(0); eq(strict_disable.n,1,"P71 nontrue arity"); eq(strict_disable[1],true)
eq(strict_cfg.bIsAimAssistOpen,true,"P71 nontrue restores saved true"); eq(ROOT_ENV.custom_dongdong_native_aim_state.saved,false)

reset_p71(); local save_after_set_error=0
local throwing_obj=setmetatable({}, {
  __index=function(_,key)
    if key=="bIsAimAssistOpen" then return false end
    if key=="SaveDataConfig" then return function(self) save_after_set_error=save_after_set_error+1 end end
  end,
  __newindex=function(_,key,value)
    if key=="bIsAimAssistOpen" then error("setter failed") end
    rawset(_,key,value)
  end,
})
install_p71_object(throwing_obj,{})
local setter_fail=p71_result(true)
eq(setter_fail.n,1,"P71 setter failure arity"); eq(setter_fail[1],false,"P71 setter failure result")
eq(save_after_set_error,1,"P71 save still runs after setter failure")

reset_p71(); local save_error_calls=0
local save_error_cfg={bIsAimAssistOpen=false,SaveDataConfig=function(self)
  save_error_calls=save_error_calls+1; error("save failed")
end}
install_p71_object(save_error_cfg,{})
local save_error=p71_result(true)
eq(save_error.n,1,"P71 save error arity"); eq(save_error[1],true,"P71 return is setter pcall result")
eq(save_error_calls,1,"P71 save has no retry")

local old_get,old_optional=ABI.get,ABI.call_optional_self
local replacement_get,replacement_optional=0,0
ABI.get=function() replacement_get=replacement_get+1; error("replacement P2 observed") end
ABI.call_optional_self=function() replacement_optional=replacement_optional+1; error("replacement P12 observed") end
reset_p71(); local fixed_cfg={bIsAimAssistOpen=false,SaveDataConfig=function() end}; install_p71_object(fixed_cfg,{})
local fixed_helpers=p71_result(true)
ABI.get,ABI.call_optional_self=old_get,old_optional
eq(fixed_helpers.n,1,"P71 fixed helper arity"); eq(fixed_helpers[1],true,"P71 fixed helper result")
eq(replacement_get,0,"P71 fixed P2 capture"); eq(replacement_optional,0,"P71 fixed P12 capture")

-- P72 command selection is equality to literal true, never generic truthiness.
local command_cases={{true,1},{false,0},{nil,0},{0,0},{1,0},{"true",0}}
for _,case in ipairs(command_cases) do
  reset_engine(); local q=timer_queue(); local seen={}
  install_console(function(...)
    local a=table.pack(...); eq(a.n,3,"command static arity"); eq(a[3],nil,"command trailing nil")
    seen[#seen+1]=a[2]
  end)
  local result
  if case[1]==nil then result=packed(M.set_fire_assisted_aim_debug) else result=packed(M.set_fire_assisted_aim_debug,case[1]) end
  eq(result.n,1,"command result arity")
  eq(result[1],true,"command immediate success")
  eq(seen[1],"weapon.FireAssistedAimingDebugEnable "..case[2],"command selection")
  eq(#q,2,"command schedules")
end

-- Immediate false is still exactly one return and still schedules both callbacks.
reset_engine(); local q_false=timer_queue(); _G.GetGameInstance=function() return {} end
local immediate_false=packed(M.set_fire_assisted_aim_debug,true)
eq(immediate_false.n,1,"immediate false arity"); eq(immediate_false[1],false,"immediate false")
eq(#q_false,2,"false schedules twice"); eq(q_false[1].seconds,0.35); eq(q_false[2].seconds,1.2)
eq(q_false[1].callback,q_false[2].callback,"same callback identity")

-- Per-call command capture: callbacks from the first invocation retain command 1.
reset_engine(); local q_capture=timer_queue(); local commands={}
install_console(function(...)
  local a=table.pack(...); commands[#commands+1]=a[2]
end)
eq(M.set_fire_assisted_aim_debug(true),true,"first command call")
eq(M.set_fire_assisted_aim_debug(false),true,"second command call")
eq(#q_capture,4,"two calls queue four callbacks")
q_capture[1].callback(); q_capture[2].callback()
eq(commands[1],"weapon.FireAssistedAimingDebugEnable 1","first immediate command")
eq(commands[2],"weapon.FireAssistedAimingDebugEnable 0","second immediate command")
eq(commands[3],"weapon.FireAssistedAimingDebugEnable 1","first delayed capture")
eq(commands[4],"weapon.FireAssistedAimingDebugEnable 1","second delayed capture")

-- P72 captures fixed P8 identity when AimRuntime loads.
local old_delay=H.delay; local replacement_delay_calls=0
H.delay=function() replacement_delay_calls=replacement_delay_calls+1; error("replacement P8 observed") end
reset_engine(); local q_fixed_p8=timer_queue(); install_console(function() end)
local fixed_p8=packed(M.set_fire_assisted_aim_debug,true)
H.delay=old_delay
eq(fixed_p8.n,1,"fixed P8 result arity"); eq(fixed_p8[1],true,"fixed P8 result")
eq(replacement_delay_calls,0,"P72 fixed P8 capture"); eq(#q_fixed_p8,2,"captured P8 queues")

-- P72.0 captures fixed P2 identity when AimRuntime loads.
local old_get=ABI.get; local replacement_get_calls=0
ABI.get=function() replacement_get_calls=replacement_get_calls+1; error("replacement P2 observed") end
reset_engine(); local q_fixed_p2=timer_queue(); install_console(function() end)
local fixed_p2=packed(M.set_fire_assisted_aim_debug,true)
ABI.get=old_get
eq(fixed_p2.n,1,"fixed P2 result arity"); eq(fixed_p2[1],true,"fixed P2 result")
eq(replacement_get_calls,0,"P72.0 fixed P2 capture"); eq(#q_fixed_p2,2,"fixed P2 schedules")

-- Import / library matrix. Import fallback is nil-only: global false never imports.
one_child_case("library missing import missing",function() _G.GetGameInstance=function() return {} end end,false)
one_child_case("library missing import nonfunction",function() _G.import={}; _G.GetGameInstance=function() return {} end end,false)
one_child_case("import throws",function() _G.import=function() error("import") end; _G.GetGameInstance=function() return {} end end,false)
one_child_case("import returns nil",function() _G.import=function() return nil end; _G.GetGameInstance=function() return {} end end,false)
local import_false_calls=0
one_child_case("global library false",function()
  _G.UKismetSystemLibrary=false
  _G.import=function() import_false_calls=import_false_calls+1; return {ExecuteConsoleCommand=function() end} end
  _G.GetGameInstance=function() return {} end
end,false,function() eq(import_false_calls,0,"false library does not import") end)
local imported_calls=0
one_child_case("import succeeds",function()
  _G.import=function(name) imported_calls=imported_calls+1; eq(name,"UKismetSystemLibrary","import name"); return {ExecuteConsoleCommand=function() end} end
  _G.GetGameInstance=function() return {} end
end,true,function() eq(imported_calls,1,"import once") end)

-- GetGameInstance failure matrix, including literal false which must continue.
one_child_case("GetGameInstance missing",function() _G.UKismetSystemLibrary={} end,false)
one_child_case("GetGameInstance nonfunction",function() _G.UKismetSystemLibrary={}; _G.GetGameInstance={} end,false)
one_child_case("GetGameInstance throws",function() _G.UKismetSystemLibrary={}; _G.GetGameInstance=function() error("gi") end end,false)
one_child_case("GetGameInstance nil",function() _G.UKismetSystemLibrary={}; _G.GetGameInstance=function() return nil end end,false)
local false_gi_seen=false
one_child_case("GetGameInstance false continues",function()
  _G.UKismetSystemLibrary={ExecuteConsoleCommand=function(...)
    local a=table.pack(...); eq(a.n,3,"false GI static arity"); eq(a[1],false,"false GI forwarded"); false_gi_seen=true
  end}
  _G.GetGameInstance=function() return false end
end,true,function() truth(false_gi_seen,"false GI reached execute") end)

-- ExecuteConsoleCommand lookup inherits fixed P2 semantics.
one_child_case("execute missing",function() install_console(nil) end,false)
one_child_case("execute false",function() _G.UKismetSystemLibrary={ExecuteConsoleCommand=false}; _G.GetGameInstance=function() return {} end end,false)
one_child_case("execute lookup throws",function()
  _G.UKismetSystemLibrary=setmetatable({}, {__index=function() error("lookup") end})
  _G.GetGameInstance=function() return {} end
end,false)

-- Static-first call has exactly gi, command, nil. No self fallback after success.
local static_calls=0
one_child_case("static succeeds",function()
  install_console(function(...)
    static_calls=static_calls+1; local a=table.pack(...)
    eq(a.n,3,"static exact arg count"); eq(a[2],"weapon.FireAssistedAimingDebugEnable 1","static command"); eq(a[3],nil,"static trailing nil")
  end)
end,true,function() eq(static_calls,1,"static only once") end)

-- A static exception triggers exact self fallback: lib, gi, command, nil.
local static_n,fallback_n=0,0
one_child_case("static throws self succeeds",function()
  local lib; local gi={}
  lib={ExecuteConsoleCommand=function(...)
    local a=table.pack(...)
    if a[1]==lib then
      fallback_n=fallback_n+1; eq(a.n,4,"fallback exact arg count"); eq(a[2],gi,"fallback gi"); eq(a[3],"weapon.FireAssistedAimingDebugEnable 1","fallback command"); eq(a[4],nil,"fallback trailing nil"); return
    end
    static_n=static_n+1; eq(a.n,3,"throwing static arg count"); eq(a[1],gi,"static gi"); eq(a[3],nil,"throwing static trailing nil"); error("static")
  end}
  _G.UKismetSystemLibrary=lib; _G.GetGameInstance=function() return gi end
end,true,function() eq(static_n,1,"static attempted first"); eq(fallback_n,1,"fallback attempted once") end)

local both_static,both_fallback=0,0
one_child_case("both execute attempts throw",function()
  local lib
  lib={ExecuteConsoleCommand=function(...)
    local a=table.pack(...)
    if a[1]==lib then both_fallback=both_fallback+1; eq(a.n,4,"failing fallback arg count")
    else both_static=both_static+1; eq(a.n,3,"failing static arg count") end
    error("execute")
  end}
  _G.UKismetSystemLibrary=lib; _G.GetGameInstance=function() return {} end
end,false,function() eq(both_static,1); eq(both_fallback,1) end)

-- Integration with the actual captured P8: missing Timer executes both delayed callbacks synchronously.
reset_engine(); local gi_calls=0
_G.UKismetSystemLibrary={ExecuteConsoleCommand=function() end}
_G.GetGameInstance=function()
  gi_calls=gi_calls+1
  if gi_calls==1 then return {} end
  return nil
end
local no_timer=packed(M.set_fire_assisted_aim_debug,true)
eq(no_timer.n,1,"P8 immediate fallback parent arity"); eq(no_timer[1],true,"parent keeps first immediate result")
eq(gi_calls,3,"missing Timer makes three synchronous child executions")

-- Actual P8 static success queues exactly two callbacks; only first child is synchronous.
reset_engine(); local q_real=timer_queue(); local real_gi_calls=0
_G.UKismetSystemLibrary={ExecuteConsoleCommand=function() end}
_G.GetGameInstance=function() real_gi_calls=real_gi_calls+1; return {} end
local timer_success=packed(M.set_fire_assisted_aim_debug,true)
eq(timer_success.n,1,"Timer success parent arity"); eq(timer_success[1],true,"Timer success immediate")
eq(real_gi_calls,1,"Timer success only first child synchronous")
eq(#q_real,2,"Timer success queues two callbacks")
eq(q_real[1].seconds,0.35); eq(q_real[2].seconds,1.2); eq(q_real[1].callback,q_real[2].callback,"Timer queue same callback")

for name,value in pairs(ORIGINAL) do restore_global(name,value) end
print("aim-runtime: ok")

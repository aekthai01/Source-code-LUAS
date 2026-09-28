local root=assert(arg[1])
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
  _G.Timer=nil; _G.UKismetSystemLibrary=nil; _G.GetGameInstance=nil; _G.import=nil
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

-- Exact P71/P71.0 source-owned behavior.
local ORIGINAL_NATIVE_AIM_STATE=rawget(_G,"custom_dongdong_native_aim_state")
local function reset_p71() rawset(_G,"custom_dongdong_native_aim_state",nil); rawset(_G,"import",nil); rawset(_G,"GetWorld",nil) end
local function install_p71(cfg,world)
  local cls={}; cls.Get=function(self,w) eq(self,cls,"P71 Get self"); eq(w,world,"P71 Get world"); return cfg end
  _G.import=function(name) eq(name,"ClientBaseSetting","P71 import"); return cls end; _G.GetWorld=function() return world end
end
reset_p71(); local r=packed(M.set_native_aim_assist,true); eq(r.n,1,"P71 early arity"); eq(r[1],false,"P71 early false"); truth(type(rawget(_G,"custom_dongdong_native_aim_state"))=="table","P71 early state")
reset_p71(); local order={}; _G.import=function() order[#order+1]="import"; error("x") end; _G.GetWorld=function() order[#order+1]="world"; return {} end
r=packed(M.set_native_aim_assist,true); eq(r.n,1,"P71 pcall arity"); eq(r[1],false); eq(order[1],"import"); eq(order[2],"world","P71 both pcalls")
reset_p71(); local cfg_false={bIsAimAssistOpen=false,SaveDataConfig=function() end}; install_p71(cfg_false,false); r=packed(M.set_native_aim_assist,true); eq(r.n,1); eq(r[1],true,"P71 false world accepted")
reset_p71(); local saves=0; local cfg={bIsAimAssistOpen=false}; cfg.SaveDataConfig=function(self) eq(self,cfg,"P71 save self"); saves=saves+1 end; install_p71(cfg,{})
local a1=packed(M.set_native_aim_assist,true); local st=rawget(_G,"custom_dongdong_native_aim_state"); eq(a1.n,1); eq(a1[1],true); eq(st.saved,true); eq(st.value,false); eq(cfg.bIsAimAssistOpen,true)
local a2=packed(M.set_native_aim_assist,true); eq(a2.n,1); eq(a2[1],true); eq(st.value,false,"P71 snapshot stable")
local a3=packed(M.set_native_aim_assist,false); eq(a3.n,1); eq(a3[1],true); eq(cfg.bIsAimAssistOpen,false,"P71 restore"); eq(st.saved,false); eq(saves,3)
reset_p71(); local save_after_throw=0; local bad=setmetatable({SaveDataConfig=function() save_after_throw=save_after_throw+1 end},{__index=function(_,k) if k=="bIsAimAssistOpen" then return false end end,__newindex=function(_,k) if k=="bIsAimAssistOpen" then error("set") end end}); install_p71(bad,{})
r=packed(M.set_native_aim_assist,true); eq(r.n,1); eq(r[1],false,"P71 setter pcall result"); eq(save_after_throw,1,"P71 save after setter failure")
reset_p71(); local save_fail=0; local sf={bIsAimAssistOpen=false}; sf.SaveDataConfig=function(...) save_fail=save_fail+1; local a=table.pack(...); eq(a.n,1,"P71 save arity"); eq(a[1],sf); error("save") end; install_p71(sf,{})
r=packed(M.set_native_aim_assist,true); eq(r.n,1); eq(r[1],true,"P71 ignores save error"); eq(save_fail,1,"P71 no save retry")
local old2,old12=ABI.get,ABI.call_optional_self; local repl2,repl12=0,0; ABI.get=function() repl2=repl2+1; error("P2") end; ABI.call_optional_self=function() repl12=repl12+1; error("P12") end
reset_p71(); local fixed={bIsAimAssistOpen=false,SaveDataConfig=function() end}; install_p71(fixed,{}); r=packed(M.set_native_aim_assist,true); ABI.get=old2; ABI.call_optional_self=old12; eq(r.n,1); eq(r[1],true); eq(repl2,0,"P71 fixed P2"); eq(repl12,0,"P71 fixed P12")
reset_p71(); local original_global=_G; local fake={}; local captured={bIsAimAssistOpen=false,SaveDataConfig=function() end}; local cls={Get=function() return captured end}; fake.import=function() return cls end; fake.GetWorld=function() return {} end; original_global._G=fake; r=packed(M.set_native_aim_assist,true); original_global._G=original_global; eq(r.n,1); eq(r[1],true,"P71 captured state result"); truth(type(rawget(original_global,"custom_dongdong_native_aim_state"))=="table","P71 fixed state table"); eq(rawget(fake,"custom_dongdong_native_aim_state"),nil,"P71 ignores replacement state table")
rawset(_G,"custom_dongdong_native_aim_state",ORIGINAL_NATIVE_AIM_STATE)

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

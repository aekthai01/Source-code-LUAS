local root=assert(arg[1]); local S={}; assert(loadfile(root.."/src/spectra/aim_runtime.lua"))(S); local M=S.AimRuntime
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local cfg={bIsAimAssistOpen=false, SaveDataConfig=function(self) self.saved_calls=(self.saved_calls or 0)+1 end}
import=function(name) if name=="ClientBaseSetting" then return {Get=function(self,world) return cfg end} elseif name=="UKismetSystemLibrary" then return UKismetSystemLibrary end end
GetWorld=function() return {} end
local state={}; eq(M.set_native_aim_assist(state,true),true); eq(cfg.bIsAimAssistOpen,true); eq(state.custom_dongdong_native_aim_state.value,false)
eq(M.set_native_aim_assist(state,false),true); eq(cfg.bIsAimAssistOpen,false); eq(state.custom_dongdong_native_aim_state.saved,false)
local cmds={}; GetGameInstance=function() return {} end; UKismetSystemLibrary={ExecuteConsoleCommand=function(gi,cmd) cmds[#cmds+1]=cmd end}
local q={}; local function delay(t,fn) q[#q+1]={t,fn} end
eq(M.set_fire_assisted_aim_debug(delay,true),true); eq(cmds[1],"weapon.FireAssistedAimingDebugEnable 1"); eq(q[1][1],0.35); eq(q[2][1],1.2); q[1][2](); q[2][2](); eq(#cmds,3)
print("aim-runtime: ok")

local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_refresh.lua"))(S)
local M = S.AimRefresh
local function eq(a,b,label) if a~=b then error((label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b),2) end end
local refreshed = 0
local component = {RefreshAimAssistorConfig=function(self) refreshed=refreshed+1 end}
local weapon = {WeaponDataComponentAiming=component, GetWeaponAimingComponent=function(self) return component end}
local manager = {}
local character = {Blackboard={WeaponManager=manager}, GetRealWeapon=function(self) return weapon end}
_G.Facade = {GameFlowManager={GetCharacter=function(self) return character end}}
local list=M.collect_targets()
eq(#list,5,"deduplicated character, blackboard, manager, weapon, component")
eq(M.refresh_methods(),true,"method refresh success")
eq(refreshed,1,"refresh invoked once")
local order={}
package.preload["DFM.Business.Module.RangeModule.Logic.RangeEquipLogic"] = function()
    return {
        GetCurrentPlayerWeaponItem=function(flag) eq(flag,true,"item flag"); return {InSlot={SlotType=7}} end,
        InitWeapon=function(slot) eq(slot,7,"slot type"); order[#order+1]="weapon" end,
        InitAmmos=function(flag) eq(flag,false,"ammo flag"); order[#order+1]="ammo" end,
    }
end
local scheduled={}
eq(M.init_current_weapon(function(seconds,callback) scheduled[#scheduled+1]={seconds,callback} end),true,"weapon init")
eq(order[1],"weapon","synchronous init")
eq(scheduled[1][1],0.28,"ammo delay")
scheduled[1][2]()
eq(order[2],"ammo","delayed ammo init")
_G.Facade=nil
package.loaded["DFM.Business.Module.RangeModule.Logic.RangeEquipLogic"]=nil
package.preload["DFM.Business.Module.RangeModule.Logic.RangeEquipLogic"]=nil
print("aim-refresh: ok")

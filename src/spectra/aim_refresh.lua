local S = ...
assert(type(S) == "table")
local M = {}
S.AimRefresh = M
M.PROTOTYPES = { collect_targets = "0.29.74", refresh_methods = "0.29.75",
    init_current_weapon = "0.29.76" }
-- Descriptive source names; method strings and order are from the payload.
local ABI = assert(S.AimABI, "P0.29.2/3/4/12 ABI helpers required")
local safe_get = ABI.get
local function invoke(owner, key, self_first, ...)
    if self_first then return ABI.self_first(owner, key, ...) end
    return ABI.static_first(owner, key, ...)
end

function M.collect_targets()
    local objects, seen = {}, {}
    local function add(obj)
        if obj == nil or (type(obj) ~= "table" and type(obj) ~= "userdata") or seen[obj] then return end
        seen[obj] = true
        objects[#objects + 1] = obj
    end
    local flow = safe_get(rawget(_G, "Facade"), "GameFlowManager")
    local _, character = invoke(flow, "GetCharacter", true)
    if character == nil then
        local ok, controller = invoke(rawget(_G, "InGameController"), "Get", false)
        if ok and controller ~= nil then
            local has_character, fallback = invoke(controller, "GetGPCharacter", true)
            if has_character then character = fallback end
        end
    end
    add(character)
    local blackboard = safe_get(character, "Blackboard")
    add(blackboard)
    local manager = safe_get(blackboard, "WeaponManager")
    if manager == nil and character ~= nil then
        local ue = rawget(_G, "UE")
        local helper = safe_get(ue, "GameplayBlueprintHelper")
        local cls = safe_get(ue, "WeaponManagerComponent")
        local finder = safe_get(helper, "FindComponentByClass")
        local ok, found = false, nil
        if type(finder) == "function" then
            ok, found = ABI.call_optional_self(finder, helper, character, cls)
        end
        if ok then manager = found end
    end
    add(manager)
    local ok_weapon, weapon = invoke(character, "GetRealWeapon", true)
    if not ok_weapon or weapon == nil then
        local ok_manager, candidate = invoke(manager, "BP_GetCurrentWeapon", true)
        if ok_manager then weapon = candidate end
    end
    add(weapon)
    if weapon ~= nil then
        for _, key in ipairs({"WeaponDataComponentAiming", "WeaponDataComponentProxy",
            "WeaponAimingComponent", "AimingComponent", "AimAssistorComponent",
            "WeaponAimAssistorComponent", "WeaponViewComponent", "ViewComponent"}) do
            add(safe_get(weapon, key))
        end
        for _, key in ipairs({"GetWeaponDataComponentAiming", "GetWeaponDataComponentProxy",
            "GetWeaponAimingComponent", "GetAimingComponent", "GetAimAssistorComponent",
            "GetWeaponAimAssistorComponent"}) do
            local success, value = invoke(weapon, key, true)
            if success then add(value) end
        end
    end
    return objects
end

local REFRESH_METHODS = {
    "RefreshAimAssistorConfig", "ReloadAimAssistorConfig", "RebuildAimAssistorConfig",
    "RefreshAimingConfig", "ReloadAimingConfig", "RebuildAimingConfig",
    "RefreshAimingData", "ReloadAimingData", "RebuildAimingData",
    "UpdateAimingData", "ApplyAimingData", "OnAimingDataChanged",
    "RefreshWeaponData", "ReloadWeaponData", "RebuildWeaponData",
    "UpdateWeaponData", "ApplyWeaponData", "OnWeaponDataChanged",
}

function M.refresh_methods()
    local called = false
    for _, obj in ipairs(M.collect_targets()) do
        for _, name in ipairs(REFRESH_METHODS) do
            if type(safe_get(obj, name)) == "function" and select(1, invoke(obj, name, true)) then
                called = true
            end
        end
    end
    return called
end

function M.init_current_weapon(delay)
    assert(type(delay) == "function", "delay function required")
    local ok_require, logic = pcall(require, "DFM.Business.Module.RangeModule.Logic.RangeEquipLogic")
    if not ok_require or type(logic) ~= "table" then return false end
    local ok_item, item = invoke(logic, "GetCurrentPlayerWeaponItem", false, true)
    if not ok_item or item == nil then return false end
    local slot = safe_get(safe_get(item, "InSlot"), "SlotType")
    if slot == nil then return false end
    if not select(1, invoke(logic, "InitWeapon", false, slot)) then return false end
    delay(0.28, function() invoke(logic, "InitAmmos", false, false) end)
    return true
end

return M

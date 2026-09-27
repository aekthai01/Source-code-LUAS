local S = ...
assert(type(S) == "table", "spectra module table required")
local M = {}
S.AimRuntime = M
M.PROTOTYPES = { native_aim_state = "0.29.71", fire_assisted_debug = "0.29.72" }

local function safe_get(obj, key)
    if obj == nil then return nil end
    local ok, v = pcall(function() return obj[key] end)
    if ok then return v end
end

local function invoke(fn, self, ...)
    if type(fn) ~= "function" then return false, nil end
    local ok, a = pcall(fn, self, ...)
    if ok then return true, a end
    return pcall(fn, ...)
end

local function method(obj, name, ...)
    local fn = safe_get(obj, name)
    return invoke(fn, obj, ...)
end

function M.set_native_aim_assist(state, enabled)
    local saved = state.custom_dongdong_native_aim_state
    if type(saved) ~= "table" then saved = {}; state.custom_dongdong_native_aim_state = saved end
    local import_fn = rawget(_G, "import")
    local get_world = rawget(_G, "GetWorld")
    if type(import_fn) ~= "function" or type(get_world) ~= "function" then return false end
    local ok_class, cls = pcall(import_fn, "ClientBaseSetting")
    local ok_world, world = pcall(get_world)
    if not ok_class or not ok_world or cls == nil or world == nil then return false end
    local getter = safe_get(cls, "Get")
    local ok_get, obj = invoke(getter, cls, world)
    if not ok_get or obj == nil then return false end
    if saved.saved ~= true then
        saved.saved = true
        saved.value = safe_get(obj, "bIsAimAssistOpen") == true
    end
    local desired = enabled == true and true or (saved.value == true)
    local ok_set = pcall(function() obj.bIsAimAssistOpen = desired end)
    local saver = safe_get(obj, "SaveDataConfig")
    if type(saver) == "function" then pcall(saver, obj) end
    if enabled ~= true then saved.saved = false end
    return ok_set
end

local function execute_console(command)
    local lib = rawget(_G, "UKismetSystemLibrary")
    local get_instance = rawget(_G, "GetGameInstance")
    if lib == nil then
        local import_fn = rawget(_G, "import")
        if type(import_fn) == "function" then
            local ok, v = pcall(import_fn, "UKismetSystemLibrary")
            if ok then lib = v end
        end
    end
    if lib == nil or type(get_instance) ~= "function" then return false end
    local ok_gi, gi = pcall(get_instance)
    if not ok_gi or gi == nil then return false end
    local fn = safe_get(lib, "ExecuteConsoleCommand")
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, gi, command, nil)
    if not ok then ok = pcall(fn, lib, gi, command, nil) end
    return ok
end

function M.set_fire_assisted_aim_debug(delay, enabled)
    assert(type(delay) == "function", "delay function required")
    local command = enabled == true and "weapon.FireAssistedAimingDebugEnable 1" or "weapon.FireAssistedAimingDebugEnable 0"
    local function apply() return execute_console(command) end
    local immediate = apply()
    delay(0.35, apply)
    delay(1.2, apply)
    return immediate
end

return M

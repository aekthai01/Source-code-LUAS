local S = ...
assert(type(S) == "table", "spectra module table required")
local ABI = assert(S.AimABI, "AimABI required")
local RuntimeHelpers = assert(S.P029RuntimeHelpers, "P0.29 runtime helpers required")
local M = {}
S.AimRuntime = M
M.PROTOTYPES = {
    native_aim_state = "0.29.71",
    native_aim_state_apply = "0.29.71.0",
    fire_assisted_debug = "0.29.72",
    fire_assisted_debug_apply = "0.29.72.0",
}

-- P0.29.71 captures the P0.29 parent R0 state table plus exact P0.29.2 and
-- P0.29.12 sibling helpers once when this source module is constructed.
local native_aim_state_029_71 = _G
local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")
local call_optional_self_029_12 = assert(ABI.call_optional_self, "P0.29.12 required")

-- P0.29.72 additionally captures exact P0.29.8 once.
local delay_029_8 = assert(RuntimeHelpers.delay, "P0.29.8 required")

function M.set_native_aim_assist(enabled)
    local state = native_aim_state_029_71
    local saved = state.custom_dongdong_native_aim_state
    if type(saved) ~= "table" then
        saved = {}
        state.custom_dongdong_native_aim_state = saved
    end

    local import_fn = rawget(_G, "import")
    local get_world = rawget(_G, "GetWorld")
    if type(import_fn) ~= "function" or type(get_world) ~= "function" then
        return false
    end

    local ok_class, cls = pcall(import_fn, "ClientBaseSetting")
    local ok_world, world = pcall(get_world)
    if not ok_class or not ok_world or cls == nil or world == nil then
        return false
    end

    local getter = safe_get_029_2(cls, "Get")
    local ok_get, obj = call_optional_self_029_12(getter, cls, world)
    if not ok_get or obj == nil then
        return false
    end

    if saved.saved ~= true then
        saved.saved = true
        saved.value = safe_get_029_2(obj, "bIsAimAssistOpen") == true
    end

    local desired
    if enabled == true then
        desired = true
    else
        desired = saved.value == true
    end

    local ok_set = pcall(function()
        obj.bIsAimAssistOpen = desired
    end)

    local saver = safe_get_029_2(obj, "SaveDataConfig")
    if type(saver) == "function" then
        pcall(saver, obj)
    end

    if enabled ~= true then
        saved.saved = false
    end
    return ok_set
end

-- P0.29.72.0. The closure is recreated by set_fire_assisted_aim_debug for each
-- parent invocation and captures only the command plus fixed P0.29.2 identity.
local function execute_console(command)
    local lib = rawget(_G, "UKismetSystemLibrary")
    local get_game_instance = rawget(_G, "GetGameInstance")

    if lib == nil then
        local import_fn = rawget(_G, "import")
        if type(import_fn) == "function" then
            local ok, imported = pcall(import_fn, "UKismetSystemLibrary")
            if ok then
                lib = imported
            end
        end
    end

    if lib == nil or type(get_game_instance) ~= "function" then
        return false
    end

    local ok_gi, game_instance = pcall(get_game_instance)
    if not ok_gi or game_instance == nil then
        return false
    end

    local execute = safe_get_029_2(lib, "ExecuteConsoleCommand")
    if type(execute) ~= "function" then
        return false
    end

    local ok = pcall(execute, game_instance, command, nil)
    if ok then
        return true
    end

    local fallback_ok = pcall(execute, lib, game_instance, command, nil)
    return fallback_ok
end

-- P0.29.72. Only literal boolean true selects the enabled command. The exact
-- same child closure is called immediately and scheduled through captured P8.
function M.set_fire_assisted_aim_debug(enabled)
    local command
    if enabled == true then
        command = "weapon.FireAssistedAimingDebugEnable 1"
    else
        command = "weapon.FireAssistedAimingDebugEnable 0"
    end

    local function apply()
        return execute_console(command)
    end

    local immediate = apply()
    delay_029_8(0.35, apply)
    delay_029_8(1.2, apply)
    return immediate
end

return M

local S = ...
assert(type(S) == "table", "spectra module table required")
local ABI = assert(S.AimABI, "AimABI required")
local M = {}
S.P029RuntimeHelpers = M

-- Reconstructed semantic names for stripped payload P0.29 helpers.
M.PROTOTYPES = {
    is_function_field = "0.29.5",
    object_name = "0.29.6",
    delay = "0.29.8",
    get_table_manager = "0.29.11",
    get_data_table = "0.29.13",
}

local safe_get = ABI.get

function M.is_function_field(owner, key)
    return type(safe_get(owner, key)) == "function"
end

function M.object_name(object)
    if object == nil then
        return ""
    end
    for _, method_name in ipairs({"GetFullName", "GetName"}) do
        local ok, value = ABI.self_first(object, method_name)
        if ok and value ~= nil then
            return tostring(value)
        end
    end
    return tostring(object)
end

function M.delay(seconds, callback)
    local timer = rawget(_G, "Timer")
    local delay_call = safe_get(timer, "DelayCall")
    if type(delay_call) ~= "function" then
        callback()
        return
    end

    local ok = pcall(delay_call, seconds, callback)
    if ok then
        return
    end

    pcall(delay_call, timer, seconds, callback)
    return
end

function M.get_table_manager()
    local facade = rawget(_G, "Facade")
    local manager = safe_get(facade, "TableManager")
    if manager then
        return manager
    end
    return rawget(_G, "TableManager")
end

function M.get_data_table(table_name)
    local manager = M.get_table_manager()
    local fn = safe_get(manager, "GetTable")
    local ok, value = ABI.call_optional_self(fn, manager, table_name)
    if ok then
        return value
    end
    return nil
end

return M

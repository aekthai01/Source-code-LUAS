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

-- P0.29 captures sibling helpers once when the parent closure is constructed.
-- Freeze those identities here rather than re-reading mutable export tables.
local safe_get = assert(ABI.get, "P0.29.2 required")
local self_first = assert(ABI.self_first, "P0.29.3 required")
local call_optional_self = assert(ABI.call_optional_self, "P0.29.12 required")

function M.is_function_field(owner, key)
    return type(safe_get(owner, key)) == "function"
end

function M.object_name(object)
    if object == nil then
        return ""
    end
    for _, method_name in ipairs({"GetFullName", "GetName"}) do
        local ok, value = self_first(object, method_name)
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

local function get_table_manager_impl()
    local facade = rawget(_G, "Facade")
    local manager = safe_get(facade, "TableManager")
    if manager then
        return manager
    end
    return rawget(_G, "TableManager")
end

local function get_data_table_impl(table_name)
    local manager = get_table_manager_impl()
    local fn = safe_get(manager, "GetTable")
    local ok, value = call_optional_self(fn, manager, table_name)
    if ok then
        return value
    end
    return nil
end

M.get_table_manager = get_table_manager_impl
M.get_data_table = get_data_table_impl

return M

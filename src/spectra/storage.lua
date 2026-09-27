local S = ...
assert(type(S) == "table", "spectra module table required")

local Runtime = assert(S.Runtime, "Runtime module required")
local M = {}
S.Storage = M

M.KEY = "SPECTRA_WY_71438_CARD"

local function get_manager()
    local facade = rawget(_G, "Facade")
    return Runtime.safe_get(facade, "ConfigManager")
end

function M.get_string(key)
    local manager = get_manager()
    local fn = Runtime.safe_get(manager, "GetUserString")
    if type(fn) ~= "function" then
        return ""
    end
    local ok, value = pcall(fn, manager, key)
    if not ok or value == nil then
        return ""
    end
    return Runtime.trim(value)
end

function M.set_string(key, value)
    local manager = get_manager()
    local fn = Runtime.safe_get(manager, "SetUserString")
    if type(fn) ~= "function" then
        return false
    end
    return pcall(fn, manager, key, tostring(value or ""))
end

function M.get_card()
    return Runtime.normalize_card(M.get_string(M.KEY))
end

function M.set_card(card)
    return M.set_string(M.KEY, Runtime.normalize_card(card))
end

function M.clear_card()
    return M.set_string(M.KEY, "")
end

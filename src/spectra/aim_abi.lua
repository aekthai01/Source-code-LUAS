local S = ...
assert(type(S) == "table")
local M = {}
S.AimABI = M
-- Reconstructed descriptive names for payload P0.29.2/3/4/12.
function M.get(owner, key)
    if owner == nil then return nil end
    local ok, value = pcall(function() return owner[key] end)
    return ok and value or nil
end
function M.self_first(owner, key, ...)
    local fn = M.get(owner, key)
    if type(fn) ~= "function" then return false, nil end
    local ok, a, b = pcall(fn, owner, ...)
    if ok then return true, a, b end
    ok, a, b = pcall(fn, ...)
    if ok then return true, a, b end
    return false, nil
end
function M.static_first(owner, key, ...)
    local fn = M.get(owner, key)
    if type(fn) ~= "function" then return false, nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return true, a, b end
    ok, a, b = pcall(fn, owner, ...)
    if ok then return true, a, b end
    return false, nil
end
function M.call_optional_self(fn, owner, ...)
    if type(fn) ~= "function" then return false, nil end
    local ok, value = pcall(fn, owner, ...)
    if ok then return true, value end
    return pcall(fn, ...)
end
return M

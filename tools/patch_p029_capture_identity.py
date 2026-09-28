#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

runtime = ROOT / "src/spectra/p029_runtime_helpers.lua"
runtime.write_text('''local S = ...
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
''', encoding='utf-8')

test = ROOT / "tests/p029_runtime_helpers.lua"
s = test.read_text(encoding='utf-8')
anchor = '''local function packed(fn, ...)
    return table.pack(fn(...))
end
'''
insert = anchor + '''local function with_replaced(owner, key, replacement, fn)
    local previous = owner[key]
    owner[key] = replacement
    local outcome = table.pack(pcall(fn))
    owner[key] = previous
    if not outcome[1] then error(outcome[2], 0) end
    return table.unpack(outcome, 2, outcome.n)
end
'''
assert s.count(anchor) == 1
s = s.replace(anchor, insert, 1)
anchor2 = '''-- Active MutationRuntime integration uses the canonical ABI and runtime helpers.
'''
capture_tests = '''-- Fixed sibling-helper capture identity: replacements after module load are not observed internally.
with_replaced(ABI, "self_first", function()
    error("replacement self_first must not be observed")
end, function()
    local captured = packed(H.object_name, {GetFullName = function() return "captured-p3" end})
    eq(captured.n, 1, "P6 fixed P3 capture arity")
    eq(captured[1], "captured-p3", "P6 fixed P3 capture")
end)

local original_p11 = H.get_table_manager
with_replaced(H, "get_table_manager", function()
    error("replacement P11 must not be observed by P13")
end, function()
    local manager13 = {GetTable = function(self, name) return "p11:" .. name end}
    _G.Facade = nil
    _G.TableManager = manager13
    local captured = packed(H.get_data_table, "Captured")
    eq(captured.n, 1, "P13 fixed P11 capture arity")
    eq(captured[1], "p11:Captured", "P13 fixed P11 capture")
    local ok_external = pcall(H.get_table_manager)
    eq(ok_external, false, "export replacement remains externally visible")
end)
eq(H.get_table_manager, original_p11, "P11 export restored")

with_replaced(ABI, "call_optional_self", function()
    error("replacement P12 must not be observed by P13")
end, function()
    local manager13 = {GetTable = function(self, name) return "p12:" .. name end}
    _G.Facade = nil
    _G.TableManager = manager13
    local captured = packed(H.get_data_table, "Captured")
    eq(captured.n, 1, "P13 fixed P12 capture arity")
    eq(captured[1], "p12:Captured", "P13 fixed P12 capture")
end)

with_replaced(ABI, "get", function()
    error("replacement P2 must not be observed by P13")
end, function()
    local manager13 = {GetTable = function(self, name) return "p2:" .. name end}
    _G.Facade = nil
    _G.TableManager = manager13
    local captured = packed(H.get_data_table, "Captured")
    eq(captured.n, 1, "P13 fixed P2 capture arity")
    eq(captured[1], "p2:Captured", "P13 fixed P2 capture")
end)

''' + anchor2
assert s.count(anchor2) == 1
s = s.replace(anchor2, capture_tests, 1)
test.write_text(s, encoding='utf-8')

validator = ROOT / "tools/validate_phase_d.py"
s = validator.read_text(encoding='utf-8')
old = '''    assert 'local ABI = assert(S.AimABI, "AimABI required")' in runtime_source
    assert 'local function safe_get' not in mutation_source
'''
new = '''    assert 'local ABI = assert(S.AimABI, "AimABI required")' in runtime_source
    assert 'local safe_get = assert(ABI.get, "P0.29.2 required")' in runtime_source
    assert 'local self_first = assert(ABI.self_first, "P0.29.3 required")' in runtime_source
    assert 'local call_optional_self = assert(ABI.call_optional_self, "P0.29.12 required")' in runtime_source
    assert 'local manager = get_table_manager_impl()' in runtime_source
    assert 'M.get_table_manager = get_table_manager_impl' in runtime_source
    assert 'M.get_data_table = get_data_table_impl' in runtime_source
    assert 'ABI.self_first(' not in runtime_source
    assert 'M.get_table_manager(' not in runtime_source
    assert 'ABI.call_optional_self(' not in runtime_source
    assert '0.29.72' in groups['payload_owned'] and '0.29.72.0' in groups['payload_owned']
    assert 'local function safe_get' not in mutation_source
'''
assert s.count(old) == 1
s = s.replace(old, new, 1)
s = s.replace("'phase':'E5.9-p029-runtime-helpers-source-only'", "'phase':'E5.9a-p029-capture-identity-fidelity'", 1)
s = s.replace("'mutation_runtime_abi_integration':'passed'", "'mutation_runtime_abi_integration':'passed','p029_capture_identity':'passed'", 1)
validator.write_text(s, encoding='utf-8')

print('patched P0.29 capture identity gate')

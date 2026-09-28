local root = assert(arg[1], "root path required")
local S = {}
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root .. "/src/spectra/p029_runtime_helpers.lua"))(S)
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
local ABI = assert(S.AimABI)
local H = assert(S.P029RuntimeHelpers)
local Mutation = assert(S.MutationRuntime)

local function eq(a, b, message)
    if a ~= b then
        error((message or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end
local function packed(fn, ...)
    return table.pack(fn(...))
end

local old = {
    Facade = rawget(_G, "Facade"),
    TableManager = rawget(_G, "TableManager"),
    Timer = rawget(_G, "Timer"),
    tostring = tostring,
}

-- P0.29.5: exactly one boolean and strict type(value)=="function" semantics.
local callable_table = setmetatable({}, {__call = function() end})
local throwing_owner = setmetatable({}, {__index = function() error("lookup failed") end})
for index, case in ipairs({
    {nil, "x", false},
    {{}, "x", false},
    {{x = false}, "x", false},
    {{x = 7}, "x", false},
    {{x = callable_table}, "x", false},
    {{x = function() end}, "x", true},
    {throwing_owner, "x", false},
}) do
    local result = packed(H.is_function_field, case[1], case[2])
    eq(result.n, 1, "P5 arity " .. index)
    eq(result[1], case[3], "P5 result " .. index)
end

-- P0.29.6: GetFullName then GetName via self-first ABI, with tostring tail returns.
local result = packed(H.object_name, nil)
eq(result.n, 1, "P6 nil arity")
eq(result[1], "", "P6 nil result")
result = packed(H.object_name, {
    GetFullName = function() return "full" end,
    GetName = function() return "name" end,
})
eq(result[1], "full", "P6 GetFullName wins")
result = packed(H.object_name, {
    GetFullName = function() return nil end,
    GetName = function() return "name" end,
})
eq(result[1], "name", "P6 nil continues")
local attempts = 0
local named = {}
named.GetFullName = function(first)
    attempts = attempts + 1
    if first == named then error("self-first failure") end
    return "static-name"
end
result = packed(H.object_name, named)
eq(result[1], "static-name", "P6 static retry")
eq(attempts, 2, "P6 retry count")
result = packed(H.object_name, {GetFullName = function() return false end})
eq(result[1], "false", "P6 false is non-nil")
local original_tostring = tostring
_G.tostring = function() return "tail", "extra" end
result = packed(H.object_name, {})
_G.tostring = original_tostring
eq(result.n, 2, "P6 tostring tail arity")
eq(result[1], "tail", "P6 tostring first")
eq(result[2], "extra", "P6 tostring second")

-- P0.29.8: every path returns zero values; retry order is static then self.
local callback_calls = 0
_G.Timer = nil
result = packed(H.delay, 0.5, function() callback_calls = callback_calls + 1; return 1, 2, 3 end)
eq(result.n, 0, "P8 missing timer arity")
eq(callback_calls, 1, "P8 missing timer callback")
local static_calls = 0
_G.Timer = {DelayCall = function() static_calls = static_calls + 1; return 1, 2, 3 end}
result = packed(H.delay, 0.5, function() end)
eq(result.n, 0, "P8 static success arity")
eq(static_calls, 1, "P8 static success calls")
attempts = 0
local timer = {}
timer.DelayCall = function(first)
    attempts = attempts + 1
    if first ~= timer then error("static attempt failed") end
    return "ignored"
end
_G.Timer = timer
result = packed(H.delay, 0.5, function() end)
eq(result.n, 0, "P8 fallback success arity")
eq(attempts, 2, "P8 fallback attempts")
attempts = 0
timer.DelayCall = function()
    attempts = attempts + 1
    error("both fail")
end
result = packed(H.delay, 0.5, function() end)
eq(result.n, 0, "P8 both fail arity")
eq(attempts, 2, "P8 both fail attempts")

-- P0.29.11: false/exception in Facade lookup falls back; raw global false is preserved.
local fallback_manager = {}
_G.Facade = {TableManager = false}
_G.TableManager = fallback_manager
result = packed(H.get_table_manager)
eq(result.n, 1, "P11 false-fallback arity")
eq(result[1], fallback_manager, "P11 false Facade fallback")
_G.Facade = setmetatable({}, {__index = function() error("Facade lookup failed") end})
result = packed(H.get_table_manager)
eq(result[1], fallback_manager, "P11 throwing Facade fallback")
local facade_manager = {}
_G.Facade = {TableManager = facade_manager}
result = packed(H.get_table_manager)
eq(result[1], facade_manager, "P11 Facade manager wins")
_G.Facade = nil
_G.TableManager = false
result = packed(H.get_table_manager)
eq(result.n, 1, "P11 global false arity")
eq(result[1], false, "P11 global false preserved")

-- P0.29.13: exactly one return, self-first P12 retry, and fallback error discarded.
_G.Facade = nil
_G.TableManager = nil
result = packed(H.get_data_table, "Missing")
eq(result.n, 1, "P13 absent manager arity")
eq(result[1], nil, "P13 absent manager")
local manager = {}
_G.TableManager = manager
result = packed(H.get_data_table, "Missing")
eq(result.n, 1, "P13 absent method arity")
eq(result[1], nil, "P13 absent method")
manager.GetTable = function(self, name) return {name = name} end
result = packed(H.get_data_table, "A")
eq(result.n, 1, "P13 table arity")
eq(result[1].name, "A", "P13 table value")
manager.GetTable = function() return false end
result = packed(H.get_data_table, "B")
eq(result.n, 1, "P13 false arity")
eq(result[1], false, "P13 false value")
manager.GetTable = function() return nil end
result = packed(H.get_data_table, "C")
eq(result.n, 1, "P13 nil-success arity")
eq(result[1], nil, "P13 nil-success")
attempts = 0
manager.GetTable = function(first)
    attempts = attempts + 1
    if first == manager then error("self failed after side effect") end
    return {name = first}
end
result = packed(H.get_data_table, "Static")
eq(result.n, 1, "P13 retry arity")
eq(result[1].name, "Static", "P13 retry value")
eq(attempts, 2, "P13 retry attempts")
attempts = 0
manager.GetTable = function()
    attempts = attempts + 1
    error("fallback error discarded by P13")
end
result = packed(H.get_data_table, "Fail")
eq(result.n, 1, "P13 both-fail arity")
eq(result[1], nil, "P13 both-fail nil")
eq(attempts, 2, "P13 both-fail attempts")

-- Active MutationRuntime integration uses the canonical ABI and runtime helpers.
eq(Mutation.safe_get, ABI.get, "MutationRuntime reuses AimABI.get")
eq(Mutation.call_optional_self, ABI.call_optional_self, "MutationRuntime reuses AimABI.call_optional_self")
eq(Mutation.get_table_manager, H.get_table_manager, "MutationRuntime reuses P11")
eq(Mutation.get_data_table, H.get_data_table, "MutationRuntime reuses P13")
_G.Facade = {TableManager = false}
_G.TableManager = fallback_manager
eq(Mutation.get_table_manager(), fallback_manager, "MutationRuntime false TableManager fallback")
local integrated_manager = {}
_G.Facade = nil
_G.TableManager = integrated_manager
attempts = 0
integrated_manager.GetTable = function(first)
    attempts = attempts + 1
    if first == integrated_manager then error("integration self failure") end
    return {name = first}
end
result = packed(Mutation.get_data_table, "Integrated")
eq(result.n, 1, "MutationRuntime P13 retry arity")
eq(result[1].name, "Integrated", "MutationRuntime P13 retry value")
eq(attempts, 2, "MutationRuntime P13 retry attempts")
integrated_manager.GetTable = function() error("integration both fail") end
result = packed(Mutation.get_data_table, "Fail")
eq(result.n, 1, "MutationRuntime both-fail arity")
eq(result[1], nil, "MutationRuntime both-fail one nil")

rawset(_G, "Facade", old.Facade)
rawset(_G, "TableManager", old.TableManager)
rawset(_G, "Timer", old.Timer)
_G.tostring = old.tostring

print("p029-runtime-helpers: ok")

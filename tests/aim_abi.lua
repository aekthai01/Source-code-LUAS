local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
local abi = S.AimABI

local function eq(actual, expected, message)
    if actual ~= expected then
        error((message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function truth(value, message)
    if not value then error(message or "expected truthy", 2) end
end

local function packed(...)
    return table.pack(...)
end

local function arity(result, expected, message)
    eq(result.n, expected, message or "return arity")
end

-- P0.29.2 / P0.29.2.0 protected lookup. The nested child performs the raw
-- owner[key] access without a nil guard; the parent pcall owns exceptions and
-- TESTSET semantics collapse false to nil.
do
    local r = packed(abi.get(nil, "x"))
    arity(r, 1, "P0.29.2 nil-owner arity")
    eq(r[1], nil)

    r = packed(abi.get({x=false}, "x"))
    arity(r, 1, "P0.29.2 false-field arity")
    eq(r[1], nil)

    local throwing = setmetatable({}, {__index=function() error("lookup exploded") end})
    r = packed(abi.get(throwing, "x"))
    arity(r, 1, "P0.29.2 throwing-index arity")
    eq(r[1], nil)

    r = packed(abi.get({x="truthy"}, "x"))
    arity(r, 1, "P0.29.2 truthy-field arity")
    eq(r[1], "truthy")
end

-- P0.29.3 self-first. Successful calls always return exactly
-- true,result1,result2; missing function and complete failure return exactly
-- false,nil. The fallback intentionally retries after a throwing first call.
do
    local r = packed(abi.self_first({}, "absent"))
    arity(r, 2, "P0.29.3 missing arity")
    eq(r[1], false); eq(r[2], nil)

    local owner = {}
    owner.zero = function(self) eq(self, owner); return end
    r = packed(abi.self_first(owner, "zero"))
    arity(r, 3, "P0.29.3 zero-result success arity")
    eq(r[1], true); eq(r[2], nil); eq(r[3], nil)

    owner.one = function(self) eq(self, owner); return 11 end
    r = packed(abi.self_first(owner, "one"))
    arity(r, 3, "P0.29.3 one-result success arity")
    eq(r[1], true); eq(r[2], 11); eq(r[3], nil)

    owner.multi = function(self) eq(self, owner); return 1, 2, 3, 4 end
    r = packed(abi.self_first(owner, "multi"))
    arity(r, 3, "P0.29.3 multi-result success arity")
    eq(r[1], true); eq(r[2], 1); eq(r[3], 2)

    local calls, mutated = {}, 0
    owner.retry = function(first, value)
        calls[#calls + 1] = first
        mutated = mutated + 1
        if first == owner then error("self-first failure after mutation") end
        return first, value, "discarded"
    end
    r = packed(abi.self_first(owner, "retry", 17))
    arity(r, 3, "P0.29.3 fallback success arity")
    eq(r[1], true); eq(r[2], 17); eq(r[3], nil)
    eq(mutated, 2, "P0.29.3 retry side effects")
    eq(#calls, 2); eq(calls[1], owner); eq(calls[2], 17)

    local failures = 0
    owner.fail = function()
        failures = failures + 1
        error("both attempts fail")
    end
    r = packed(abi.self_first(owner, "fail", 17))
    arity(r, 2, "P0.29.3 complete failure arity")
    eq(r[1], false); eq(r[2], nil)
    eq(failures, 2, "P0.29.3 both attempts execute")
end

-- P0.29.4 static-first mirrors P0.29.3 with invocation order reversed.
do
    local r = packed(abi.static_first({}, "absent"))
    arity(r, 2, "P0.29.4 missing arity")
    eq(r[1], false); eq(r[2], nil)

    local owner = {}
    owner.zero = function(...) eq(select("#", ...), 0); return end
    r = packed(abi.static_first(owner, "zero"))
    arity(r, 3, "P0.29.4 zero-result success arity")
    eq(r[1], true); eq(r[2], nil); eq(r[3], nil)

    owner.one = function(...) eq(select("#", ...), 0); return 21 end
    r = packed(abi.static_first(owner, "one"))
    arity(r, 3, "P0.29.4 one-result success arity")
    eq(r[1], true); eq(r[2], 21); eq(r[3], nil)

    owner.multi = function(...) eq(select("#", ...), 0); return 4, 5, 6, 7 end
    r = packed(abi.static_first(owner, "multi"))
    arity(r, 3, "P0.29.4 multi-result success arity")
    eq(r[1], true); eq(r[2], 4); eq(r[3], 5)

    local calls, mutated = {}, 0
    owner.retry = function(first, value)
        calls[#calls + 1] = first
        mutated = mutated + 1
        if first == 17 then error("static-first failure after mutation") end
        return first, value, "discarded"
    end
    r = packed(abi.static_first(owner, "retry", 17))
    arity(r, 3, "P0.29.4 fallback success arity")
    eq(r[1], true); eq(r[2], owner); eq(r[3], 17)
    eq(mutated, 2, "P0.29.4 retry side effects")
    eq(#calls, 2); eq(calls[1], 17); eq(calls[2], owner)

    local failures = 0
    owner.fail = function()
        failures = failures + 1
        error("both attempts fail")
    end
    r = packed(abi.static_first(owner, "fail", 17))
    arity(r, 2, "P0.29.4 complete failure arity")
    eq(r[1], false); eq(r[2], nil)
    eq(failures, 2, "P0.29.4 both attempts execute")
end

-- P0.29.12 optional-self has CALL C=3 on both pcall sites and RETURN B=3,
-- so every path returns exactly two values. Fallback failures preserve the
-- pcall error value instead of replacing it with nil.
do
    local r = packed(abi.call_optional_self("not-a-function", {}))
    arity(r, 2, "P0.29.12 not-function arity")
    eq(r[1], false); eq(r[2], nil)

    local owner = {}
    local fn_zero = function(self) eq(self, owner); return end
    r = packed(abi.call_optional_self(fn_zero, owner))
    arity(r, 2, "P0.29.12 self zero-result arity")
    eq(r[1], true); eq(r[2], nil)

    local fn_multi = function(self) eq(self, owner); return 1, 2, 3 end
    r = packed(abi.call_optional_self(fn_multi, owner))
    arity(r, 2, "P0.29.12 self multi-result arity")
    eq(r[1], true); eq(r[2], 1)

    local zero_calls = 0
    local fallback_zero = function(first)
        zero_calls = zero_calls + 1
        if first == owner then error("self call fails") end
        return
    end
    r = packed(abi.call_optional_self(fallback_zero, owner))
    arity(r, 2, "P0.29.12 fallback zero-result arity")
    eq(r[1], true); eq(r[2], nil)
    eq(zero_calls, 2, "P0.29.12 fallback zero retry count")

    local multi_calls = 0
    local fallback_multi = function(first)
        multi_calls = multi_calls + 1
        if first == owner then error("self call fails") end
        return 1, 2, 3
    end
    r = packed(abi.call_optional_self(fallback_multi, owner))
    arity(r, 2, "P0.29.12 fallback multi-result arity")
    eq(r[1], true); eq(r[2], 1)
    eq(multi_calls, 2, "P0.29.12 fallback multi retry count")

    local fail_calls = 0
    local both_fail = function()
        fail_calls = fail_calls + 1
        error("P0.29.12 fallback error marker")
    end
    r = packed(abi.call_optional_self(both_fail, owner))
    arity(r, 2, "P0.29.12 both-fail arity")
    eq(r[1], false)
    truth(r[2] ~= nil, "P0.29.12 fallback error value must survive")
    truth(tostring(r[2]):find("P0.29.12 fallback error marker", 1, true) ~= nil,
        "P0.29.12 fallback error marker missing")
    eq(fail_calls, 2, "P0.29.12 both attempts execute")
end

print("aim-abi: ok")

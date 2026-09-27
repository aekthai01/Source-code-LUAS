local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
local abi = S.AimABI
local function eq(a,b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local calls = {}
local obj = {}
obj.f = function(a, b)
    calls[#calls+1] = a
    if a == obj then error("first invocation already changed state") end
    return a, b
end
-- P3 retries only when pcall fails, even if the first invocation changed state.
local ok, a, b = abi.self_first(obj, "f", 17)
eq(ok, true); eq(a, 17); eq(#calls, 2); eq(calls[1], obj); eq(calls[2], 17)
calls = {}
local stat = { f = function(a, b)
    calls[#calls+1] = a
    if a == 17 then error("static attempt") end
    return a, b
end }
ok, a, b = abi.static_first(stat, "f", 17)
eq(ok, true); eq(a, stat); eq(b, 17); eq(#calls, 2)
eq(calls[1], 17); eq(calls[2], stat)
eq(select(1, abi.self_first({}, "absent")), false)
eq(abi.get({f=false}, "f"), nil) -- P2 TESTSET coerces false to nil.
local count = 0
local fn = function(first, value)
    count = count + 1
    if first == obj then error("retry") end
    return first, value
end
ok, a = abi.call_optional_self(fn, obj, 17)
eq(ok, true); eq(a, 17); eq(count, 2)
print("aim-abi: ok")

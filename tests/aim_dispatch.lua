local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
local M = S.MutationRuntime
local names = M.FEATURE_TABLES.aim
local seen, calls = {}, {}
local same, different = {}, {}
local table_for_name = { [names[1]]=same, [names[2]]=same, [names[3]]=different }
local result = M.apply_feature({}, "aim", nil, {
    get_data_table = function(name) seen[#seen+1]=name; return table_for_name[name] end,
    apply_table = function(feature, value, name)
        calls[#calls+1] = {feature, value, name}
        return name == names[3]
    end,
})
assert(result == true and #calls == 2 and #seen == #names)
assert(calls[1][2] == same and calls[1][3] == names[1])
assert(calls[2][2] == different and calls[2][3] == names[3])
assert(M.apply_feature({}, "absent", nil, {get_data_table=function() error("must not call") end}) == false)
assert(M.apply_feature({}, "aim", nil, {get_data_table=function() return nil end,
    apply_table=function() error("must not call") end}) == false)
local empty = {}
local input = { [names[1]]=empty, [names[2]]=io.stdout, [names[3]]=empty,
    [names[4]]=io.stdout, [names[5]]="invalid" }
local visited = {}
local saw = M.apply_feature({custom_dongdong_toggle_state={aim=false}}, "aim", nil, {
    get_data_table=function(name) return input[name] end,
    apply_table=function(_, value) visited[#visited+1]=value; return false end,
})
assert(saw == false and #visited == 3) -- no mode guard in P68 itself
assert(visited[1] == empty and visited[2] == io.stdout and visited[3] == "invalid")
-- P68 does not catch P13/P67 errors: callers are responsible for transaction rollback.
assert(not pcall(M.apply_feature, {}, "aim", nil, {get_data_table=function() error("lookup") end}))
assert(not pcall(M.apply_feature, {}, "aim", nil, {get_data_table=function() return {} end,
    apply_table=function() error("dispatch") end}))
print("aim-dispatch: ok")

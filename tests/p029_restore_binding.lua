local root=assert(arg[1],"root path required")
local S={}
assert(loadfile(root.."/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root.."/src/spectra/p029_runtime_helpers.lua"))(S)
assert(loadfile(root.."/src/spectra/mutation_runtime.lua"))(S)
local M=assert(S.MutationRuntime)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function pack(fn,...) return table.pack(fn(...)) end

local r=pack(M.restore_binding,nil,{}); eq(r.n,1,"nil binding arity"); eq(r[1],false,"nil binding")
r=pack(M.restore_binding,{},{}); eq(r.n,1,"missing owner/key arity"); eq(r[1],false,"missing owner/key")
r=pack(M.restore_binding,{owner={},key=nil},{}); eq(r.n,1,"nil key arity"); eq(r[1],false,"nil key")

local owner={}; local array={}
r=pack(M.restore_binding,{owner=owner,key="Bones"},array)
eq(r.n,1,"owner-only arity"); eq(r[1],true,"owner-only true"); eq(owner.Bones,array,"owner restored")

-- Fixed P57 capture: replacing the exported function after module construction
-- must not redirect P58. Parent value false is non-nil and must be restored.
local exported=M.array_set_raw
M.array_set_raw=function() error("mutated P57 export observed") end
owner={}; local parent={true,true,true}
local binding={owner=owner,key="Bones",parent_array=parent,parent_index=1,parent_value=false}
r=pack(M.restore_binding,binding,array)
eq(r.n,1,"fixed P57 arity"); eq(r[1],true,"fixed P57 true"); eq(parent[2],false,"parent false restored")
M.array_set_raw=exported

-- parent_owner/key path is a separate protected child and can turn a failed
-- direct assignment into overall success.
local bad_owner=setmetatable({}, {__newindex=function() error("owner-blocked") end})
local parent_owner={}
binding={owner=bad_owner,key="Bones",parent_owner=parent_owner,parent_key="Nested",parent_array=parent}
r=pack(M.restore_binding,binding,array)
eq(r.n,1,"parent-owner recovery arity"); eq(r[1],true,"parent-owner recovery")
eq(parent_owner.Nested,parent,"parent-owner restored array")

-- All three mechanisms can fail; errors are swallowed and one false remains.
local fail_parent_owner=setmetatable({}, {__newindex=function() error("parent-owner-blocked") end})
binding={owner=bad_owner,key="Bones",parent_array="not-array",parent_index=0,parent_value=1,parent_owner=fail_parent_owner,parent_key="Nested"}
r=pack(M.restore_binding,binding,array)
eq(r.n,1,"all-fail arity"); eq(r[1],false,"all-fail false")

-- Missing any one parent-array triple member skips P57 entirely.
for _,missing in ipairs({"parent_array","parent_index","parent_value"}) do
  local b={owner={},key="K",parent_array={},parent_index=0,parent_value=7}
  b[missing]=nil
  local before=M.array_set_raw; M.array_set_raw=function() error("dynamic export observed") end
  r=pack(M.restore_binding,b,array); eq(r.n,1,"nil gate arity "..missing); eq(r[1],true,"nil gate owner success "..missing)
  M.array_set_raw=before
end
print("p029-restore-binding: ok")

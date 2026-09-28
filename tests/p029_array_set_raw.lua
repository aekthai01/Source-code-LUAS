local root=assert(arg[1],"root path required")
local S={}
assert(loadfile(root.."/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root.."/src/spectra/p029_runtime_helpers.lua"))(S)
assert(loadfile(root.."/src/spectra/mutation_runtime.lua"))(S)
local M=assert(S.MutationRuntime)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function pack(fn,...) return table.pack(fn(...)) end

-- Table branch is a pcall tail-return: success one value, exception false+error.
local t={}
local r=pack(M.array_set_raw,t,0,"x"); eq(r.n,1,"table success arity"); eq(r[1],true,"table success"); eq(t[1],"x","table index+1")
local blocked=setmetatable({}, {__newindex=function() error("table-blocked") end})
r=pack(M.array_set_raw,blocked,1,"y"); eq(r.n,2,"table failure arity"); eq(r[1],false,"table failure"); truth(tostring(r[2]):find("table%-blocked")~=nil,"table error preserved")
-- Non-table/non-userdata returns exactly one false.
r=pack(M.array_set_raw,"nope",0,1); eq(r.n,1,"wrong-type arity"); eq(r[1],false,"wrong-type false")

-- Use a real Lua userdata and temporarily replace its metatable. Restore it before close.
local ud=assert(io.tmpfile())
local original_mt=debug.getmetatable(ud)
local direct_calls={}
debug.setmetatable(ud, {
  __index=function(self,key)
    if key=="Set" then
      return function(...)
        direct_calls[#direct_calls+1]=table.pack(...)
        return "ignored",2,3
      end
    end
  end,
  __newindex=function() error("unexpected direct fallback") end,
})
r=pack(M.array_set_raw,ud,2,"direct")
eq(r.n,1,"direct Set success arity"); eq(r[1],true,"direct Set true")
eq(#direct_calls,1,"direct Set calls")
eq(direct_calls[1].n,3,"direct Set self args"); eq(direct_calls[1][1],ud,"direct Set receiver"); eq(direct_calls[1][2],3,"direct Set index1"); eq(direct_calls[1][3],"direct","direct Set value")

-- Missing direct Set reaches ULuaArrayHelper.Set: static first, self only after exception.
local saved_helper=rawget(_G,"ULuaArrayHelper")
local helper={}
local helper_calls={}
helper.Set=function(...)
  helper_calls[#helper_calls+1]=table.pack(...)
  return true
end
rawset(_G,"ULuaArrayHelper",helper)
debug.setmetatable(ud,{__index=function() return nil end,__newindex=function() error("unexpected assignment") end})
r=pack(M.array_set_raw,ud,3,"static")
eq(r.n,1,"helper static success arity"); eq(r[1],true,"helper static success")
eq(#helper_calls,1,"helper static one call"); eq(helper_calls[1].n,3,"helper static argc"); eq(helper_calls[1][1],ud,"helper static array first"); eq(helper_calls[1][2],4,"helper static index1"); eq(helper_calls[1][3],"static","helper static value")

helper_calls={}
helper.Set=function(...)
  local a=table.pack(...); helper_calls[#helper_calls+1]=a
  if a[1]~=helper then error("static-side-effect") end
  return true
end
r=pack(M.array_set_raw,ud,4,"retry")
eq(r.n,1,"helper retry success arity"); eq(r[1],true,"helper retry success")
eq(#helper_calls,2,"helper retry count")
eq(helper_calls[1].n,3,"helper first argc"); eq(helper_calls[1][1],ud,"helper first static")
eq(helper_calls[2].n,4,"helper self argc"); eq(helper_calls[2][1],helper,"helper self receiver"); eq(helper_calls[2][2],ud,"helper self array"); eq(helper_calls[2][3],5,"helper self index1"); eq(helper_calls[2][4],"retry","helper self value")

-- Both helper calls fail, then final protected array[index1]=value determines return arity.
helper_calls={}
helper.Set=function(...) helper_calls[#helper_calls+1]=table.pack(...); error("helper-fail") end
local assigned={}
debug.setmetatable(ud,{__index=function() return nil end,__newindex=function(_,k,v) assigned.k=k; assigned.v=v end})
r=pack(M.array_set_raw,ud,5,"fallback")
eq(#helper_calls,2,"both helper attempts"); eq(r.n,1,"final assignment success arity"); eq(r[1],true,"final assignment success"); eq(assigned.k,6,"final assignment index1"); eq(assigned.v,"fallback","final assignment value")

debug.setmetatable(ud,{__index=function() return nil end,__newindex=function() error("final-blocked") end})
r=pack(M.array_set_raw,ud,6,"fail")
eq(r.n,2,"final assignment failure arity"); eq(r[1],false,"final assignment failure"); truth(tostring(r[2]):find("final%-blocked")~=nil,"final assignment error")

debug.setmetatable(ud,original_mt); ud:close(); rawset(_G,"ULuaArrayHelper",saved_helper)
print("p029-array-set-raw: ok")

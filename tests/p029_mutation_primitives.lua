local root=assert(arg[1],"root path required")
local S={}
assert(loadfile(root.."/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root.."/src/spectra/p029_runtime_helpers.lua"))(S)
assert(loadfile(root.."/src/spectra/mutation_runtime.lua"))(S)
local ABI=assert(S.AimABI)
local M=assert(S.MutationRuntime)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function packed(fn,...) return table.pack(fn(...)) end

-- P0.29.10 tail-returns string.gsub, including the substitution count.
local n=packed(M.normalize_identifier,"A-B c!")
eq(n.n,2,"P10 return arity"); eq(n[1],"abc","P10 normalized"); eq(n[2],3,"P10 gsub count")
local f=packed(M.normalize_identifier,false)
eq(f.n,2,"P10 false arity"); eq(f[1],""); eq(f[2],0)
local z=packed(M.normalize_identifier,0)
eq(z.n,2,"P10 zero arity"); eq(z[1],"0"); eq(z[2],0)

-- P0.29.18: non-userdata returns the original exactly once.
local marker={}
local plain=packed(M.table_extend,marker)
eq(plain.n,1,"P18 plain arity"); eq(plain[1],marker,"P18 plain identity")
local primitive=packed(M.table_extend,"x")
eq(primitive.n,1,"P18 primitive arity"); eq(primitive[1],"x")

local function userdata_with_index(index)
  local u=assert(io.tmpfile(),"tmpfile userdata required")
  debug.setmetatable(u,{__index=index})
  return u
end
local calls=0
local extended={ok=true}
local u1
u1=userdata_with_index(function(self,key)
  if key=="TableExtend" then
    return function(...)
      calls=calls+1
      local a=table.pack(...)
      eq(a.n,1,"P18 first arg count"); eq(a[1],u1,"P18 first self arg")
      return extended,"discarded"
    end
  end
end)
local e1=packed(M.table_extend,u1)
eq(e1.n,1,"P18 success arity"); eq(e1[1],extended,"P18 table result"); eq(calls,1)

local retry_calls=0
local retry_result={retry=true}
local u2
u2=userdata_with_index(function(self,key)
  if key=="TableExtend" then
    return function(...)
      retry_calls=retry_calls+1
      local a=table.pack(...)
      if a.n==1 then eq(a[1],u2,"P18 throwing self arg"); error("self form fails") end
      eq(a.n,0,"P18 static retry arg count")
      return retry_result
    end
  end
end)
local e2=packed(M.table_extend,u2)
eq(e2.n,1,"P18 retry arity"); eq(e2[1],retry_result); eq(retry_calls,2,"P18 retry count")

local u3
u3=userdata_with_index(function(self,key)
  if key=="TableExtend" then return function() return false,"extra" end end
end)
local e3=packed(M.table_extend,u3)
eq(e3.n,1,"P18 non-table arity"); eq(e3[1],u3,"P18 non-table returns original")

-- P0.29.49 exact table/invalid/userdata behavior and one-value return contract.
local table_case=packed(M.array_get,{"a","b"},1)
eq(table_case.n,1,"P49 table arity"); eq(table_case[1],"b","P49 zero-based table index")
local invalid=packed(M.array_get,"nope",0)
eq(invalid.n,1,"P49 invalid arity"); eq(invalid[1],nil,"P49 invalid nil")

local direct_calls=0
local u4
u4=userdata_with_index(function(self,key)
  if key=="Get" then
    return function(owner,index1)
      direct_calls=direct_calls+1; eq(owner,u4,"P49 direct self"); eq(index1,3,"P49 direct index1")
      return false,"discarded"
    end
  end
end)
local direct=packed(M.array_get,u4,2)
eq(direct.n,1,"P49 direct arity"); eq(direct[1],false,"P49 false is valid direct result"); eq(direct_calls,1)

local helper_calls=0
local u5
u5=userdata_with_index(function(self,key)
  if key=="Get" then return function(owner,index1) eq(owner,u5); eq(index1,1); return nil end end
end)
_G.ULuaArrayHelper={Get=function(owner,array,index1)
  helper_calls=helper_calls+1; eq(owner,_G.ULuaArrayHelper,"P49 helper self"); eq(array,u5,"P49 helper array"); eq(index1,1,"P49 helper index")
  return "helper", "discarded"
end}
local helper=packed(M.array_get,u5,0)
eq(helper.n,1,"P49 helper arity"); eq(helper[1],"helper"); eq(helper_calls,1,"P49 nil direct falls through")

local old_get,old_optional=ABI.get,ABI.call_optional_self
local replacement_get,replacement_optional=0,0
ABI.get=function(...) replacement_get=replacement_get+1; error("replacement P2 observed") end
ABI.call_optional_self=function(...) replacement_optional=replacement_optional+1; error("replacement P12 observed") end
local fixed=packed(M.array_get,u4,2)
ABI.get,ABI.call_optional_self=old_get,old_optional
eq(fixed.n,1,"P49 fixed capture arity"); eq(fixed[1],false)
eq(replacement_get,0,"P49 fixed P2 capture"); eq(replacement_optional,0,"P49 fixed P12 capture")
_G.ULuaArrayHelper=nil

-- P0.29.17.0 is the zero-return child assignment closure used by P17 restore.
local restore_obj={x=9}
local restore_state={
  custom_dongdong_feature_snapshots={
    demo={records={{object=restore_obj,key="x",value=4}},seen={}}
  }
}
local restored=packed(M.restore_feature_snapshot,restore_state,"demo")
eq(restored.n,1,"P17 parent arity"); eq(restored[1],true,"P17 child success"); eq(restore_obj.x,4,"P17 child assignment")
eq(restore_state.custom_dongdong_feature_snapshots.demo,nil,"P17 snapshot cleared")

-- Assignment error is swallowed by the parent pcall; child is not retried.
local writes=0
local blocked=setmetatable({}, {__newindex=function() writes=writes+1; error("blocked") end})
local fail_state={
  custom_dongdong_feature_snapshots={
    demo={records={{object=blocked,key="x",value=7}},seen={}}
  }
}
local failed=packed(M.restore_feature_snapshot,fail_state,"demo")
eq(failed.n,1,"P17 failure arity"); eq(failed[1],false,"P17 child failure"); eq(writes,1,"P17 child no retry")
eq(fail_state.custom_dongdong_feature_snapshots.demo,nil,"P17 failed snapshot cleared")

print("p029-mutation-primitives: ok")

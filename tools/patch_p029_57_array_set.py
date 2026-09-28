#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def put(path,text): path.write_text(text,encoding='utf-8')

# Source: preserve fixed P12 self-first semantics for array:Set, but make the
# ULuaArrayHelper fallback bytecode-exact static-first then self retry.
p=ROOT/'src/spectra/mutation_runtime.lua'; s=p.read_text()
old='''    local helper = rawget(_G, "ULuaArrayHelper")
    fn = safe_get(helper, "Set")
    if type(fn) == "function" then
        ok = select(1, call_optional_self(fn, helper, array, index1, value))
        if ok then return true end
    end
    return pcall(function() array[index1] = value end)
'''
new='''    local helper = rawget(_G, "ULuaArrayHelper")
    fn = safe_get(helper, "Set")
    if type(fn) == "function" then
        ok = pcall(fn, array, index1, value)
        if not ok then ok = pcall(fn, helper, array, index1, value) end
        if ok then return true end
    end
    return pcall(function() array[index1] = value end)
'''
assert s.count(old)==1,("array_set_raw helper block",s.count(old)); s=s.replace(old,new,1); put(p,s)

# Focused exact P57 behavior, including actual userdata receiver and arity.
p=ROOT/'tests/p029_array_set_raw.lua'
put(p,r'''local root=assert(arg[1],"root path required")
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
''')

# Generated ownership/evidence.
p=ROOT/'tools/aim_forensics.py'; s=p.read_text()
s=s.replace('    "0.29.17.0",\n','    "0.29.17.0",\n    "0.29.57.0",\n    "0.29.57.1",\n',1)
s=s.replace('MUTATION_HELPERS = ["0.29.10", "0.29.14", "0.29.15", "0.29.16", "0.29.18", "0.29.49"]','MUTATION_HELPERS = ["0.29.10", "0.29.14", "0.29.15", "0.29.16", "0.29.18", "0.29.49", "0.29.57"]',1)
s=s.replace('assert len(NESTED) == 13','assert len(NESTED) == 15',1)
s=s.replace('assert len(MUTATION_HELPERS) == 6','assert len(MUTATION_HELPERS) == 7',1)
s=s.replace('assert len(ALL) == 61 and len(set(ALL)) == 61','assert len(ALL) == 64 and len(set(ALL)) == 64',1)
s=s.replace('if pid in {"0.29.15.0", "0.29.17.0"}:','if pid in {"0.29.15.0", "0.29.17.0", "0.29.57.0", "0.29.57.1"}:',1)
s=s.replace('    "0.29.49": "R74",\n','    "0.29.49": "R74",\n    "0.29.57": "R82",\n',1)
old='mutation_symbols={"0.29.10":"MutationRuntime.normalize_identifier","0.29.14":"MutationRuntime.p029_ensure_feature_snapshot","0.29.15":"MutationRuntime.p029_snapshot_set","0.29.16":"MutationRuntime.p029_clear_feature_snapshot","0.29.18":"MutationRuntime.table_extend","0.29.49":"MutationRuntime.array_get"}'
new='mutation_symbols={"0.29.10":"MutationRuntime.normalize_identifier","0.29.14":"MutationRuntime.p029_ensure_feature_snapshot","0.29.15":"MutationRuntime.p029_snapshot_set","0.29.16":"MutationRuntime.p029_clear_feature_snapshot","0.29.18":"MutationRuntime.table_extend","0.29.49":"MutationRuntime.array_get","0.29.57":"MutationRuntime.array_set_raw"}'
assert s.count(old)==1; s=s.replace(old,new,1)
s=s.replace('  "0.29.49":"exactly one value: zero-based table read or protected userdata Get/helper Get with false preserved and nil fallback",\n','  "0.29.49":"exactly one value: zero-based table read or protected userdata Get/helper Get with false preserved and nil fallback",\n  "0.29.57":"table/final assignment tail-return pcall arity; wrong type one false; successful userdata Set paths one true",\n',1)
s=s.replace('  "0.29.49":"table direct index+1; userdata gate; fixed P2 Get; fixed P12 self-first; direct nil falls through to ULuaArrayHelper Get through same P2/P12",\n','  "0.29.49":"table direct index+1; userdata gate; fixed P2 Get; fixed P12 self-first; direct nil falls through to ULuaArrayHelper Get through same P2/P12",\n  "0.29.57":"index+1; table pcall child; userdata fixed P2 Set then fixed P12 self-first; ULuaArrayHelper.Set static pcall then self pcall only after exception; final pcall child",\n',1)
put(p,s)

# Validator exact shapes/captures/opcodes and focused test registration.
p=ROOT/'tools/validate_phase_d.py'; s=p.read_text()
s=s.replace("mutation_paths={'0.29.10','0.29.14','0.29.15','0.29.16','0.29.18','0.29.49'}","mutation_paths={'0.29.10','0.29.14','0.29.15','0.29.16','0.29.18','0.29.49','0.29.57'}",1)
s=s.replace("mutation_shape={'0.29.10':(1,17,1,0),'0.29.18':(1,40,2,0),'0.29.49':(2,71,3,0)}","mutation_shape={'0.29.10':(1,17,1,0),'0.29.18':(1,40,2,0),'0.29.49':(2,71,3,0),'0.29.57':(3,80,3,2)}",1)
s=s.replace("mutation_upvalues={'0.29.10':[(0,0)],'0.29.18':[(0,0),(1,19)],'0.29.49':[(0,0),(1,19),(1,32)]}","mutation_upvalues={'0.29.10':[(0,0)],'0.29.18':[(0,0),(1,19)],'0.29.49':[(0,0),(1,19),(1,32)],'0.29.57':[(0,0),(1,19),(1,32)]}",1)
s=s.replace("mutation_registers={'0.29.10':('R30',325),'0.29.18':('R38',333),'0.29.49':('R74',1034)}","mutation_registers={'0.29.10':('R30',325),'0.29.18':('R38',333),'0.29.49':('R74',1034),'0.29.57':('R82',1042)}",1)
s=s.replace("mutation_captures={'0.29.10':set(),'0.29.18':{('U1','R19','0.29.2')},'0.29.49':{('U1','R19','0.29.2'),('U2','R32','0.29.12')}}","mutation_captures={'0.29.10':set(),'0.29.18':{('U1','R19','0.29.2')},'0.29.49':{('U1','R19','0.29.2'),('U2','R32','0.29.12')},'0.29.57':{('U1','R19','0.29.2'),('U2','R32','0.29.12')}}",1)
needle="    p49=body('0.29.49')\n    assert \"'ULuaArrayHelper'\" in p49 and \"'Get'\" in p49\n    assert re.search(r'^0009 GETTABLE\\s+R2, R0, R2$',p49,re.M) and re.search(r'^0010 RETURN\\s+A=2 B=2 C=0$',p49,re.M)\n"
add="""    p57=body('0.29.57')\n    assert re.search(r'^0010 CLOSURE\\s+R5, P0$',p57,re.M) and re.search(r'^0011 TAILCALL\\s+A=4 B=2 C=0$',p57,re.M)\n    assert re.search(r'^0020 GETUPVAL\\s+R4, U1$',p57,re.M) and re.search(r'^0031 GETUPVAL\\s+R7, U2$',p57,re.M)\n    assert re.search(r'^0036 CALL\\s+A=7 B=5 C=0$',p57,re.M) and re.search(r'^0037 CALL\\s+A=5 B=0 C=2$',p57,re.M)\n    assert re.search(r'^0055 GETTABUP\\s+R7, U0, K3=\\'pcall\\'$',p57,re.M) and re.search(r'^0060 CALL\\s+A=7 B=5 C=2$',p57,re.M)\n    assert re.search(r'^0063 GETTABUP\\s+R8, U0, K3=\\'pcall\\'$',p57,re.M) and re.search(r'^0069 CALL\\s+A=8 B=6 C=2$',p57,re.M)\n    assert re.search(r'^0076 CLOSURE\\s+R8, P1$',p57,re.M) and re.search(r'^0077 TAILCALL\\s+A=7 B=2 C=0$',p57,re.M)\n    for child in ('0.29.57.0','0.29.57.1'):\n        item=prototypes[child]\n        assert (item['numparams'],item['instruction_count'],item['upvalues'],item['child_count'])==(0,7,[{'instack':1,'idx':0},{'instack':1,'idx':3},{'instack':1,'idx':2}],0),child\n        text=body(child); assert re.search(r'^0005 SETTABUP\\s+U0, R0, R1$',text,re.M) and re.search(r'^0006 RETURN\\s+A=0 B=1 C=0$',text,re.M)\n        assert child in groups['source_owned'] and source_files[child]=='src/spectra/mutation_runtime.lua'\n"""
assert s.count(needle)==1; s=s.replace(needle,needle+add,1)
source_needle="    assert 'function M.array_get(array, index0)' in mutation_source\n"
source_add="""    assert 'function M.array_set_raw(array, index0, value)' in mutation_source\n    assert 'ok = pcall(fn, array, index1, value)' in mutation_source\n    assert 'if not ok then ok = pcall(fn, helper, array, index1, value) end' in mutation_source\n"""
assert s.count(source_needle)==1; s=s.replace(source_needle,source_needle+source_add,1)
testneedle="'mutation_runtime.lua':'mutation-runtime: ok','p029_runtime_helpers.lua':'p029-runtime-helpers: ok','p029_mutation_primitives.lua':'p029-mutation-primitives: ok'"
testrepl="'mutation_runtime.lua':'mutation-runtime: ok','p029_runtime_helpers.lua':'p029-runtime-helpers: ok','p029_mutation_primitives.lua':'p029-mutation-primitives: ok','p029_array_set_raw.lua':'p029-array-set-raw: ok'"
assert s.count(testneedle)==1; s=s.replace(testneedle,testrepl,1)
s=s.replace("'phase':'E5.13-p029-17-child-source-only'","'phase':'E5.14-p029-57-array-set-source-only'",1)
put(p,s)
print('applied exact P0.29.57 array-set checkpoint')

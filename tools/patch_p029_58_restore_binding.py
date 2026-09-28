#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def put(p,s): p.write_text(s,encoding='utf-8')

p=ROOT/'src/spectra/mutation_runtime.lua'; s=p.read_text()
anchor='''function M.ensure_bone_name_pool(state)\n'''
assert s.count(anchor)==1
# Capture exact P57 identity after its construction, matching root R82 capture.
s=s.replace(anchor,'local array_set_raw_029_57 = M.array_set_raw\n\n'+anchor,1)
old='if M.array_set_raw(binding.parent_array, binding.parent_index, binding.parent_value) then ok = true end'
new='if array_set_raw_029_57(binding.parent_array, binding.parent_index, binding.parent_value) then ok = true end'
assert s.count(old)==1; s=s.replace(old,new,1); put(p,s)

p=ROOT/'tests/p029_restore_binding.lua'
put(p,r'''local root=assert(arg[1],"root path required")
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
''')

p=ROOT/'tools/aim_forensics.py'; s=p.read_text()
s=s.replace('    "0.29.57.1",\n','    "0.29.57.1",\n    "0.29.58.0",\n    "0.29.58.1",\n',1)
s=s.replace('"0.29.49", "0.29.57"]','"0.29.49", "0.29.57", "0.29.58"]',1)
s=s.replace('assert len(NESTED) == 15','assert len(NESTED) == 17',1)
s=s.replace('assert len(MUTATION_HELPERS) == 7','assert len(MUTATION_HELPERS) == 8',1)
s=s.replace('assert len(ALL) == 64 and len(set(ALL)) == 64','assert len(ALL) == 67 and len(set(ALL)) == 67',1)
s=s.replace('"0.29.57.0", "0.29.57.1"}:','"0.29.57.0", "0.29.57.1", "0.29.58.0", "0.29.58.1"}:',1)
s=s.replace('    "0.29.57": "R82",\n','    "0.29.57": "R82",\n    "0.29.58": "R83",\n',1)
s=s.replace('"0.29.57":"MutationRuntime.array_set_raw"}', '"0.29.57":"MutationRuntime.array_set_raw","0.29.58":"MutationRuntime.restore_binding"}',1)
s=s.replace('  "0.29.57":"table/final assignment tail-return pcall arity; wrong type one false; successful userdata Set paths one true",\n','  "0.29.57":"table/final assignment tail-return pcall arity; wrong type one false; successful userdata Set paths one true",\n  "0.29.58":"exactly one boolean; protected direct/parent-owner writes and fixed P57 parent-array restore aggregate success",\n',1)
s=s.replace('  "0.29.57":"index+1; table pcall child; userdata fixed P2 Set then fixed P12 self-first; ULuaArrayHelper.Set static pcall then self pcall only after exception; final pcall child",\n','  "0.29.57":"index+1; table pcall child; userdata fixed P2 Set then fixed P12 self-first; ULuaArrayHelper.Set static pcall then self pcall only after exception; final pcall child",\n  "0.29.58":"binding table/owner/key gate; protected owner assignment; nil-specific parent triple invokes fixed P57; nil-specific parent owner/key protected assignment; return aggregate boolean",\n',1)
put(p,s)

p=ROOT/'tools/validate_phase_d.py'; s=p.read_text()
s=s.replace("'0.29.57'}","'0.29.57','0.29.58'}",1)
s=s.replace("'0.29.57':(3,80,3,2)}","'0.29.57':(3,80,3,2),'0.29.58':(2,50,2,2)}",1)
s=s.replace("'0.29.57':[(0,0),(1,19),(1,32)]}","'0.29.57':[(0,0),(1,19),(1,32)],'0.29.58':[(0,0),(1,82)]}",1)
s=s.replace("'0.29.57':('R82',1042)}","'0.29.57':('R82',1042),'0.29.58':('R83',1043)}",1)
s=s.replace("'0.29.57':{('U1','R19','0.29.2'),('U2','R32','0.29.12')}}","'0.29.57':{('U1','R19','0.29.2'),('U2','R32','0.29.12')},'0.29.58':{('U1','R82','0.29.57')}}",1)
needle="""    for child in ('0.29.57.0','0.29.57.1'):
        item=prototypes[child]
        assert (item['numparams'],item['instruction_count'],item['upvalues'],item['child_count'])==(0,7,[{'instack':1,'idx':0},{'instack':1,'idx':3},{'instack':1,'idx':2}],0),child
        text=body(child); assert re.search(r'^0005 SETTABUP\\s+U0, R0, R1$',text,re.M) and re.search(r'^0006 RETURN\\s+A=0 B=1 C=0$',text,re.M)
        assert child in groups['source_owned'] and source_files[child]=='src/spectra/mutation_runtime.lua'
"""
add="""    p58=body('0.29.58')
    assert re.search(r'^0017 CLOSURE\\s+R3, P0$',p58,re.M) and re.search(r'^0018 CALL\\s+A=2 B=2 C=2$',p58,re.M)
    assert re.search(r'^0028 GETUPVAL\\s+R3, U1$',p58,re.M) and re.search(r'^0032 CALL\\s+A=3 B=4 C=2$',p58,re.M)
    assert re.search(r'^0043 CLOSURE\\s+R4, P1$',p58,re.M) and re.search(r'^0044 CALL\\s+A=3 B=2 C=2$',p58,re.M)
    assert re.search(r'^0048 RETURN\\s+A=2 B=2 C=0$',p58,re.M)
    c580=prototypes['0.29.58.0']; assert (c580['numparams'],c580['instruction_count'],c580['upvalues'],c580['child_count'])==(0,8,[{'instack':1,'idx':0},{'instack':1,'idx':1}],0)
    c581=prototypes['0.29.58.1']; assert (c581['numparams'],c581['instruction_count'],c581['upvalues'],c581['child_count'])==(0,8,[{'instack':1,'idx':0}],0)
    for child in ('0.29.58.0','0.29.58.1'):
        assert child in groups['source_owned'] and source_files[child]=='src/spectra/mutation_runtime.lua'
        assert re.search(r'^0007 RETURN\\s+A=0 B=1 C=0$',body(child),re.M)
"""
assert s.count(needle)==1; s=s.replace(needle,needle+add,1)
s=s.replace("    assert 'if not ok then ok = pcall(fn, helper, array, index1, value) end' in mutation_source\n","    assert 'if not ok then ok = pcall(fn, helper, array, index1, value) end' in mutation_source\n    assert 'local array_set_raw_029_57 = M.array_set_raw' in mutation_source\n    assert 'if array_set_raw_029_57(binding.parent_array, binding.parent_index, binding.parent_value) then ok = true end' in mutation_source\n",1)
s=s.replace("'p029_array_set_raw.lua':'p029-array-set-raw: ok'","'p029_array_set_raw.lua':'p029-array-set-raw: ok','p029_restore_binding.lua':'p029-restore-binding: ok'",1)
s=s.replace("'phase':'E5.14-p029-57-array-set-source-only'","'phase':'E5.15-p029-58-restore-binding-source-only'",1)
put(p,s)
print('applied exact P0.29.58 restore-binding checkpoint')

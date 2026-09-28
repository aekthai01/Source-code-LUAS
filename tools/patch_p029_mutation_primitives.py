from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def replace_once(rel,old,new):
    p=ROOT/rel; text=p.read_text(encoding='utf-8'); count=text.count(old)
    assert count==1,(rel,count,old[:120]); p.write_text(text.replace(old,new,1),encoding='utf-8')

def insert_before(rel,marker,block):
    p=ROOT/rel; text=p.read_text(encoding='utf-8'); assert text.count(marker)==1,(rel,marker)
    p.write_text(text.replace(marker,block+marker,1),encoding='utf-8')

# Focused exact-ABI regression for P10/P18/P49.
test=r'''local root=assert(arg[1],"root path required")
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

print("p029-mutation-primitives: ok")
'''
(ROOT/'tests/p029_mutation_primitives.lua').write_text(test,encoding='utf-8')

# Extend aim_forensics with a reusable mutation-helper subsystem map.
replace_once('tools/aim_forensics.py','RUNTIME_HELPERS = ["0.29.5", "0.29.6", "0.29.8", "0.29.11", "0.29.13"]\nAIM_RUNTIME =', 'RUNTIME_HELPERS = ["0.29.5", "0.29.6", "0.29.8", "0.29.11", "0.29.13"]\nMUTATION_HELPERS = ["0.29.10", "0.29.18", "0.29.49"]\nAIM_RUNTIME =')
replace_once('tools/aim_forensics.py','ALL = [*PRIMARY, *OUTER, *NESTED, *ABI_HELPERS, *RUNTIME_HELPERS, *AIM_RUNTIME]','ALL = [*PRIMARY, *OUTER, *NESTED, *ABI_HELPERS, *RUNTIME_HELPERS, *MUTATION_HELPERS, *AIM_RUNTIME]')
replace_once('tools/aim_forensics.py','assert len(RUNTIME_HELPERS) == 5\nassert len(AIM_RUNTIME) == 4\nassert len(ALL) == 53 and len(set(ALL)) == 53','assert len(RUNTIME_HELPERS) == 5\nassert len(MUTATION_HELPERS) == 3\nassert len(AIM_RUNTIME) == 4\nassert len(ALL) == 56 and len(set(ALL)) == 56')
replace_once('tools/aim_forensics.py','    if pid in AIM_RUNTIME:\n        return "src/spectra/aim_runtime.lua"\n','    if pid in MUTATION_HELPERS:\n        return "src/spectra/mutation_runtime.lua"\n    if pid in AIM_RUNTIME:\n        return "src/spectra/aim_runtime.lua"\n')
replace_once('tools/aim_forensics.py','assert set(RUNTIME_HELPERS) <= set(D)\nassert set(AIM_RUNTIME) <= set(D)','assert set(RUNTIME_HELPERS) <= set(D)\nassert set(MUTATION_HELPERS) <= set(D)\nassert set(AIM_RUNTIME) <= set(D)')
replace_once('tools/aim_forensics.py','    "0.29.13": "R33",\n    "0.29.71": "R96",','    "0.29.13": "R33",\n    "0.29.10": "R30",\n    "0.29.18": "R38",\n    "0.29.49": "R74",\n    "0.29.71": "R96",')

map_block=r'''# Reusable source-ownership evidence for mutation primitives. Later bone-array
# checkpoints extend this subsystem map rather than inventing one file per helper.
mutation_symbols={"0.29.10":"MutationRuntime.normalize_identifier","0.29.18":"MutationRuntime.table_extend","0.29.49":"MutationRuntime.array_get"}
mutation_contracts={
  "0.29.10":"tail-return string.gsub: exactly normalized string plus substitution count",
  "0.29.18":"exactly one value: table extension only on successful protected call yielding table, else original input",
  "0.29.49":"exactly one value: zero-based table read or protected userdata Get/helper Get with false preserved and nil fallback",
}
mutation_order={
  "0.29.10":"lower(tostring(input or empty)); tailcall gsub non-word removal",
  "0.29.18":"userdata gate; fixed P2 TableExtend lookup; pcall(fn,value); retry pcall(fn) only after exception; accept table result only",
  "0.29.49":"table direct index+1; userdata gate; fixed P2 Get; fixed P12 self-first; direct nil falls through to ULuaArrayHelper Get through same P2/P12",
}
mutation_map={"_meta":{"source_of_truth":"embedded_payload.bin","payload_sha256":PAYLOAD_SHA,"names_are_reconstructed_semantic_labels":True,"payload_closure_rebinding":False,"ownership_boundary":MUTATION_HELPERS},"helpers":{}}
for pid in MUTATION_HELPERS:
    item=P[pid]
    mutation_map["helpers"][pid]={
      "prototype_id":pid,"numparams":item["numparams"],"instruction_count":item["instruction_count"],"upvalues":item["upvalues"],"child_count":item["child_count"],
      "p029_parent_register":root_closures[pid]["register"],"p029_closure_instruction":root_closures[pid]["instruction"],"captured_helper_registers":captured_root_helpers(pid),
      "source_symbol":mutation_symbols[pid],"source_file":"src/spectra/mutation_runtime.lua","return_contract":mutation_contracts[pid],"branch_retry_order":mutation_order[pid],
      "source_capture_identity":"fixed sibling helper identities captured when MutationRuntime loads" if pid!="0.29.10" else "environment-only helper; no sibling closure capture",
      "source_only_dependency":True,"current_ownership":"source_owned","payload_closure_rebinding":False,
    }
(ROOT/"P029_MUTATION_HELPER_MAP.json").write_text(json.dumps(mutation_map,indent=2,ensure_ascii=False)+"\n")
md=["# P0.29 Mutation Helper Map","",f"Evidence payload SHA-256: `{PAYLOAD_SHA}`.","","Names are reconstructed semantic labels. Payload copies are not dynamically rebound.","","| Prototype | Root register | Params | Instructions | Captures | Source symbol | Return contract |","|---|---:|---:|---:|---|---|---|"]
for pid in MUTATION_HELPERS:
    e=mutation_map["helpers"][pid]; caps=", ".join(x["register"]+"/"+x["prototype"] for x in e["captured_helper_registers"]) or "environment only"
    md.append(f"| `{pid}` | `{e['p029_parent_register']}` | {e['numparams']} | {e['instruction_count']} | {caps} | `{e['source_symbol']}` | {e['return_contract']} |")
(ROOT/"P029_MUTATION_HELPER_MAP.md").write_text("\n".join(md)+"\n")

'''
insert_before('tools/aim_forensics.py','index = {\n',map_block)
replace_once('tools/aim_forensics.py','        "runtime_helpers": 5,\n        "aim_runtime": 4,\n        "indexed_entries_total": 53,','        "runtime_helpers": 5,\n        "mutation_helpers": 3,\n        "aim_runtime": 4,\n        "indexed_entries_total": 56,')
replace_once('tools/aim_forensics.py','    elif pid == "0.29.71":\n','    elif pid == "0.29.10":\n        item.update(reconstructed_name="normalize_identifier", evidence_status="17-instruction environment-only gsub tail-return helper; two-value return pinned")\n    elif pid == "0.29.18":\n        item.update(reconstructed_name="table_extend", evidence_status="40-instruction fixed P2 lookup and exception-only static retry; one-value return pinned")\n    elif pid == "0.29.49":\n        item.update(reconstructed_name="array_get", evidence_status="71-instruction fixed P2/P12 userdata array getter; false-vs-nil and one-value return pinned")\n    elif pid == "0.29.71":\n')

# Normal CI must regenerate/zero-diff this subsystem map.
replace_once('.github/workflows/phase-d.yml','P029_RUNTIME_HELPER_MAP.json P029_RUNTIME_HELPER_MAP.md P029_AIM_RUNTIME_MAP.json P029_AIM_RUNTIME_MAP.md','P029_RUNTIME_HELPER_MAP.json P029_RUNTIME_HELPER_MAP.md P029_MUTATION_HELPER_MAP.json P029_MUTATION_HELPER_MAP.md P029_AIM_RUNTIME_MAP.json P029_AIM_RUNTIME_MAP.md')

# Validator evidence and focused test registration.
validation=r'''    # Mutation primitive source-ownership checkpoint: exact ABI and fixed captures.
    mutation_paths={'0.29.10','0.29.18','0.29.49'}
    mutation_evidence=json.loads((ROOT/'P029_MUTATION_HELPER_MAP.json').read_text())
    assert mutation_evidence['_meta']['payload_sha256']==PAY
    assert mutation_evidence['_meta']['payload_closure_rebinding'] is False
    assert set(mutation_evidence['_meta']['ownership_boundary'])==mutation_paths
    assert set(mutation_evidence['helpers'])==mutation_paths
    assert mutation_paths <= set(groups['source_owned'])
    assert all(source_files[path]=='src/spectra/mutation_runtime.lua' for path in mutation_paths)
    mutation_shape={'0.29.10':(1,17,1,0),'0.29.18':(1,40,2,0),'0.29.49':(2,71,3,0)}
    mutation_upvalues={'0.29.10':[(0,0)],'0.29.18':[(0,0),(1,19)],'0.29.49':[(0,0),(1,19),(1,32)]}
    mutation_registers={'0.29.10':('R30',325),'0.29.18':('R38',333),'0.29.49':('R74',1034)}
    mutation_captures={'0.29.10':set(),'0.29.18':{('U1','R19','0.29.2')},'0.29.49':{('U1','R19','0.29.2'),('U2','R32','0.29.12')}}
    for path,(params,instructions,upvalues,children) in mutation_shape.items():
        item=prototypes[path]
        assert (item['numparams'],item['instruction_count'],len(item['upvalues']),item['child_count'])==(params,instructions,upvalues,children),path
        assert item['upvalues']==[{'instack':a,'idx':b} for a,b in mutation_upvalues[path]],path
        evidence=mutation_evidence['helpers'][path]
        assert (evidence['p029_parent_register'],evidence['p029_closure_instruction'])==mutation_registers[path]
        assert evidence['current_ownership']=='source_owned' and evidence['source_only_dependency'] is True
        assert evidence['source_file']=='src/spectra/mutation_runtime.lua' and evidence['payload_closure_rebinding'] is False
        captures={(x['upvalue'],x['register'],x['prototype']) for x in evidence['captured_helper_registers']}
        assert captures==mutation_captures[path],(path,captures)
    root29=body('0.29')
    for path,(reg,pc) in mutation_registers.items():
        child=int(path.rsplit('.',1)[1]); assert re.search(rf'^{pc:04d} CLOSURE\s+{reg}, P{child}$',root29,re.M)
    p10=body('0.29.10')
    assert re.search(r"^0003 GETTABUP\s+R1, U0, K0='string'$",p10,re.M)
    assert re.search(r"^0011 SELF\s+R1, R1, K4='gsub'$",p10,re.M)
    assert re.search(r'^0014 TAILCALL\s+A=1 B=4 C=0$',p10,re.M)
    p18=body('0.29.18')
    assert re.search(r"^0011 LOADK\s+R3, K2='TableExtend'$",p18,re.M)
    assert re.search(r'^0022 CALL\s+A=2 B=3 C=3$',p18,re.M)
    assert re.search(r'^0027 CALL\s+A=4 B=2 C=3$',p18,re.M)
    assert re.search(r'^0037 RETURN\s+A=3 B=2 C=0$',p18,re.M) and re.search(r'^0038 RETURN\s+A=0 B=2 C=0$',p18,re.M)
    p49=body('0.29.49')
    assert "'ULuaArrayHelper'" in p49 and "'Get'" in p49
    assert re.search(r'^0009 GETTABLE\s+R2, R0, R2$',p49,re.M) and re.search(r'^0010 RETURN\s+A=2 B=2 C=0$',p49,re.M)
    mutation_source=(ROOT/'src/spectra/mutation_runtime.lua').read_text()
    assert 'return string.lower(tostring(value or "")):gsub("[^%w]", "")' in mutation_source
    assert 'local safe_get = ABI.get' in mutation_source and 'local call_optional_self = ABI.call_optional_self' in mutation_source
    assert 'local ok, extended = pcall(fn, value)' in mutation_source and 'if not ok then ok, extended = pcall(fn) end' in mutation_source
    assert 'function M.array_get(array, index0)' in mutation_source

'''
replace_once('tools/validate_phase_d.py','    coverage_text=(ROOT/\'RECONSTRUCTION_COVERAGE.md\').read_text()\n',validation+'    coverage_text=(ROOT/\'RECONSTRUCTION_COVERAGE.md\').read_text()\n')
replace_once('tools/validate_phase_d.py',"      'visual_runtime.lua':'visual-runtime: ok','mutation_runtime.lua':'mutation-runtime: ok','p029_runtime_helpers.lua':'p029-runtime-helpers: ok','payload_feature_bridge.lua':'payload-feature-bridge: ok',","      'visual_runtime.lua':'visual-runtime: ok','mutation_runtime.lua':'mutation-runtime: ok','p029_runtime_helpers.lua':'p029-runtime-helpers: ok','p029_mutation_primitives.lua':'p029-mutation-primitives: ok','payload_feature_bridge.lua':'payload-feature-bridge: ok',")
replace_once('tools/validate_phase_d.py',"      'phase':'E5.11-p029-71-72-source-only',","      'phase':'E5.12-p029-mutation-primitives-source-only',")
replace_once('tools/validate_phase_d.py',"'p029_aim_runtime_map':'passed','p029_71_exact_parent_child':'passed'","'p029_mutation_helper_map':'passed','p029_mutation_primitive_exact_abi':'passed','p029_aim_runtime_map':'passed','p029_71_exact_parent_child':'passed'")
replace_once('tools/validate_phase_d.py',"'p029_runtime_helpers':True,'p029_aim_runtime':True","'p029_runtime_helpers':True,'p029_mutation_helpers':True,'p029_aim_runtime':True")

print('p029 mutation primitives patch: ok')

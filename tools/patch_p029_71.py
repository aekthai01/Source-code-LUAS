from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(rel, old, new):
    p = ROOT / rel
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    assert count == 1, (rel, count, old[:120])
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


def replace_span(rel, start_marker, end_marker, replacement):
    p = ROOT / rel
    text = p.read_text(encoding='utf-8')
    start = text.index(start_marker)
    end = text.index(end_marker, start)
    p.write_text(text[:start] + replacement + text[end:], encoding='utf-8')

# Exact P0.29.71 / .71.0 source semantics and fixed capture identities.
aim_runtime_block = r'''M.PROTOTYPES = {
    native_aim_state = "0.29.71",
    native_aim_state_apply = "0.29.71.0",
    fire_assisted_debug = "0.29.72",
    fire_assisted_debug_apply = "0.29.72.0",
}

-- P0.29.71 captures the P0.29 parent R0 state table plus exact P0.29.2 and
-- P0.29.12 sibling helpers once when this source module is constructed.
local native_aim_state_029_71 = _G
local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")
local call_optional_self_029_12 = assert(ABI.call_optional_self, "P0.29.12 required")

-- P0.29.72 additionally captures exact P0.29.8 once.
local delay_029_8 = assert(RuntimeHelpers.delay, "P0.29.8 required")

function M.set_native_aim_assist(enabled)
    local state = native_aim_state_029_71
    local saved = state.custom_dongdong_native_aim_state
    if type(saved) ~= "table" then
        saved = {}
        state.custom_dongdong_native_aim_state = saved
    end

    local import_fn = rawget(_G, "import")
    local get_world = rawget(_G, "GetWorld")
    if type(import_fn) ~= "function" or type(get_world) ~= "function" then
        return false
    end

    local ok_class, cls = pcall(import_fn, "ClientBaseSetting")
    local ok_world, world = pcall(get_world)
    if not ok_class or not ok_world or cls == nil or world == nil then
        return false
    end

    local getter = safe_get_029_2(cls, "Get")
    local ok_get, obj = call_optional_self_029_12(getter, cls, world)
    if not ok_get or obj == nil then
        return false
    end

    if saved.saved ~= true then
        saved.saved = true
        saved.value = safe_get_029_2(obj, "bIsAimAssistOpen") == true
    end

    local desired
    if enabled == true then
        desired = true
    else
        desired = saved.value == true
    end

    local ok_set = pcall(function()
        obj.bIsAimAssistOpen = desired
    end)

    local saver = safe_get_029_2(obj, "SaveDataConfig")
    if type(saver) == "function" then
        pcall(saver, obj)
    end

    if enabled ~= true then
        saved.saved = false
    end
    return ok_set
end

'''
replace_span(
    'src/spectra/aim_runtime.lua',
    'M.PROTOTYPES = { native_aim_state = "0.29.71", fire_assisted_debug = "0.29.72", fire_assisted_debug_apply = "0.29.72.0" }\n',
    '-- P0.29.72.0.',
    aim_runtime_block,
)
replace_once(
    'src/spectra/payload_feature_bridge.lua',
    '        return AimRuntime.set_native_aim_assist(_G, enabled)\n',
    '        return AimRuntime.set_native_aim_assist(enabled)\n',
)

# Focused behavioral regression. Every P71 branch checks exact one-value arity.
replace_once(
    'tests/aim_runtime.lua',
    'local root=assert(arg[1])\nlocal S={}\n',
    'local root=assert(arg[1])\nlocal ROOT_ENV=_G\nlocal S={}\n',
)
replace_once(
    'tests/aim_runtime.lua',
    '  _G.Timer=nil; _G.UKismetSystemLibrary=nil; _G.GetGameInstance=nil; _G.import=nil\n',
    '  _G.Timer=nil; _G.UKismetSystemLibrary=nil; _G.GetGameInstance=nil; _G.import=nil; _G.GetWorld=nil\n',
)
p71_tests = r'''-- Exact P71/P71.0 source-owned parent/child behavior.
local function reset_p71()
  reset_engine()
  ROOT_ENV.custom_dongdong_native_aim_state=nil
end
local function install_p71_object(object, world_value)
  local class={Get=function(self,world) return object end}
  ROOT_ENV.import=function(name) eq(name,"ClientBaseSetting","P71 import name"); return class end
  ROOT_ENV.GetWorld=function() return world_value==nil and {} or world_value end
  return class
end
local function p71_result(enabled)
  if enabled==nil then return packed(M.set_native_aim_assist) end
  return packed(M.set_native_aim_assist,enabled)
end

reset_p71()
local missing=p71_result(true)
eq(missing.n,1,"P71 missing import arity"); eq(missing[1],false,"P71 missing import")

reset_p71(); local world_after_import_error=0
ROOT_ENV.import=function() error("import failed") end
ROOT_ENV.GetWorld=function() world_after_import_error=world_after_import_error+1; return {} end
local both_pcalls=p71_result(true)
eq(both_pcalls.n,1,"P71 pcall failure arity"); eq(both_pcalls[1],false,"P71 import failure")
eq(world_after_import_error,1,"P71 GetWorld still called after import exception")

reset_p71(); ROOT_ENV.import=function() return nil end; ROOT_ENV.GetWorld=function() return {} end
local nil_class=p71_result(true); eq(nil_class.n,1,"P71 nil class arity"); eq(nil_class[1],false,"P71 nil class")
reset_p71(); local false_world_seen=false
local false_world_cfg={bIsAimAssistOpen=false,SaveDataConfig=function() end}
ROOT_ENV.import=function()
  return {Get=function(self,world) eq(world,false,"P71 false world forwarded"); false_world_seen=true; return false_world_cfg end}
end
ROOT_ENV.GetWorld=function() return false end
local false_world=p71_result(true)
eq(false_world.n,1,"P71 false world arity"); eq(false_world[1],true,"P71 false world accepted")
truth(false_world_seen,"P71 nil-only world gate")

reset_p71(); local getter_attempts=0; local retry_world={}
local retry_cfg={bIsAimAssistOpen=false,SaveDataConfig=function() end}
local retry_class
retry_class={Get=function(...)
  getter_attempts=getter_attempts+1
  local a=table.pack(...)
  if a.n==2 and a[1]==retry_class then error("self form rejected") end
  eq(a.n,1,"P71 static fallback arg count"); eq(a[1],retry_world,"P71 static fallback world")
  return retry_cfg
end}
ROOT_ENV.import=function() return retry_class end; ROOT_ENV.GetWorld=function() return retry_world end
local retried=p71_result(true)
eq(retried.n,1,"P71 P12 retry arity"); eq(retried[1],true,"P71 P12 retry result")
eq(getter_attempts,2,"P71 P12 self then static")

reset_p71(); local save_calls=0
local cfg={bIsAimAssistOpen=false,SaveDataConfig=function(self) save_calls=save_calls+1 end}
install_p71_object(cfg,{})
local enabled1=p71_result(true); eq(enabled1.n,1,"P71 enable arity"); eq(enabled1[1],true,"P71 enable")
eq(cfg.bIsAimAssistOpen,true,"P71 enabled value")
local state=ROOT_ENV.custom_dongdong_native_aim_state
eq(state.saved,true,"P71 saved marker"); eq(state.value,false,"P71 saved original false")
local enabled2=p71_result(true); eq(enabled2.n,1,"P71 repeated enable arity"); eq(enabled2[1],true)
eq(state.value,false,"P71 repeated enable does not overwrite snapshot")
local disabled=p71_result(false); eq(disabled.n,1,"P71 disable arity"); eq(disabled[1],true,"P71 disable")
eq(cfg.bIsAimAssistOpen,false,"P71 restored value"); eq(state.saved,false,"P71 saved marker cleared")
eq(save_calls,3,"P71 SaveDataConfig each successful setter attempt")

reset_p71(); local strict_cfg={bIsAimAssistOpen=true,SaveDataConfig=function() end}; install_p71_object(strict_cfg,{})
local strict_enable=p71_result(true); eq(strict_enable[1],true); strict_cfg.bIsAimAssistOpen=false
local strict_disable=p71_result(0); eq(strict_disable.n,1,"P71 nontrue arity"); eq(strict_disable[1],true)
eq(strict_cfg.bIsAimAssistOpen,true,"P71 nontrue restores saved true"); eq(ROOT_ENV.custom_dongdong_native_aim_state.saved,false)

reset_p71(); local save_after_set_error=0
local throwing_obj=setmetatable({}, {
  __index=function(_,key)
    if key=="bIsAimAssistOpen" then return false end
    if key=="SaveDataConfig" then return function(self) save_after_set_error=save_after_set_error+1 end end
  end,
  __newindex=function(_,key,value)
    if key=="bIsAimAssistOpen" then error("setter failed") end
    rawset(_,key,value)
  end,
})
install_p71_object(throwing_obj,{})
local setter_fail=p71_result(true)
eq(setter_fail.n,1,"P71 setter failure arity"); eq(setter_fail[1],false,"P71 setter failure result")
eq(save_after_set_error,1,"P71 save still runs after setter failure")

reset_p71(); local save_error_calls=0
local save_error_cfg={bIsAimAssistOpen=false,SaveDataConfig=function(self)
  save_error_calls=save_error_calls+1; error("save failed")
end}
install_p71_object(save_error_cfg,{})
local save_error=p71_result(true)
eq(save_error.n,1,"P71 save error arity"); eq(save_error[1],true,"P71 return is setter pcall result")
eq(save_error_calls,1,"P71 save has no retry")

local old_get,old_optional=ABI.get,ABI.call_optional_self
local replacement_get,replacement_optional=0,0
ABI.get=function() replacement_get=replacement_get+1; error("replacement P2 observed") end
ABI.call_optional_self=function() replacement_optional=replacement_optional+1; error("replacement P12 observed") end
reset_p71(); local fixed_cfg={bIsAimAssistOpen=false,SaveDataConfig=function() end}; install_p71_object(fixed_cfg,{})
local fixed_helpers=p71_result(true)
ABI.get,ABI.call_optional_self=old_get,old_optional
eq(fixed_helpers.n,1,"P71 fixed helper arity"); eq(fixed_helpers[1],true,"P71 fixed helper result")
eq(replacement_get,0,"P71 fixed P2 capture"); eq(replacement_optional,0,"P71 fixed P12 capture")

'''
replace_span(
    'tests/aim_runtime.lua',
    '-- Existing P71 semantic path remains unchanged and is not claimed by this checkpoint.\n',
    '-- P72 command selection is equality to literal true, never generic truthiness.\n',
    p71_tests,
)

# Evidence generator.
replace_once('tools/aim_forensics.py','AIM_RUNTIME = ["0.29.72", "0.29.72.0"]','AIM_RUNTIME = ["0.29.71", "0.29.71.0", "0.29.72", "0.29.72.0"]')
replace_once('tools/aim_forensics.py','assert len(AIM_RUNTIME) == 2','assert len(AIM_RUNTIME) == 4')
replace_once('tools/aim_forensics.py','assert len(ALL) == 51 and len(set(ALL)) == 51','assert len(ALL) == 53 and len(set(ALL)) == 53')
replace_once('tools/aim_forensics.py','    "0.29.13": "R33",\n    "0.29.72": "R97",\n','    "0.29.13": "R33",\n    "0.29.71": "R96",\n    "0.29.72": "R97",\n')
replace_once('tools/aim_forensics.py','        "src/spectra/mutation_runtime.lua: canonical safe_get used throughout active P0.29.68 source path",\n','        "src/spectra/mutation_runtime.lua: canonical safe_get used throughout active P0.29.68 source path",\n        "src/spectra/aim_runtime.lua: P0.29.71 fixed protected field reads",\n')
replace_once('tools/aim_forensics.py','        "src/spectra/mutation_runtime.lua: get_data_table inherits exact P0.29.12 optional-self ABI",\n','        "src/spectra/mutation_runtime.lua: get_data_table inherits exact P0.29.12 optional-self ABI",\n        "src/spectra/aim_runtime.lua: P0.29.71 ClientBaseSetting.Get optional-self call",\n')
replace_once('tools/aim_forensics.py','assert \'local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")\' in source_text["src/spectra/aim_runtime.lua"]\n','assert \'local native_aim_state_029_71 = _G\' in source_text["src/spectra/aim_runtime.lua"]\nassert \'local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")\' in source_text["src/spectra/aim_runtime.lua"]\nassert \'local call_optional_self_029_12 = assert(ABI.call_optional_self, "P0.29.12 required")\' in source_text["src/spectra/aim_runtime.lua"]\nassert \'function M.set_native_aim_assist(enabled)\' in source_text["src/spectra/aim_runtime.lua"]\n')
replace_once('tools/aim_forensics.py','assert \'AimRuntime.set_fire_assisted_aim_debug(enabled)\' in source_text["src/spectra/payload_feature_bridge.lua"]\n','assert \'AimRuntime.set_native_aim_assist(enabled)\' in source_text["src/spectra/payload_feature_bridge.lua"]\nassert \'AimRuntime.set_native_aim_assist(_G, enabled)\' not in source_text["src/spectra/payload_feature_bridge.lua"]\nassert \'AimRuntime.set_fire_assisted_aim_debug(enabled)\' in source_text["src/spectra/payload_feature_bridge.lua"]\n')

runtime_map_block = r'''# Exact P0.29.71/.71.0 and P0.29.72/.72.0 aim-runtime evidence.
p71=P["0.29.71"]
p710=P["0.29.71.0"]
p72=P["0.29.72"]
p720=P["0.29.72.0"]
assert p71["upvalues"] == [{"instack":1,"idx":0},{"instack":0,"idx":0},{"instack":1,"idx":19},{"instack":1,"idx":32}]
assert p710["upvalues"] == [{"instack":1,"idx":10},{"instack":1,"idx":11}]
assert p72["upvalues"] == [{"instack":0,"idx":0},{"instack":1,"idx":19},{"instack":1,"idx":25}]
assert p720["upvalues"] == [{"instack":0,"idx":0},{"instack":0,"idx":1},{"instack":1,"idx":1}]
aim_runtime_map={"_meta":{"source_of_truth":"embedded_payload.bin","payload_sha256":PAYLOAD_SHA,"names_are_reconstructed_semantic_labels":True,"payload_closure_rebinding":False,"ownership_boundary":["0.29.71","0.29.71.0","0.29.72","0.29.72.0"],"excluded_adjacent":["0.29.69","0.29.70","0.29.73"]},"prototypes":{}}
aim_runtime_map["prototypes"]["0.29.71"]={"prototype_id":"0.29.71","numparams":p71["numparams"],"instruction_count":p71["instruction_count"],"upvalues":p71["upvalues"],"child_count":p71["child_count"],"p029_parent_register":root_closures["0.29.71"]["register"],"p029_closure_instruction":root_closures["0.29.71"]["instruction"],"captured_helper_registers":captured_root_helpers("0.29.71"),"captured_state":{"upvalue":"U0","register":"R0","semantic":"P0.29 invocation state table"},"child_prototype":"0.29.71.0","child_closure_register":"R13","child_closure_instruction":88,"source_symbol":"AimRuntime.set_native_aim_assist","source_file":"src/spectra/aim_runtime.lua","return_contract":"exactly one boolean on every reachable parent path; success path returns setter pcall success","branch_order":"captured state table ensure; require import/GetWorld functions; execute both pcalls before checks; nil-specific class/world gates; P2 Get then P12 self-first; one-time snapshot; strict enabled==true desired selection; pcall child assignment; SaveDataConfig protected self call even after setter failure; non-true clears saved; return setter pcall success","source_capture_identity":"fixed P0.29 R0 state table plus fixed P0.29.2 and P0.29.12 identities captured when AimRuntime loads","source_only_dependency":True,"current_ownership":"source_owned","payload_closure_rebinding":False}
aim_runtime_map["prototypes"]["0.29.71.0"]={"prototype_id":"0.29.71.0","numparams":p710["numparams"],"instruction_count":p710["instruction_count"],"upvalues":p710["upvalues"],"child_count":p710["child_count"],"parent_prototype":"0.29.71","parent_capture_mapping":[{"upvalue":"U0","from":"P0.29.71 local R10 ClientBaseSetting instance","descriptor":p710["upvalues"][0]},{"upvalue":"U1","from":"P0.29.71 local R11 desired boolean","descriptor":p710["upvalues"][1]}],"source_symbol":"AimRuntime.set_native_aim_assist nested assignment closure","source_file":"src/spectra/aim_runtime.lua","return_contract":"exactly zero values; parent pcall observes only success/error","branch_order":"assign captured desired boolean to captured object.bIsAimAssistOpen; return zero values","source_capture_identity":"per-parent-call object and desired captures","source_only_dependency":True,"current_ownership":"source_owned","payload_closure_rebinding":False}
aim_runtime_map["prototypes"]["0.29.72"]={"prototype_id":"0.29.72","numparams":p72["numparams"],"instruction_count":p72["instruction_count"],"upvalues":p72["upvalues"],"child_count":p72["child_count"],"p029_parent_register":root_closures["0.29.72"]["register"],"p029_closure_instruction":root_closures["0.29.72"]["instruction"],"captured_helper_registers":captured_root_helpers("0.29.72"),"child_prototype":"0.29.72.0","child_closure_register":"R2","child_closure_instruction":9,"source_symbol":"AimRuntime.set_fire_assisted_aim_debug","source_file":"src/spectra/aim_runtime.lua","return_contract":"exactly one value: immediate P0.29.72.0 boolean result","branch_order":"literal enabled == true selects command 1; create one child; immediate call; P8(0.35,same child); P8(1.2,same child); return immediate","source_capture_identity":"fixed local P0.29.2 and P0.29.8 identities captured when AimRuntime loads","source_only_dependency":True,"current_ownership":"source_owned","payload_closure_rebinding":False}
aim_runtime_map["prototypes"]["0.29.72.0"]={"prototype_id":"0.29.72.0","numparams":p720["numparams"],"instruction_count":p720["instruction_count"],"upvalues":p720["upvalues"],"child_count":p720["child_count"],"parent_prototype":"0.29.72","parent_capture_mapping":[{"upvalue":"U0","from":"P0.29.72 U0 environment","descriptor":p720["upvalues"][0]},{"upvalue":"U1","from":"P0.29.72 U1 / root R19 / P0.29.2","descriptor":p720["upvalues"][1]},{"upvalue":"U2","from":"P0.29.72 local R1 command string","descriptor":p720["upvalues"][2]}],"source_symbol":"AimRuntime.set_fire_assisted_aim_debug nested apply -> execute_console","source_file":"src/spectra/aim_runtime.lua","return_contract":"exactly one boolean on every path","branch_order":"nil-only library import gate; GetGameInstance protected call and nil-only result rejection; fixed P2 ExecuteConsoleCommand lookup; static pcall(gi,command,nil); self fallback pcall(lib,gi,command,nil) only after exception","source_capture_identity":"fixed P0.29.2 identity plus per-parent-call immutable command capture","source_only_dependency":True,"current_ownership":"source_owned","payload_closure_rebinding":False}
(ROOT/"P029_AIM_RUNTIME_MAP.json").write_text(json.dumps(aim_runtime_map,indent=2,ensure_ascii=False)+"\n")
aim_runtime_md=["# P0.29 Aim Runtime Map","",f"Evidence payload SHA-256: `{PAYLOAD_SHA}`.","","This subsystem map source-owns `P0.29.71/.71.0` and `P0.29.72/.72.0`; adjacent P69/P70/P73 ownership is unchanged.","","| Prototype | Parent register | Params | Instructions | Upvalues | Children | Source symbol | Return contract |","|---|---:|---:|---:|---:|---:|---|---|"]
for pid in AIM_RUNTIME:
    e=aim_runtime_map["prototypes"][pid]
    aim_runtime_md.append(f"| `{pid}` | `{e.get('p029_parent_register','nested')}` | {e['numparams']} | {e['instruction_count']} | {len(e['upvalues'])} | {e['child_count']} | `{e['source_symbol']}` | {e['return_contract']} |")
aim_runtime_md += ["","## P0.29.71.0 parent capture map",""]
for cap in aim_runtime_map["prototypes"]["0.29.71.0"]["parent_capture_mapping"]: aim_runtime_md.append(f"- `{cap['upvalue']}` <- {cap['from']}")
aim_runtime_md += ["","## P0.29.72.0 parent capture map",""]
for cap in aim_runtime_map["prototypes"]["0.29.72.0"]["parent_capture_mapping"]: aim_runtime_md.append(f"- `{cap['upvalue']}` <- {cap['from']}")
(ROOT/"P029_AIM_RUNTIME_MAP.md").write_text("\n".join(aim_runtime_md)+"\n")

'''
replace_span('tools/aim_forensics.py','# Exact P0.29.72 parent/child evidence.','index = {\n',runtime_map_block)
replace_once('tools/aim_forensics.py','        "aim_runtime": 2,','        "aim_runtime": 4,')
replace_once('tools/aim_forensics.py','        "indexed_entries_total": 51,','        "indexed_entries_total": 53,')
replace_once('tools/aim_forensics.py','    elif pid == "0.29.72":\n','    elif pid == "0.29.71":\n        item.update(reconstructed_name="set_native_aim_assist", evidence_status="108-instruction R96 parent, fixed R0/P2/P12 captures, one-time snapshot, nested setter pcall, SaveDataConfig ordering and one-boolean return pinned")\n    elif pid == "0.29.71.0":\n        item.update(reconstructed_name="set_native_aim_assist nested assignment", evidence_status="6-instruction child, parent R10/R11 captures, assignment-only body and zero-value return pinned")\n    elif pid == "0.29.72":\n')

# Validator expansion.
validator_block = r'''    # Exact P0.29.71/.71.0 and P0.29.72/.72.0 aim-runtime source ownership checkpoint.
    aim_runtime_paths={'0.29.71','0.29.71.0','0.29.72','0.29.72.0'}
    aim_runtime_evidence=json.loads((ROOT/'P029_AIM_RUNTIME_MAP.json').read_text())
    assert aim_runtime_evidence['_meta']['payload_sha256']==PAY
    assert aim_runtime_evidence['_meta']['payload_closure_rebinding'] is False
    assert set(aim_runtime_evidence['_meta']['ownership_boundary'])==aim_runtime_paths
    assert set(aim_runtime_evidence['prototypes'])==aim_runtime_paths
    assert aim_runtime_paths <= set(groups['source_owned'])
    assert all(source_files[path]=='src/spectra/aim_runtime.lua' for path in aim_runtime_paths)
    assert {'0.29.69','0.29.70','0.29.73'} <= set(groups['payload_owned'])

    p71_meta=prototypes['0.29.71']; p710_meta=prototypes['0.29.71.0']; p72_meta=prototypes['0.29.72']; p720_meta=prototypes['0.29.72.0']
    assert (p71_meta['numparams'],p71_meta['instruction_count'],len(p71_meta['upvalues']),p71_meta['child_count'])==(1,108,4,1)
    assert p71_meta['upvalues']==[{'instack':1,'idx':0},{'instack':0,'idx':0},{'instack':1,'idx':19},{'instack':1,'idx':32}]
    assert (p710_meta['numparams'],p710_meta['instruction_count'],len(p710_meta['upvalues']),p710_meta['child_count'])==(0,6,2,0)
    assert p710_meta['upvalues']==[{'instack':1,'idx':10},{'instack':1,'idx':11}]
    assert (p72_meta['numparams'],p72_meta['instruction_count'],len(p72_meta['upvalues']),p72_meta['child_count'])==(1,22,3,1)
    assert p72_meta['upvalues']==[{'instack':0,'idx':0},{'instack':1,'idx':19},{'instack':1,'idx':25}]
    assert (p720_meta['numparams'],p720_meta['instruction_count'],len(p720_meta['upvalues']),p720_meta['child_count'])==(0,76,3,0)
    assert p720_meta['upvalues']==[{'instack':0,'idx':0},{'instack':0,'idx':1},{'instack':1,'idx':1}]

    p71e=aim_runtime_evidence['prototypes']['0.29.71']; p710e=aim_runtime_evidence['prototypes']['0.29.71.0']
    assert p71e['p029_parent_register']=='R96' and p71e['p029_closure_instruction']==1056
    assert p71e['captured_state']=={'upvalue':'U0','register':'R0','semantic':'P0.29 invocation state table'}
    assert p71e['child_prototype']=='0.29.71.0' and p71e['child_closure_register']=='R13' and p71e['child_closure_instruction']==88
    assert {(x['upvalue'],x['register'],x['prototype']) for x in p71e['captured_helper_registers']}=={('U2','R19','0.29.2'),('U3','R32','0.29.12')}
    assert p71e['source_only_dependency'] is True and p71e['current_ownership']=='source_owned'
    assert p710e['source_only_dependency'] is True and p710e['current_ownership']=='source_owned'
    assert [x['upvalue'] for x in p710e['parent_capture_mapping']]==['U0','U1']

    p71=body('0.29.71')
    assert re.search(r"^0003 GETTABUP\s+R1, U0, K0='custom_dongdong_native_aim_state'$",p71,re.M)
    assert re.search(r'^0035 CALL\s+A=4 B=3 C=3$',p71,re.M) and re.search(r'^0038 CALL\s+A=6 B=2 C=3$',p71,re.M)
    assert re.search(r'^0049 GETUPVAL\s+R8, U2$',p71,re.M) and re.search(r'^0052 CALL\s+A=8 B=3 C=2$',p71,re.M)
    assert re.search(r'^0053 GETUPVAL\s+R9, U3$',p71,re.M) and re.search(r'^0057 CALL\s+A=9 B=4 C=3$',p71,re.M)
    assert re.search(r'^0068 GETUPVAL\s+R11, U2$',p71,re.M)
    assert re.search(r'^0088 CLOSURE\s+R13, P0$',p71,re.M) and re.search(r'^0089 CALL\s+A=12 B=2 C=2$',p71,re.M)
    assert re.search(r'^0090 GETUPVAL\s+R13, U2$',p71,re.M) and re.search(r'^0093 CALL\s+A=13 B=3 C=2$',p71,re.M)
    assert re.search(r'^0102 CALL\s+A=14 B=3 C=1$',p71,re.M)
    assert re.search(r'^0105 SETTABLE\s+R1, K12=\'saved\', K17=False$',p71,re.M)
    assert re.search(r'^0106 RETURN\s+A=12 B=2 C=0$',p71,re.M)
    assert re.search(r'^1056 CLOSURE\s+R96, P71$',body('0.29'),re.M)
    p710=body('0.29.71.0')
    assert re.search(r'^0003 GETUPVAL\s+R0, U1$',p710,re.M)
    assert re.search(r"^0004 SETTABUP\s+U0, K0='bIsAimAssistOpen', R0$",p710,re.M)
    assert re.search(r'^0005 RETURN\s+A=0 B=1 C=0$',p710,re.M)

    p72e=aim_runtime_evidence['prototypes']['0.29.72']; p720e=aim_runtime_evidence['prototypes']['0.29.72.0']
    assert p72e['p029_parent_register']=='R97' and p72e['p029_closure_instruction']==1057
    assert p72e['child_prototype']=='0.29.72.0' and p72e['child_closure_register']=='R2' and p72e['child_closure_instruction']==9
    assert {(x['upvalue'],x['register'],x['prototype']) for x in p72e['captured_helper_registers']}=={('U1','R19','0.29.2'),('U2','R25','0.29.8')}
    assert [x['upvalue'] for x in p720e['parent_capture_mapping']]==['U0','U1','U2']
    p72=body('0.29.72')
    assert re.search(r'^0003 EQ\s+A=0 R0, K0=True$',p72,re.M)
    assert re.search(r'^0009 CLOSURE\s+R2, P0$',p72,re.M) and re.search(r'^0011 CALL\s+A=3 B=1 C=2$',p72,re.M)
    assert re.search(r'^0013 LOADK\s+R5, K3=0\.35$',p72,re.M) and re.search(r'^0017 LOADK\s+R5, K4=1\.2$',p72,re.M)
    assert re.search(r'^0020 RETURN\s+A=3 B=2 C=0$',p72,re.M)
    assert re.search(r'^1057 CLOSURE\s+R97, P72$',body('0.29'),re.M)
    p720=body('0.29.72.0')
    assert re.search(r'^0063 CALL\s+A=5 B=5 C=2$',p720,re.M) and re.search(r'^0072 CALL\s+A=6 B=6 C=2$',p720,re.M)
    assert re.search(r'^0074 RETURN\s+A=5 B=2 C=0$',p720,re.M)

    aim_runtime_source=(ROOT/'src/spectra/aim_runtime.lua').read_text()
    assert 'local native_aim_state_029_71 = _G' in aim_runtime_source
    assert 'local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")' in aim_runtime_source
    assert 'local call_optional_self_029_12 = assert(ABI.call_optional_self, "P0.29.12 required")' in aim_runtime_source
    assert 'function M.set_native_aim_assist(enabled)' in aim_runtime_source
    assert 'function M.set_native_aim_assist(state, enabled)' not in aim_runtime_source
    assert 'p71_safe_get' not in aim_runtime_source and 'p71_invoke' not in aim_runtime_source
    assert 'local delay_029_8 = assert(RuntimeHelpers.delay, "P0.29.8 required")' in aim_runtime_source
    assert 'function M.set_fire_assisted_aim_debug(enabled)' in aim_runtime_source
    assert 'delay_029_8(0.35, apply)' in aim_runtime_source and 'delay_029_8(1.2, apply)' in aim_runtime_source
    assert 'AimRuntime.set_native_aim_assist(_G, enabled)' not in bridge_source
    assert 'AimRuntime.set_native_aim_assist(enabled)' in bridge_source
    assert 'AimRuntime.set_fire_assisted_aim_debug(enabled)' in bridge_source

'''
replace_span('tools/validate_phase_d.py','    # Exact P0.29.72/.72.0 parent-child source ownership checkpoint.\n','    coverage_text=',validator_block)
replace_once('tools/validate_phase_d.py',"      'phase':'E5.10-p029-72-source-only',","      'phase':'E5.11-p029-71-72-source-only',")
replace_once('tools/validate_phase_d.py',"'p029_aim_runtime_map':'passed','p029_72_exact_parent_child':'passed'","'p029_aim_runtime_map':'passed','p029_71_exact_parent_child':'passed','p029_72_exact_parent_child':'passed'")

print('p029-71 patch: ok')

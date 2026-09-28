#!/usr/bin/env python3
"""Generate exact P0.29.73 feature-control ownership evidence.

Run after tools/aim_forensics.py. This bounded generator patches the reviewer-facing
AIM index with P73 ownership and removes P73 from the aim-runtime adjacent-exclusion
note; it does not alter P69/P70/P77 ownership.
"""
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PAYLOAD_SHA="a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263"
P={x["path"]:x for x in json.loads((ROOT/"payload_prototypes.json").read_text())}

def blocks():
    out={}
    text=(ROOT/"payload_disassembly.txt").read_text(encoding="utf-8")
    for piece in re.split(r"^=== PROTO ",text,flags=re.M)[1:]:
        header,*body=piece.splitlines()
        out[header.split(" ",1)[0]]="\n".join(body)
    return out

D=blocks()
p=P["0.29.73"]
expected_upvalues=[
    {"instack":1,"idx":0},
    {"instack":0,"idx":0},
    {"instack":1,"idx":85},
    {"instack":1,"idx":37},
    {"instack":1,"idx":93},
    {"instack":1,"idx":96},
    {"instack":1,"idx":97},
]
assert (p["numparams"],p["instruction_count"],len(p["upvalues"]),p["child_count"])==(2,81,7,0)
assert p["upvalues"]==expected_upvalues

root_closures={}
for line in D["0.29"].splitlines():
    m=re.match(r"^(\d+)\s+CLOSURE\s+R(\d+), P(\d+)$",line)
    if m:
        pc,reg,child=m.groups()
        root_closures[f"0.29.{int(child)}"]={"register":f"R{int(reg)}","instruction":int(pc)}
expected_roots={
    "0.29.17":("R37",332),
    "0.29.60":("R85",1045),
    "0.29.68":("R93",1053),
    "0.29.71":("R96",1056),
    "0.29.72":("R97",1057),
    "0.29.73":("R98",1058),
}
for pid,(reg,pc) in expected_roots.items():
    assert root_closures[pid]=={"register":reg,"instruction":pc},(pid,root_closures.get(pid))

helper_by_register={85:"0.29.60",37:"0.29.17",93:"0.29.68",96:"0.29.71",97:"0.29.72"}
helper_symbols={
    "0.29.60":"MutationRuntime.restore_bone_array_snapshots",
    "0.29.17":"MutationRuntime.restore_feature_snapshot",
    "0.29.68":"MutationRuntime.apply_feature",
    "0.29.71":"AimRuntime.set_native_aim_assist",
    "0.29.72":"AimRuntime.set_fire_assisted_aim_debug",
}
helper_roles={
    "0.29.60":"restore_bone_array_snapshots-equivalent",
    "0.29.17":"restore_feature_snapshot-equivalent",
    "0.29.68":"apply_feature-equivalent",
    "0.29.71":"set_native_aim_assist-equivalent",
    "0.29.72":"set_fire_assisted_aim_debug-equivalent",
}
upvalue_map=[
    {"upvalue":"U0","descriptor":expected_upvalues[0],"register":"R0","prototype":None,"semantic":"captured P0.29 invocation state containing custom_dongdong_toggle_state"},
    {"upvalue":"U1","descriptor":expected_upvalues[1],"register":None,"prototype":None,"semantic":"environment"},
]
for i,descriptor in enumerate(expected_upvalues[2:],start=2):
    reg=descriptor["idx"]; pid=helper_by_register[reg]
    upvalue_map.append({
        "upvalue":f"U{i}","descriptor":descriptor,"register":f"R{reg}","prototype":pid,
        "semantic":helper_roles[pid],"source_symbol":helper_symbols[pid],
    })

source=(ROOT/"src/spectra/feature_control.lua").read_text()
bridge=(ROOT/"src/spectra/payload_feature_bridge.lua").read_text()
assert 'function M.make_feature_config(captured_state, captured_deps)' in source
for needle in (
    'local restore_bone_array_snapshots = need(captured_deps, "restore_bone_array_snapshots")',
    'local restore_feature_snapshot = need(captured_deps, "restore_feature_snapshot")',
    'local apply_feature = need(captured_deps, "apply_feature")',
    'local set_native_aim_assist = need(captured_deps, "set_native_aim_assist")',
    'local set_fire_assisted_aim_debug = need(captured_deps, "set_fire_assisted_aim_debug")',
    'return function(feature, enabled)',
): assert needle in source,needle
assert 'local feature_config_029_73 = FeatureControl.make_feature_config(_G, deps)' in bridge
assert 'make_feature_entry(feature_config_029_73)' in bridge
assert 'make_aim_part_entry(deps, feature_config_029_73)' in bridge
assert 'FeatureControl.set_dongdong_feature_config, _G, deps' not in bridge

entry={
    "prototype_id":"0.29.73",
    "params":p["numparams"],
    "instruction_count":p["instruction_count"],
    "upvalues":p["upvalues"],
    "children":p["child_count"],
    "p029_parent_register":"R98",
    "p029_closure_instruction":1058,
    "exact_upvalue_descriptors":upvalue_map,
    "captured_helper_prototype_register_mapping":[x for x in upvalue_map if x.get("prototype")],
    "source_symbol":"FeatureControl.make_feature_config -> returned set_dongdong_feature_config closure",
    "source_file":"src/spectra/feature_control.lua",
    "exact_source_closure_abi":"function(feature, enabled) -> exactly one boolean on every semantic branch",
    "capture_lifetime":"captured state and U2..U6-equivalent helper identities are fixed when make_feature_config constructs the closure; later dependency-table replacement is not observed",
    "return_contract":"aim/anti_shake true; no_recoil/converge true; every other feature false; exactly one return value",
    "call_order":"aim/anti_shake: U2(), U3(anti_shake), U3(aim), optional U4(aim), U5(active), U6(toggles.aim==true); no_recoil/converge: U3(feature), optional U4(feature)",
    "source_only_dependency":True,
    "current_ownership":"source_owned",
    "payload_closure_rebinding":False,
    "public_symbol_proven_by_bytecode":"set_dongdong_feature_config",
}
artifact={
    "_meta":{
        "source_of_truth":"embedded_payload.bin",
        "payload_sha256":PAYLOAD_SHA,
        "parent_prototype":"0.29",
        "ownership_boundary":["0.29.73"],
        "excluded_adjacent":["0.29.69","0.29.70","0.29.77"],
        "names_are_reconstructed_semantic_labels_except_proven_public_symbol":True,
        "payload_closure_rebinding":False,
    },
    "prototypes":{"0.29.73":entry},
}
(ROOT/"P029_FEATURE_CONTROL_MAP.json").write_text(json.dumps(artifact,indent=2,ensure_ascii=False)+"\n")
md=[
    "# P0.29 Feature-Control Map","",f"Evidence payload SHA-256: `{PAYLOAD_SHA}`.","",
    "This bounded map source-owns only `P0.29.73`. P69/P70 remain payload-owned and P77 ownership/timing is unchanged.","",
    "The public name `set_dongdong_feature_config` is directly proven by the P0.29 bytecode export. Other labels are reconstructed semantics.","",
    "| Upvalue | Descriptor | Root register | Prototype | Reconstructed role / source symbol |",
    "|---|---|---:|---|---|",
]
for x in upvalue_map:
    md.append(f"| `{x['upvalue']}` | `{json.dumps(x['descriptor'],separators=(',',':'))}` | `{x.get('register') or 'outer environment'}` | `{x.get('prototype') or 'n/a'}` | {x['semantic']}" + (f" / `{x['source_symbol']}`" if x.get('source_symbol') else "") + " |")
md += ["","## Exact closure contract","",
    "- Parent closure: `R98`, `CLOSURE` instruction `1058`; 2 params, 81 instructions, 7 upvalues, 0 children.",
    "- Source constructor: `FeatureControl.make_feature_config(captured_state, captured_deps)`; returned closure ABI is exactly `(feature, enabled)`.",
    "- Capture lifetime: state and U2..U6-equivalent helper function identities are fixed at construction.",
    "- Unsupported feature names still receive the literal-true-normalized toggle write and return exactly one `false`, with no restore/apply/native/debug call.",
    "- Payload closure rebinding: `false`.",
]
(ROOT/"P029_FEATURE_CONTROL_MAP.md").write_text("\n".join(md)+"\n")

# Patch the AIM reviewer index produced immediately before this generator.
index_path=ROOT/"AIM_PROTOTYPE_INDEX.json"
index=json.loads(index_path.read_text())
index["prototypes"]["0.29.73"]={
    "category":"feature_control",
    "source":"src/spectra/feature_control.lua",
    "implementation_status":"source-owned after payload init",
    "name_is_original_symbol":True,
    "reconstructed_name":"set_dongdong_feature_config",
    "evidence_status":"81-instruction R98 P73 exact two-parameter closure; seven captures, strict boolean normalization, call order, return arity and fixed capture identity pinned",
}
if "0.29.77" in index["prototypes"]:
    index["prototypes"]["0.29.77"]["evidence_status"]="0.12/0.04/0.10/0.38 delayed sequence; production path consumes the single exact source P73 closure constructed at takeover"
index["_meta"]["feature_control"]=1
index["_meta"]["indexed_entries_total"]=len(index["prototypes"])
index_path.write_text(json.dumps(index,indent=2,ensure_ascii=False)+"\n")

# P73 is no longer an excluded adjacent prototype of the P71/P72 map.
aim_json=ROOT/"P029_AIM_RUNTIME_MAP.json"
aim=json.loads(aim_json.read_text())
aim["_meta"]["excluded_adjacent"]=[x for x in aim["_meta"].get("excluded_adjacent",[]) if x!="0.29.73"]
aim_json.write_text(json.dumps(aim,indent=2,ensure_ascii=False)+"\n")
aim_md=ROOT/"P029_AIM_RUNTIME_MAP.md"
text=aim_md.read_text()
text=text.replace("adjacent P69/P70/P73 ownership is unchanged.","adjacent P69/P70 ownership is unchanged; P73 is tracked by P029_FEATURE_CONTROL_MAP.")
aim_md.write_text(text)
print("p029-feature-control-forensics: ok")

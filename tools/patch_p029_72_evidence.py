#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'tools/aim_forensics.py'
s=p.read_text(encoding='utf-8')

def once(old,new):
    global s
    assert s.count(old)==1, (old[:80],s.count(old))
    s=s.replace(old,new,1)

once('''RUNTIME_HELPERS = ["0.29.5", "0.29.6", "0.29.8", "0.29.11", "0.29.13"]
ALL = [*PRIMARY, *OUTER, *NESTED, *ABI_HELPERS, *RUNTIME_HELPERS]
''','''RUNTIME_HELPERS = ["0.29.5", "0.29.6", "0.29.8", "0.29.11", "0.29.13"]
AIM_RUNTIME = ["0.29.72", "0.29.72.0"]
ALL = [*PRIMARY, *OUTER, *NESTED, *ABI_HELPERS, *RUNTIME_HELPERS, *AIM_RUNTIME]
''')
once('''assert len(RUNTIME_HELPERS) == 5
assert len(ALL) == 49 and len(set(ALL)) == 49
''','''assert len(RUNTIME_HELPERS) == 5
assert len(AIM_RUNTIME) == 2
assert len(ALL) == 51 and len(set(ALL)) == 51
''')
once('''    if pid in RUNTIME_HELPERS:
        return "src/spectra/p029_runtime_helpers.lua"
    if pid.startswith("0.29.77"):
''','''    if pid in RUNTIME_HELPERS:
        return "src/spectra/p029_runtime_helpers.lua"
    if pid in AIM_RUNTIME:
        return "src/spectra/aim_runtime.lua"
    if pid.startswith("0.29.77"):
''')
once('''assert set(RUNTIME_HELPERS) <= set(D)
''','''assert set(RUNTIME_HELPERS) <= set(D)
assert set(AIM_RUNTIME) <= set(D)
''')
once('''    "0.29.13": "R33",
}
''','''    "0.29.13": "R33",
    "0.29.72": "R97",
}
''')
once('''        "src/spectra/visual_scan.lua",
    )
}
''','''        "src/spectra/visual_scan.lua",
        "src/spectra/aim_runtime.lua",
    )
}
''')
once('''assert 'choose("delay", RuntimeHelpers.delay)' in source_text["src/spectra/payload_feature_bridge.lua"]
''','''assert 'choose("delay", RuntimeHelpers.delay)' in source_text["src/spectra/payload_feature_bridge.lua"]
assert 'local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")' in source_text["src/spectra/aim_runtime.lua"]
assert 'local delay_029_8 = assert(RuntimeHelpers.delay, "P0.29.8 required")' in source_text["src/spectra/aim_runtime.lua"]
assert 'delay_029_8(0.35, apply)' in source_text["src/spectra/aim_runtime.lua"]
assert 'delay_029_8(1.2, apply)' in source_text["src/spectra/aim_runtime.lua"]
assert 'AimRuntime.set_fire_assisted_aim_debug(enabled)' in source_text["src/spectra/payload_feature_bridge.lua"]
assert 'AimRuntime.set_fire_assisted_aim_debug(Runtime.delay' not in source_text["src/spectra/payload_feature_bridge.lua"]
''')

once('''RUNTIME_SOURCE_SYMBOLS = {
    "0.29.5": "P029RuntimeHelpers.is_function_field",
    "0.29.6": "P029RuntimeHelpers.object_name",
    "0.29.8": "P029RuntimeHelpers.delay",
    "0.29.11": "P029RuntimeHelpers.get_table_manager",
    "0.29.13": "P029RuntimeHelpers.get_data_table",
}
''','''RUNTIME_SOURCE_SYMBOLS = {
    "0.29.5": "P029RuntimeHelpers.is_function_field",
    "0.29.6": "P029RuntimeHelpers.object_name",
    "0.29.8": "P029RuntimeHelpers.delay",
    "0.29.11": "P029RuntimeHelpers.get_table_manager",
    "0.29.13": "P029RuntimeHelpers.get_data_table",
}
RUNTIME_CAPTURE_IDENTITY = {
    "0.29.5": "fixed local P0.29.2 capture",
    "0.29.6": "fixed local P0.29.3 capture; post-load ABI.self_first replacement is not observed",
    "0.29.8": "fixed local P0.29.2 capture",
    "0.29.11": "fixed local P0.29.2 capture",
    "0.29.13": "fixed local P0.29.11/P0.29.2/P0.29.12 captures; post-load export/ABI replacement is not observed",
}
''')
once('''  "return_contract":RUNTIME_RETURN_CONTRACTS[pid],"retry_or_branch_order":RUNTIME_RETRY_ORDER[pid],
  "source_implementation_symbol":RUNTIME_SOURCE_SYMBOLS[pid],
''','''  "return_contract":RUNTIME_RETURN_CONTRACTS[pid],"retry_or_branch_order":RUNTIME_RETRY_ORDER[pid],
  "source_capture_identity":RUNTIME_CAPTURE_IDENTITY[pid],
  "source_implementation_symbol":RUNTIME_SOURCE_SYMBOLS[pid],
''')

anchor='''(ROOT/"P029_RUNTIME_HELPER_MAP.md").write_text("\\n".join(runtime_md))

index = {
'''
insert='''(ROOT/"P029_RUNTIME_HELPER_MAP.md").write_text("\\n".join(runtime_md))

# Exact P0.29.72 parent/child evidence. The pair is a coherent closure boundary:
# P72 captures root P2/P8, while P72.0 captures the parent's env/P2 and local command.
p72=P["0.29.72"]
p720=P["0.29.72.0"]
assert p72["upvalues"] == [
    {"instack":0,"idx":0}, {"instack":1,"idx":19}, {"instack":1,"idx":25}
]
assert p720["upvalues"] == [
    {"instack":0,"idx":0}, {"instack":0,"idx":1}, {"instack":1,"idx":1}
]
aim_runtime_map={
    "_meta":{
        "source_of_truth":"embedded_payload.bin",
        "payload_sha256":PAYLOAD_SHA,
        "names_are_reconstructed_semantic_labels":True,
        "payload_closure_rebinding":False,
        "ownership_boundary":["0.29.72","0.29.72.0"],
        "excluded_adjacent":["0.29.69","0.29.70","0.29.71","0.29.71.0","0.29.73"],
    },
    "prototypes":{}
}
aim_runtime_map["prototypes"]["0.29.72"]={
    "prototype_id":"0.29.72",
    "numparams":p72["numparams"],"instruction_count":p72["instruction_count"],
    "upvalues":p72["upvalues"],"child_count":p72["child_count"],
    "p029_parent_register":root_closures["0.29.72"]["register"],
    "p029_closure_instruction":root_closures["0.29.72"]["instruction"],
    "captured_helper_registers":captured_root_helpers("0.29.72"),
    "child_prototype":"0.29.72.0","child_closure_register":"R2","child_closure_instruction":9,
    "source_symbol":"AimRuntime.set_fire_assisted_aim_debug",
    "source_file":"src/spectra/aim_runtime.lua",
    "return_contract":"exactly one value: immediate P0.29.72.0 boolean result",
    "branch_order":"literal enabled == true selects command 1; create one child; immediate call; P8(0.35,same child); P8(1.2,same child); return immediate",
    "source_capture_identity":"fixed local P0.29.2 and P0.29.8 identities captured when AimRuntime loads",
    "source_only_dependency":True,"current_ownership":"source_owned","payload_closure_rebinding":False,
}
aim_runtime_map["prototypes"]["0.29.72.0"]={
    "prototype_id":"0.29.72.0",
    "numparams":p720["numparams"],"instruction_count":p720["instruction_count"],
    "upvalues":p720["upvalues"],"child_count":p720["child_count"],
    "parent_prototype":"0.29.72",
    "parent_capture_mapping":[
        {"upvalue":"U0","from":"P0.29.72 U0 environment","descriptor":p720["upvalues"][0]},
        {"upvalue":"U1","from":"P0.29.72 U1 / root R19 / P0.29.2","descriptor":p720["upvalues"][1]},
        {"upvalue":"U2","from":"P0.29.72 local R1 command string","descriptor":p720["upvalues"][2]},
    ],
    "source_symbol":"AimRuntime.set_fire_assisted_aim_debug nested apply -> execute_console",
    "source_file":"src/spectra/aim_runtime.lua",
    "return_contract":"exactly one boolean on every path",
    "branch_order":"nil-only library import gate; GetGameInstance protected call and nil-only result rejection; fixed P2 ExecuteConsoleCommand lookup; static pcall(gi,command,nil); self fallback pcall(lib,gi,command,nil) only after exception",
    "source_capture_identity":"fixed P0.29.2 identity plus per-parent-call immutable command capture",
    "source_only_dependency":True,"current_ownership":"source_owned","payload_closure_rebinding":False,
}
(ROOT/"P029_AIM_RUNTIME_MAP.json").write_text(json.dumps(aim_runtime_map,indent=2,ensure_ascii=False)+"\\n")
aim_runtime_md=[
    "# P0.29 Aim Runtime Map","",f"Evidence payload SHA-256: `{PAYLOAD_SHA}`.","",
    "This checkpoint source-owns only `P0.29.72` and `P0.29.72.0`; adjacent P71/P73 ownership is unchanged.","",
    "| Prototype | Parent register | Params | Instructions | Upvalues | Children | Source symbol | Return contract |",
    "|---|---:|---:|---:|---:|---:|---|---|",
]
for pid in AIM_RUNTIME:
    e=aim_runtime_map["prototypes"][pid]
    aim_runtime_md.append(f"| `{pid}` | `{e.get('p029_parent_register','nested')}` | {e['numparams']} | {e['instruction_count']} | {len(e['upvalues'])} | {e['child_count']} | `{e['source_symbol']}` | {e['return_contract']} |")
aim_runtime_md += ["","## P0.29.72.0 parent capture map",""]
for cap in aim_runtime_map["prototypes"]["0.29.72.0"]["parent_capture_mapping"]:
    aim_runtime_md.append(f"- `{cap['upvalue']}` <- {cap['from']}")
(ROOT/"P029_AIM_RUNTIME_MAP.md").write_text("\\n".join(aim_runtime_md)+"\\n")

index = {
'''
assert s.count(anchor)==1
s=s.replace(anchor,insert,1)

once('''        "runtime_helpers": 5,
        "indexed_entries_total": 49,
''','''        "runtime_helpers": 5,
        "aim_runtime": 2,
        "indexed_entries_total": 51,
''')
once('''    elif pid in RUNTIME_HELPERS:
        category = "runtime_helper"
    elif pid in PRIMARY:
''','''    elif pid in RUNTIME_HELPERS:
        category = "runtime_helper"
    elif pid in AIM_RUNTIME:
        category = "aim_runtime"
    elif pid in PRIMARY:
''')
once('''    elif pid in RUNTIME_HELPERS:
        item.update(
            reconstructed_name=RUNTIME_SOURCE_SYMBOLS[pid],
            evidence_status="exact bytecode shape, root register/captures, source integration and return contract pinned",
        )
    elif pid == "0.29.65":
''','''    elif pid in RUNTIME_HELPERS:
        item.update(
            reconstructed_name=RUNTIME_SOURCE_SYMBOLS[pid],
            evidence_status="exact bytecode shape, root register/captures, source integration, capture identity and return contract pinned",
        )
    elif pid == "0.29.72":
        item.update(
            reconstructed_name="set_fire_assisted_aim_debug",
            evidence_status="22-instruction parent, R97 closure, fixed P2/P8 captures, literal-true command selection, same child immediate/0.35/1.2 schedule and one-value return pinned",
        )
    elif pid == "0.29.72.0":
        item.update(
            reconstructed_name="set_fire_assisted_aim_debug child execute_console",
            evidence_status="76-instruction child, env/P2/command captures, nil-only gates, exact static/self pcall arity and boolean return pinned",
        )
    elif pid == "0.29.65":
''')
once('''    f"{len(ABI_HELPERS)} ABI helpers + {len(RUNTIME_HELPERS)} runtime helpers)"
''','''    f"{len(ABI_HELPERS)} ABI helpers + {len(RUNTIME_HELPERS)} runtime helpers + {len(AIM_RUNTIME)} aim-runtime)"
''')

p.write_text(s,encoding='utf-8')
print('patched P0.29.72 evidence generator')

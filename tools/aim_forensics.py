#!/usr/bin/env python3
"""Reproducible runtime-status index for the verified aim reconstruction.

The detailed structural index from the pre-takeover checkpoint is preserved as
AIM_PROTOTYPE_INDEX_LEGACY_DETAILED.json. This generator emits the current,
reviewer-facing implementation/ownership map and verifies every indexed prototype
still exists in payload_prototypes.json.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD_SHA = "a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263"
P = {x["path"]: x for x in json.loads((ROOT / "payload_prototypes.json").read_text())}

PRIMARY = [
    *(f"0.29.{i}" for i in range(30, 46)),
    *(f"0.29.{i}" for i in range(61, 67)),
    *(f"0.29.{i}" for i in range(74, 78)),
]
OUTER = ["0.29.67", "0.29.68"]
NESTED = [
    "0.29.17.0",
    "0.29.62.0",
    "0.29.64.0",
    "0.29.66.0",
    "0.29.67.0",
    "0.29.67.0.0",
    "0.29.74.0",
    "0.29.76.0",
    "0.29.77.0",
    "0.29.77.0.0",
    "0.29.77.0.0.0",
    "0.29.77.0.0.0.0",
]
ABI_HELPERS = ["0.29.2", "0.29.2.0", "0.29.3", "0.29.4", "0.29.12"]
RUNTIME_HELPERS = ["0.29.5", "0.29.6", "0.29.8", "0.29.11", "0.29.13"]
MUTATION_HELPERS = ["0.29.10", "0.29.18", "0.29.49"]
AIM_RUNTIME = ["0.29.71", "0.29.71.0", "0.29.72", "0.29.72.0"]
ALL = [*PRIMARY, *OUTER, *NESTED, *ABI_HELPERS, *RUNTIME_HELPERS, *MUTATION_HELPERS, *AIM_RUNTIME]
assert len(PRIMARY) == 26
assert len(OUTER) == 2
assert len(NESTED) == 12
assert len(ABI_HELPERS) == 5
assert len(RUNTIME_HELPERS) == 5
assert len(MUTATION_HELPERS) == 3
assert len(AIM_RUNTIME) == 4
assert len(ALL) == 57 and len(set(ALL)) == 57
missing = [pid for pid in ALL if pid not in P]
assert not missing, f"missing payload prototypes: {missing}"


def source_for(pid):
    if pid in ABI_HELPERS:
        return "src/spectra/aim_abi.lua"
    if pid in RUNTIME_HELPERS:
        return "src/spectra/p029_runtime_helpers.lua"
    if pid in MUTATION_HELPERS:
        return "src/spectra/mutation_runtime.lua"
    if pid in AIM_RUNTIME:
        return "src/spectra/aim_runtime.lua"
    if pid == "0.29.17.0":
        return "src/spectra/mutation_runtime.lua"
    if pid.startswith("0.29.77"):
        return "src/spectra/feature_control.lua"
    if pid.startswith(("0.29.74", "0.29.75", "0.29.76")):
        return "src/spectra/aim_refresh.lua"
    if pid.startswith(("0.29.66", "0.29.67")):
        return "src/spectra/aim_chain.lua"
    if pid == "0.29.68":
        return "src/spectra/mutation_runtime.lua"
    if pid == "0.29.45" or pid.startswith(("0.29.61", "0.29.62", "0.29.63", "0.29.64")):
        return "src/spectra/aim_bones.lua"
    if pid == "0.29.44":
        return "src/spectra/mutation_runtime.lua"
    if pid.startswith(tuple(f"0.29.{i}" for i in range(30, 44))) or pid == "0.29.65":
        return "src/spectra/aim_mutation.lua"
    raise AssertionError(f"unmapped source for {pid}")


def disassembly_blocks():
    text = (ROOT / "payload_disassembly.txt").read_text(encoding="utf-8")
    blocks = {}
    for piece in re.split(r"^=== PROTO ", text, flags=re.M)[1:]:
        header, *body = piece.splitlines()
        blocks[header.split(" ", 1)[0]] = "\n".join(body)
    return blocks


D = disassembly_blocks()
assert set(ABI_HELPERS) <= set(D)
assert set(RUNTIME_HELPERS) <= set(D)
assert set(MUTATION_HELPERS) <= set(D)
assert set(AIM_RUNTIME) <= set(D)

# Mechanically derive the root P0.29 child closure registers. These are not
# reconstructed names; they are bytecode register identities at closure creation.
root_closures = {}
for line in D["0.29"].splitlines():
    match = re.match(r"^(\d+)\s+CLOSURE\s+R(\d+), P(\d+)$", line)
    if match:
        instruction, register, child = match.groups()
        root_closures[f"0.29.{int(child)}"] = {
            "register": f"R{int(register)}",
            "instruction": int(instruction),
        }
expected_root_registers = {
    "0.29.2": "R19",
    "0.29.3": "R20",
    "0.29.4": "R21",
    "0.29.5": "R22",
    "0.29.6": "R23",
    "0.29.8": "R25",
    "0.29.11": "R31",
    "0.29.12": "R32",
    "0.29.13": "R33",
    "0.29.10": "R30",
    "0.29.18": "R38",
    "0.29.49": "R74",
    "0.29.71": "R96",
    "0.29.72": "R97",
}
for pid, register in expected_root_registers.items():
    assert root_closures[pid]["register"] == register, (pid, root_closures.get(pid))

# P0.29.2.0 is nested under P0.29.2 and captures that parent's argument R0/R1.
assert P["0.29.2.0"]["upvalues"] == [
    {"instack": 1, "idx": 0}, {"instack": 1, "idx": 1}
]


def direct_root_capture_consumers(target_pid):
    """Find direct P0.29 child closures that capture a target root register.

    The result is capture evidence, not a claim that payload closures were rebound.
    A best-effort direct CALL/TAILCALL site is included when the captured upvalue is
    loaded into a function register and invoked in the same stripped prototype.
    """
    root_register = int(root_closures[target_pid]["register"][1:])
    result = []
    for pid in sorted(P, key=lambda x: [int(part) for part in x.split(".")]):
        if not re.fullmatch(r"0\.29\.\d+", pid):
            continue
        item = P[pid]
        for upvalue_index, descriptor in enumerate(item["upvalues"]):
            if descriptor != {"instack": 1, "idx": root_register}:
                continue
            lines = D[pid].splitlines()
            call_sites = []
            for index, line in enumerate(lines):
                loaded = re.match(r"^(\d+)\s+GETUPVAL\s+R(\d+), U" + str(upvalue_index) + r"$", line)
                if not loaded:
                    continue
                register = int(loaded.group(2))
                aliases = {register}
                for follow in lines[index + 1:index + 12]:
                    move = re.match(r"^(\d+)\s+MOVE\s+R(\d+), R(\d+)$", follow)
                    if move and int(move.group(3)) in aliases:
                        aliases.add(int(move.group(2)))
                    call = re.match(r"^(\d+)\s+(CALL|TAILCALL)\s+A=(\d+)\b", follow)
                    if call and int(call.group(3)) in aliases:
                        call_sites.append({"instruction": int(call.group(1)), "opcode": call.group(2)})
                        break
            result.append({
                "prototype": pid,
                "upvalue": f"U{upvalue_index}",
                "direct_call_sites": call_sites,
            })
    return result


root_register_to_pid = {int(v["register"][1:]): k for k,v in root_closures.items()}
def captured_root_helpers(pid):
    result=[]
    for i,d in enumerate(P[pid]["upvalues"]):
        if d.get("instack") != 1: continue
        target=root_register_to_pid.get(d.get("idx"))
        if target is not None:
            result.append({"upvalue":f"U{i}","register":f"R{d['idx']}","prototype":target})
    return result


# Concrete source consumers. The files are inspected here so evidence generation
# fails if these source-owned paths stop using the reconstructed ABI helpers.
source_text = {
    name: (ROOT / name).read_text(encoding="utf-8")
    for name in (
        "src/spectra/aim_refresh.lua",
        "src/spectra/aim_chain.lua",
        "src/spectra/aim_mutation.lua",
        "src/spectra/payload_feature_bridge.lua",
        "src/spectra/feature_control.lua",
        "src/spectra/mutation_runtime.lua",
        "src/spectra/p029_runtime_helpers.lua",
        "src/spectra/visual_scan.lua",
        "src/spectra/aim_runtime.lua",
    )
}
assert "local safe_get = ABI.get" in source_text["src/spectra/aim_refresh.lua"]
assert "ABI.self_first" in source_text["src/spectra/aim_refresh.lua"]
assert "ABI.static_first" in source_text["src/spectra/aim_refresh.lua"]
assert "ABI.call_optional_self" in source_text["src/spectra/aim_refresh.lua"]
assert "AimABI.get" in source_text["src/spectra/aim_chain.lua"]
assert "read_field = AimABI.get" in source_text["src/spectra/payload_feature_bridge.lua"]
assert "deps.read_field" in source_text["src/spectra/aim_mutation.lua"]
assert "AimABI" not in source_text["src/spectra/feature_control.lua"]
assert 'local ABI = assert(S.AimABI, "AimABI required")' in source_text["src/spectra/p029_runtime_helpers.lua"]
assert 'local safe_get = ABI.get' in source_text["src/spectra/mutation_runtime.lua"]
assert 'local call_optional_self = ABI.call_optional_self' in source_text["src/spectra/mutation_runtime.lua"]
assert 'M.get_table_manager = RuntimeHelpers.get_table_manager' in source_text["src/spectra/mutation_runtime.lua"]
assert 'M.get_data_table = RuntimeHelpers.get_data_table' in source_text["src/spectra/mutation_runtime.lua"]
assert 'local object_name = RuntimeHelpers.object_name' in source_text["src/spectra/visual_scan.lua"]
assert 'RuntimeHelpers.is_function_field' in source_text["src/spectra/visual_scan.lua"]
assert 'choose("delay", RuntimeHelpers.delay)' in source_text["src/spectra/payload_feature_bridge.lua"]
assert 'local native_aim_state_029_71 = _G' in source_text["src/spectra/aim_runtime.lua"]
assert 'local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")' in source_text["src/spectra/aim_runtime.lua"]
assert 'local call_optional_self_029_12 = assert(ABI.call_optional_self, "P0.29.12 required")' in source_text["src/spectra/aim_runtime.lua"]
assert 'function M.set_native_aim_assist(enabled)' in source_text["src/spectra/aim_runtime.lua"]
assert 'local delay_029_8 = assert(RuntimeHelpers.delay, "P0.29.8 required")' in source_text["src/spectra/aim_runtime.lua"]
assert 'delay_029_8(0.35, apply)' in source_text["src/spectra/aim_runtime.lua"]
assert 'delay_029_8(1.2, apply)' in source_text["src/spectra/aim_runtime.lua"]
assert 'AimRuntime.set_native_aim_assist(enabled)' in source_text["src/spectra/payload_feature_bridge.lua"]
assert 'AimRuntime.set_native_aim_assist(_G, enabled)' not in source_text["src/spectra/payload_feature_bridge.lua"]
assert 'AimRuntime.set_fire_assisted_aim_debug(enabled)' in source_text["src/spectra/payload_feature_bridge.lua"]
assert 'AimRuntime.set_fire_assisted_aim_debug(Runtime.delay' not in source_text["src/spectra/payload_feature_bridge.lua"]

SOURCE_CONSUMERS = {
    "0.29.2": [
        "src/spectra/aim_refresh.lua: AimRefresh.collect_targets/refresh_methods/init_current_weapon",
        "src/spectra/aim_chain.lua: AimChain.walk_and_patch/apply_aim_row",
        "src/spectra/payload_feature_bridge.lua: default_dependencies read_field injection",
        "src/spectra/aim_mutation.lua: replacement consumes injected deps.read_field",
        "src/spectra/mutation_runtime.lua: canonical safe_get used throughout active P0.29.68 source path",
        "src/spectra/aim_runtime.lua: P0.29.71 fixed protected field reads",
    ],
    "0.29.2.0": [
        "src/spectra/aim_abi.lua: nested raw owner[key] closure inside AimABI.get",
    ],
    "0.29.3": [
        "src/spectra/aim_refresh.lua: invoke(self_first=true) used by collect_targets/refresh_methods",
    ],
    "0.29.4": [
        "src/spectra/aim_refresh.lua: invoke(self_first=false) used by collect_targets/init_current_weapon",
    ],
    "0.29.12": [
        "src/spectra/aim_refresh.lua: collect_targets FindComponentByClass optional-self call",
        "src/spectra/mutation_runtime.lua: get_data_table inherits exact P0.29.12 optional-self ABI",
        "src/spectra/aim_runtime.lua: P0.29.71 ClientBaseSetting.Get optional-self call",
    ],
}
RUNTIME_SOURCE_CONSUMERS = {
    "0.29.5": ["src/spectra/visual_scan.lua: P0.29.81 is_mesh_component SetMaterial/SetOverlayMaterial predicates"],
    "0.29.6": ["src/spectra/visual_scan.lua: P0.29.85 is_ai_actor object-name normalization"],
    "0.29.8": ["src/spectra/payload_feature_bridge.lua: P0.29.77 delay dependency injection"],
    "0.29.11": ["src/spectra/mutation_runtime.lua: get_table_manager/get_data_table/apply_feature"],
    "0.29.13": [
        "src/spectra/mutation_runtime.lua: get_data_table/apply_feature",
        "src/spectra/aim_bones.lua: refresh_bone_table consumes MutationRuntime.get_data_table",
    ],
}
RUNTIME_RETURN_CONTRACTS = {
    "0.29.5": "exactly one boolean: true only when protected field value has type function",
    "0.29.6": "nil input returns exactly one empty string; successful/fallback tostring is a tail return",
    "0.29.8": "exactly zero values on every normal path",
    "0.29.11": "exactly one value: truthy Facade.TableManager or raw global TableManager fallback",
    "0.29.13": "exactly one value: GetTable first result on success, otherwise nil",
}
RUNTIME_RETRY_ORDER = {
    "0.29.5": "P0.29.2 protected lookup then strict type(value)==function",
    "0.29.6": "GetFullName then GetName via P0.29.3 self-first ABI; final tostring fallback",
    "0.29.8": "missing/non-function DelayCall invokes callback immediately; otherwise static pcall then self fallback after exception; errors discarded",
    "0.29.11": "rawget Facade; P0.29.2 TableManager lookup; truthy branch; raw global fallback",
    "0.29.13": "P0.29.11 manager; P0.29.2 GetTable; P0.29.12 self-first call; ok branch returns value",
}
RUNTIME_SOURCE_SYMBOLS = {
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

RETURN_CONTRACTS = {
    "0.29.2": "exactly one value: truthy field value or nil; false/nil/error collapse to nil",
    "0.29.2.0": "exactly one value: raw owner[key]; no nil guard; parent pcall owns exceptions",
    "0.29.3": "missing/both-fail: exactly false,nil; success: exactly true,result1,result2",
    "0.29.4": "missing/both-fail: exactly false,nil; success: exactly true,result1,result2",
    "0.29.12": "all paths exactly two values; success true,result1; fallback failure false,error",
}
RETRY_ORDER = {
    "0.29.2": "single protected lookup",
    "0.29.2.0": "none",
    "0.29.3": "self-first pcall, then static pcall only after first exception",
    "0.29.4": "static-first pcall, then self pcall only after first exception",
    "0.29.12": "self-first pcall, then static pcall only after first exception",
}
SOURCE_SYMBOLS = {
    "0.29.2": "AimABI.get",
    "0.29.2.0": "AimABI.get nested protected lookup closure",
    "0.29.3": "AimABI.self_first",
    "0.29.4": "AimABI.static_first",
    "0.29.12": "AimABI.call_optional_self",
}

abi_map = {
    "_meta": {
        "source_of_truth": "embedded_payload.bin",
        "payload_sha256": PAYLOAD_SHA,
        "parent_prototype": "0.29",
        "names_are_reconstructed_semantic_labels": True,
        "payload_closure_rebinding": False,
        "ownership_model": (
            "source-owned consumers call src/spectra/aim_abi.lua directly; unreconstructed "
            "payload-owned callers may continue using their captured payload helper closures"
        ),
    },
    "helpers": {},
    "inspected_source_files": list(source_text),
}
for pid in ABI_HELPERS:
    item = P[pid]
    entry = {
        "prototype_id": pid,
        "instruction_count": item["instruction_count"],
        "numparams": item["numparams"],
        "upvalues": item["upvalues"],
        "children": item["child_count"],
        "p029_parent_register": root_closures.get(pid, {}).get("register"),
        "p029_closure_instruction": root_closures.get(pid, {}).get("instruction"),
        "known_payload_capture_consumers": (
            direct_root_capture_consumers(pid) if pid in root_closures else []
        ),
        "known_source_consumers": SOURCE_CONSUMERS[pid],
        "return_contract": RETURN_CONTRACTS[pid],
        "retry_order": RETRY_ORDER[pid],
        "source_implementation_symbol": SOURCE_SYMBOLS[pid],
        "source_file": "src/spectra/aim_abi.lua",
        "source_only_dependency": True,
        "name_is_original_symbol": False,
    }
    if pid == "0.29.2.0":
        entry["parent_prototype"] = "0.29.2"
        entry["parent_local_capture_registers"] = ["R0", "R1"]
    abi_map["helpers"][pid] = entry

(ROOT / "P029_ABI_HELPER_MAP.json").write_text(
    json.dumps(abi_map, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

md = [
    "# P0.29 ABI Helper Map", "",
    f"Evidence payload SHA-256: `{PAYLOAD_SHA}`.", "",
    "Names below are reconstructed semantic labels, not recovered stripped debug symbols.", "",
    "The source-owned boundary is deliberately non-invasive: source-owned consumers call `src/spectra/aim_abi.lua` directly. Existing payload helper closures are not dynamically rebound; unreconstructed payload-owned callers may continue using captured payload copies.", "",
    "| Prototype | P0.29 register | Params | Instructions | Upvalues | Children | Source symbol | Return contract | Retry order |",
    "|---|---:|---:|---:|---:|---:|---|---|---|",
]
for pid in ABI_HELPERS:
    entry = abi_map["helpers"][pid]
    md.append(
        f"| `{pid}` | `{entry['p029_parent_register'] or 'nested'}` | {entry['numparams']} | "
        f"{entry['instruction_count']} | {len(entry['upvalues'])} | {entry['children']} | "
        f"`{entry['source_implementation_symbol']}` | {entry['return_contract']} | {entry['retry_order']} |"
    )
md += ["", "## Known source consumers", ""]
for pid in ABI_HELPERS:
    md.append(f"### `{pid}`")
    md.extend(f"- {value}" for value in SOURCE_CONSUMERS[pid])
    md.append("")
md += ["## Mechanically derived payload capture consumers", ""]
for pid in ABI_HELPERS:
    md.append(f"### `{pid}`")
    consumers = abi_map["helpers"][pid]["known_payload_capture_consumers"]
    if not consumers:
        md.append("- None at the direct P0.29 child-capture layer.")
    else:
        for consumer in consumers:
            calls = ", ".join(
                f"{call['opcode']}@{call['instruction']}" for call in consumer["direct_call_sites"]
            ) or "capture observed; no direct call site proven by the local scan"
            md.append(f"- `{consumer['prototype']}` `{consumer['upvalue']}`: {calls}")
    md.append("")
(ROOT / "P029_ABI_HELPER_MAP.md").write_text("\n".join(md), encoding="utf-8")

runtime_map={
 "_meta":{
  "source_of_truth":"embedded_payload.bin","payload_sha256":PAYLOAD_SHA,"parent_prototype":"0.29",
  "names_are_reconstructed_semantic_labels":True,"payload_closure_rebinding":False,
  "ownership_model":"source-owned callers use src/spectra/p029_runtime_helpers.lua directly; payload-owned callers retain captured payload closures",
  "mutation_runtime_integration":{
   "canonical_get":"AimABI.get","canonical_optional_self":"AimABI.call_optional_self",
   "table_manager":"P029RuntimeHelpers.get_table_manager","get_data_table":"P029RuntimeHelpers.get_data_table"}},
 "helpers":{},"inspected_source_files":list(source_text)}
for pid in RUNTIME_HELPERS:
 item=P[pid]
 runtime_map["helpers"][pid]={
  "prototype_id":pid,"instruction_count":item["instruction_count"],"numparams":item["numparams"],
  "upvalues":item["upvalues"],"child_count":item["child_count"],
  "p029_parent_register":root_closures[pid]["register"],
  "p029_closure_instruction":root_closures[pid]["instruction"],
  "captured_helper_registers":captured_root_helpers(pid),
  "known_payload_capture_consumers":direct_root_capture_consumers(pid),
  "known_source_consumers":RUNTIME_SOURCE_CONSUMERS[pid],
  "return_contract":RUNTIME_RETURN_CONTRACTS[pid],"retry_or_branch_order":RUNTIME_RETRY_ORDER[pid],
  "source_capture_identity":RUNTIME_CAPTURE_IDENTITY[pid],
  "source_implementation_symbol":RUNTIME_SOURCE_SYMBOLS[pid],
  "source_file":"src/spectra/p029_runtime_helpers.lua",
  "source_implementation_exists":True,"current_ownership":"source_owned",
  "active_source_consumer":True,"payload_closure_rebinding":False,
  "source_only_dependency":True,"name_is_original_symbol":False}
(ROOT/"P029_RUNTIME_HELPER_MAP.json").write_text(json.dumps(runtime_map,indent=2,ensure_ascii=False)+"\n")
runtime_md=["# P0.29 Runtime Helper Map","",f"Evidence payload SHA-256: `{PAYLOAD_SHA}`.","",
 "Names are reconstructed semantic labels, not recovered stripped symbols.","",
 "Payload closures are not dynamically rebound. Source-owned callers use exact source helpers directly.","",
 "| Prototype | Register | Params | Instructions | Upvalues | Source symbol | Return contract |",
 "|---|---:|---:|---:|---:|---|---|"]
for pid in RUNTIME_HELPERS:
 e=runtime_map["helpers"][pid]
 runtime_md.append(f"| `{pid}` | `{e['p029_parent_register']}` | {e['numparams']} | {e['instruction_count']} | {len(e['upvalues'])} | `{e['source_implementation_symbol']}` | {e['return_contract']} |")
runtime_md += ["","## MutationRuntime integration","",
 "- `MutationRuntime.safe_get` reuses `AimABI.get`.",
 "- `MutationRuntime.call_optional_self` reuses `AimABI.call_optional_self`.",
 "- `MutationRuntime.get_table_manager` / `get_data_table` reuse P0.29.11 / P0.29.13 source helpers.",
 "","## Source consumers",""]
for pid in RUNTIME_HELPERS:
 runtime_md.append(f"### `{pid}`")
 runtime_md.extend(f"- {v}" for v in RUNTIME_SOURCE_CONSUMERS[pid]); runtime_md.append("")
(ROOT/"P029_RUNTIME_HELPER_MAP.md").write_text("\n".join(runtime_md))

# Exact P0.29.71/.71.0 and P0.29.72/.72.0 aim-runtime evidence.
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

# Reusable source-ownership evidence for mutation primitives. Later bone-array
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

index = {
    "_meta": {
        "source_of_truth": "embedded_payload.bin",
        "payload_sha256": PAYLOAD_SHA,
        "primary_requested_prototypes": 26,
        "outer_dispatch_prototypes": 2,
        "nested_callbacks": 12,
        "abi_helpers": 5,
        "runtime_helpers": 5,
        "mutation_helpers": 3,
        "aim_runtime": 4,
        "indexed_entries_total": 57,
        "detailed_legacy_index": "AIM_PROTOTYPE_INDEX_LEGACY_DETAILED.json",
        "runtime_ownership": {"aim": True, "anti_shake": True},
        "game_runtime_test": False,
        "note": "Names are reconstructed descriptions unless an exact public/global symbol is stated.",
    },
    "prototypes": {},
}

for pid in ALL:
    if pid in ABI_HELPERS:
        category = "abi_helper"
    elif pid in RUNTIME_HELPERS:
        category = "runtime_helper"
    elif pid in AIM_RUNTIME:
        category = "aim_runtime"
    elif pid in PRIMARY:
        category = "primary_requested"
    elif pid in OUTER:
        category = "outer_dispatch"
    else:
        category = "nested_callback"
    item = {
        "category": category,
        "source": source_for(pid),
        "implementation_status": (
            "source-owned helper; payload closure copy not rebound for unreconstructed payload callers"
            if category in {"abi_helper", "runtime_helper"}
            else "source-owned after payload init"
            if category != "nested_callback"
            else "source-reconstructed and owned through reconstructed parent flow"
        ),
        "name_is_original_symbol": False,
    }
    if pid in ABI_HELPERS:
        item.update(
            reconstructed_name=SOURCE_SYMBOLS[pid],
            evidence_status="exact return arity, retry order, root register/capture and source-consumer evidence pinned",
        )
    elif pid in RUNTIME_HELPERS:
        item.update(
            reconstructed_name=RUNTIME_SOURCE_SYMBOLS[pid],
            evidence_status="exact bytecode shape, root register/captures, source integration, capture identity and return contract pinned",
        )
    elif pid == "0.29.17.0":
        item.update(reconstructed_name="restore_feature_snapshot assignment child", evidence_status="8-instruction P17 child; captures parent R8 record; object/key/value assignment; zero-value return pinned")
    elif pid == "0.29.10":
        item.update(reconstructed_name="normalize_identifier", evidence_status="17-instruction environment-only gsub tail-return helper; two-value return pinned")
    elif pid == "0.29.18":
        item.update(reconstructed_name="table_extend", evidence_status="40-instruction fixed P2 lookup and exception-only static retry; one-value return pinned")
    elif pid == "0.29.49":
        item.update(reconstructed_name="array_get", evidence_status="71-instruction fixed P2/P12 userdata array getter; false-vs-nil and one-value return pinned")
    elif pid == "0.29.71":
        item.update(reconstructed_name="set_native_aim_assist", evidence_status="108-instruction R96 parent, fixed R0/P2/P12 captures, one-time snapshot, nested setter pcall, SaveDataConfig ordering and one-boolean return pinned")
    elif pid == "0.29.71.0":
        item.update(reconstructed_name="set_native_aim_assist nested assignment", evidence_status="6-instruction child, parent R10/R11 captures, assignment-only body and zero-value return pinned")
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
        item.update(
            reconstructed_name="replace_aim_field",
            evidence_status="842-instruction replacement rules differential-tested",
        )
    elif pid == "0.29.66":
        item.update(
            reconstructed_name="walk_and_patch_aim_field",
            evidence_status="recursive depth-13 walker; bone fields skipped; transactional failure reporting tested",
        )
    elif pid == "0.29.67":
        item.update(
            reconstructed_name="apply_aim_row / per-table dispatcher",
            evidence_status="AimAssistorId plus exact row-name fallback; P63 then P66 chain tested",
        )
    elif pid == "0.29.68":
        item.update(
            reconstructed_name="apply_feature",
            evidence_status="38 instructions matched: captured feature list, ipairs order, P13 lookup, raw table identity dedupe, P67 dispatch, boolean return, no internal pcall",
        )
    elif pid == "0.29.77":
        item.update(
            reconstructed_name="set_dongdong_aim_part",
            evidence_status="0.12/0.04/0.10/0.38 delayed sequence; source P73 captured consistently",
        )
    index["prototypes"][pid] = item

(ROOT / "AIM_PROTOTYPE_INDEX.json").write_text(
    json.dumps(index, indent=2, ensure_ascii=False) + "\n"
)
print(
    f"indexed {len(index['prototypes'])} prototypes "
    f"({len(PRIMARY)} primary + {len(OUTER)} outer + {len(NESTED)} nested + "
    f"{len(ABI_HELPERS)} ABI helpers + {len(RUNTIME_HELPERS)} runtime helpers + {len(AIM_RUNTIME)} aim-runtime)"
)

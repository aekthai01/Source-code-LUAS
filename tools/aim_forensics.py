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
ALL = [*PRIMARY, *OUTER, *NESTED, *ABI_HELPERS]
assert len(PRIMARY) == 26
assert len(OUTER) == 2
assert len(NESTED) == 11
assert len(ABI_HELPERS) == 5
assert len(ALL) == 44 and len(set(ALL)) == 44
missing = [pid for pid in ALL if pid not in P]
assert not missing, f"missing payload prototypes: {missing}"


def source_for(pid):
    if pid in ABI_HELPERS:
        return "src/spectra/aim_abi.lua"
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
    "0.29.12": "R32",
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

SOURCE_CONSUMERS = {
    "0.29.2": [
        "src/spectra/aim_refresh.lua: AimRefresh.collect_targets/refresh_methods/init_current_weapon",
        "src/spectra/aim_chain.lua: AimChain.walk_and_patch/apply_aim_row",
        "src/spectra/payload_feature_bridge.lua: default_dependencies read_field injection",
        "src/spectra/aim_mutation.lua: replacement consumes injected deps.read_field",
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
    ],
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

index = {
    "_meta": {
        "source_of_truth": "embedded_payload.bin",
        "payload_sha256": PAYLOAD_SHA,
        "primary_requested_prototypes": 26,
        "outer_dispatch_prototypes": 2,
        "nested_callbacks": 11,
        "abi_helpers": 5,
        "indexed_entries_total": 44,
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
            if category == "abi_helper"
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
    f"({len(PRIMARY)} primary + {len(OUTER)} outer + {len(NESTED)} nested + {len(ABI_HELPERS)} ABI helpers)"
)

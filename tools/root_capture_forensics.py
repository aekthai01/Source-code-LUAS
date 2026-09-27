#!/usr/bin/env python3
"""Derive the root P0 capture/context map from verified payload bytecode evidence."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD_SHA = "a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263"
JSON_OUT = ROOT / "ROOT_CAPTURE_MAP.json"
MD_OUT = ROOT / "ROOT_CAPTURE_MAP.md"

ROOT_VALUES = {
    0: ("GenLocalLogFunc result #1", "debug_logger", "debug_logger"),
    1: ("GenLocalLogFunc result #2", "info_logger", "info_logger"),
    2: ("GenLocalLogFunc result #3", "error_logger", "error_logger"),
    3: ("new root product table", "product_table", "product"),
    4: ("require('DFM.StandaloneLua.BusinessTool.ItemHelperTool')", "item_helper", "item_helper"),
    5: ("require('DFM.StandaloneLua.BusinessTool.StructTool.ItemConfigTool')", "item_config_tool", "item_config_tool"),
    6: ("require('DFM.StandaloneLua.BusinessTool.StructTool.WeaponAssemblyTool')", "weapon_assembly_tool", "weapon_assembly_tool"),
    7: ("require('DFM.StandaloneLua.BusinessTool.WeaponHelperTool')", "weapon_helper_tool", "weapon_helper_tool"),
    8: ("require('DFM.StandaloneLua.BusinessTool.StructTool.ItemBaseTool')", "item_base_tool", "item_base_tool"),
    9: ("require('DFM.Business.Module.ArmedForceModule.Logic.ArmedForce.ArmedForceExpiredLogic')", "armed_force_expired_logic", "armed_force_expired_logic"),
    10: ("import('AmmoDataManager')", "ammo_data_manager_module", "ammo_data_manager_module"),
    11: ("AmmoDataManager.Get()", "ammo_data_manager", "ammo_data_manager"),
}

REQUIRE_PATHS = {
    4: "DFM.StandaloneLua.BusinessTool.ItemHelperTool",
    5: "DFM.StandaloneLua.BusinessTool.StructTool.ItemConfigTool",
    6: "DFM.StandaloneLua.BusinessTool.StructTool.WeaponAssemblyTool",
    7: "DFM.StandaloneLua.BusinessTool.WeaponHelperTool",
    8: "DFM.StandaloneLua.BusinessTool.StructTool.ItemBaseTool",
    9: "DFM.Business.Module.ArmedForceModule.Logic.ArmedForce.ArmedForceExpiredLogic",
}


def blocks(text):
    result = {}
    for piece in re.split(r"^=== PROTO ", text, flags=re.M)[1:]:
        header, *body = piece.splitlines()
        result[header.split(" ", 1)[0]] = "\n".join(body)
    return result


def expect(body, pattern, label):
    if not re.search(pattern, body, flags=re.M):
        raise SystemExit(f"root capture evidence missing: {label}")


def capture_register(meta, prototype, upvalue):
    item = meta[prototype]["upvalues"][upvalue]
    if prototype.rsplit(".", 1)[0] != "0" or item.get("instack") != 1:
        return None
    return int(item["idx"])


def build():
    payload = ROOT / "embedded_payload.bin"
    actual_sha = hashlib.sha256(payload.read_bytes()).hexdigest()
    if actual_sha != PAYLOAD_SHA:
        raise SystemExit(f"embedded payload SHA mismatch: {actual_sha}")

    proto_list = json.loads((ROOT / "payload_prototypes.json").read_text(encoding="utf-8"))
    meta = {item["path"]: item for item in proto_list}
    dis = blocks((ROOT / "payload_disassembly.txt").read_text(encoding="utf-8"))
    root = dis["0"]

    expect(root, r"^0003 GETTABUP\s+R0, U0, K0='GenLocalLogFunc'$", "GenLocalLogFunc load")
    expect(root, r"^0004 GETTABUP\s+R1, U0, K1='ELuaLogCategory'$", "ELuaLogCategory load")
    expect(root, r"^0005 GETTABLE\s+R1, R1, K2='LuaMArmedForce'$", "LuaMArmedForce category")
    expect(root, r"^0006 CALL\s+A=0 B=2 C=4$", "three logger returns into R0/R1/R2")
    expect(root, r"^0007 NEWTABLE\s+A=3 B=0 C=0$", "root product table R3")
    for register, path in REQUIRE_PATHS.items():
        # The root uses one plain require call per R4..R9; verify both literal and destination.
        literal = re.escape(path)
        expect(root, rf"LOADK\s+R{register + 1}, K\d+='{literal}'", f"require literal for R{register}")
        expect(root, rf"CALL\s+A={register} B=2 C=2", f"require result in R{register}")
    expect(root, r"GETTABUP\s+R10, U0, K10='import'", "AmmoDataManager import function")
    expect(root, r"LOADK\s+R11, K11='AmmoDataManager'", "AmmoDataManager import literal")
    expect(root, r"CALL\s+A=10 B=2 C=2", "AmmoDataManager module in R10")
    expect(root, r"GETTABLE\s+R11, R10, K12='Get'", "AmmoDataManager.Get fetch")
    expect(root, r"CALL\s+A=11 B=1 C=2", "AmmoDataManager.Get() result in R11")

    # Prove logger meanings from child use sites, not by assuming return order names.
    expected_child_captures = {
        ("0.3", 0): 1,
        ("0.3", 2): 2,
        ("0.3", 3): 3,
        ("0.7", 1): 4,
        ("0.7", 2): 0,
        ("0.7", 3): 3,
        ("0.7", 4): 2,
        ("0.8", 1): 2,
        ("0.10", 1): 1,
    }
    for (prototype, upvalue), register in expected_child_captures.items():
        actual = capture_register(meta, prototype, upvalue)
        if actual != register:
            raise SystemExit(f"{prototype} U{upvalue}: expected root R{register}, got {actual}")

    p03, p070, p080, p010 = dis["0.3"], dis["0.7.0"], dis["0.8.0"], dis["0.10"]
    expect(p03, r"GETUPVAL\s+R0, U0\n0004 LOADK.*START", "P0.3 U0 normal START logger")
    expect(p03, r"GETUPVAL\s+R3, U2\n0044 LOADK.*curRentalPlan is nil", "P0.3 U2 error logger")
    expect(p070, r"GETUPVAL\s+R6, U3\n0039 LOADK.*\[Debug\] Get Value", "P0.7.0 inherited debug logger")
    expect(p070, r"GETUPVAL\s+R6, U6\n0077 LOADK.*checkValue", "P0.7.0 inherited error logger")
    expect(p080, r"GETUPVAL\s+R6, U3\n0085 LOADK.*checkValue", "P0.8.0 inherited error logger")
    expect(p010, r"GETUPVAL\s+R4, U1\n0018 GETTABUP.*string", "P0.10 info/price logger")

    # Direct root-child captures are mechanically derived from the prototype descriptors.
    direct = {register: [] for register in ROOT_VALUES}
    for path, item in meta.items():
        if not re.fullmatch(r"0\.\d+", path):
            continue
        for index, capture in enumerate(item.get("upvalues", [])):
            if capture.get("instack") == 1 and int(capture.get("idx", -1)) in direct:
                register = int(capture["idx"])
                direct[register].append({"prototype": "P" + path, "upvalue": f"U{index}"})
    for values in direct.values():
        values.sort(key=lambda item: ([int(p) for p in item["prototype"][1:].split(".")], int(item["upvalue"][1:])))

    usage = {
        0: ["P0.7 U2 -> P0.7.0 inherited U3; called before '[Debug] Get Value = '"],
        1: ["P0.3 U0 normal START/result/END diagnostics", "P0.10 U1 equipment price diagnostics"],
        2: ["P0.3 U2 rental-plan nil error", "P0.7 U4 -> P0.7.0 inherited U6 negative checkValue error", "P0.8 U1 -> P0.8.0 inherited U3 negative durability checkValue error"],
        3: ["P0.3 U3 reads CheckEquipSlotValue", "P0.7 U3 -> P0.7.0 inherited U4 reads GetMatchBulletNumByWeaponItem"],
        4: ["P0.7 U1 -> P0.7.0 inherited U2 reads GetSubTypeById"],
        10: ["root imports AmmoDataManager before fetching Get"],
        11: ["root calls imported AmmoDataManager.Get() without self"],
    }

    registers = {}
    for register, (root_value, role, field) in ROOT_VALUES.items():
        registers[f"R{register}"] = {
            "root_value": root_value,
            "semantic_role": role,
            "product_context_field": field,
            "direct_child_upvalue_captures": direct[register],
            "usage_evidence": usage.get(register, []),
        }

    output = {
        "_meta": {
            "source_of_truth": "embedded_payload.bin",
            "payload_sha256": actual_sha,
            "root_prototype": "P0",
            "root_instruction_count": meta["0"]["instruction_count"],
            "gen_local_log_call": "GenLocalLogFunc(ELuaLogCategory.LuaMArmedForce)",
            "gen_local_log_return_count": 3,
            "source_only_target": True,
            "note": "Logger roles are derived from child use instructions; stripped debug/local names are not claimed as originals.",
        },
        "root_registers": registers,
    }
    JSON_OUT.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Root P0 Capture Map", "",
        f"Source of truth: `embedded_payload.bin` SHA-256 `{actual_sha}`.", "",
        "Logger roles below are inferred from actual child call sites, not from invented stripped names.", "",
        "| Root register | Root value | Semantic role | Direct child upvalue captures |",
        "|---|---|---|---|",
    ]
    for register in range(12):
        item = registers[f"R{register}"]
        captures = ", ".join(f"{c['prototype']} {c['upvalue']}" for c in item["direct_child_upvalue_captures"]) or "none"
        lines.append(f"| `R{register}` | `{item['root_value']}` | `{item['semantic_role']}` | {captures} |")
    lines += ["", "## Semantic proof points", ""]
    for register in (0, 1, 2, 3, 4, 10, 11):
        for evidence in registers[f"R{register}"]["usage_evidence"]:
            lines.append(f"- `R{register}`: {evidence}")
    lines += [
        "", "## Source-only context contract", "",
        "`src/spectra/product_context.lua` must recreate these root values directly from the runtime globals:", "",
        "- call `GenLocalLogFunc(ELuaLogCategory.LuaMArmedForce)` once and preserve all three returned functions in R0/R1/R2 order;",
        "- create a fresh source product table for R3;",
        "- resolve the six exact `require` paths into R4..R9 in root bytecode order;",
        "- call `import('AmmoDataManager')` for R10, then call its `Get` function with no implicit self for R11.", "",
        "Payload-closure introspection is not part of this contract.", "",
    ]
    MD_OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"root-capture-map: {len(registers)} root registers; P0 instructions={meta['0']['instruction_count']}")
    print(JSON_OUT.read_text(encoding="utf-8"))


if __name__ == "__main__":
    build()

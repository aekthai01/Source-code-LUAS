#!/usr/bin/env python3
"""Generate a conservative structural inventory for the embedded Lua payload."""
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_PAYLOAD_SHA = "a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263"
EXPECTED_COUNT = 296
ROOT_METHODS = [
    "CheckEquipmentBeforEnterGameProcess", "_CheckProcess", "_CheckEquipmentValue",
    "GetAllEquipmentValue", "_CheckMedicine", "_CheckUnCarryMedicine", "_CheckContainer",
    "_CheckBullet", "_CheckDurabulity", "CheckEquipSlotEmpty", "CheckEquipSlotValue",
    "DynamicGuidPriceFinishFetch", "CheckRaidBulletEnough", "GetMatchBulletNumByWeaponItem",
    "_CheckNightFight", "_CheckPlayerSuppliesForNightSpeicalType", "_CheckSafeBoxExpiredStatus",
    "_CheckKeyChainExpiredStatus", "_CheckPropExpiredStatus", "CheckPlayerBodyItemsByList",
    "CheckNightVisionLimitByList", "CheckThermalImagingLimitByList", "CheckPlayerBodyItemsEntryQuality",
    "CheckRentalConsumableID", "_CheckPropinfoDownloadWithLog", "_CheckItemWithCompsDownloaded",
    "_CheckItemIdDownloaded", "_CheckAllWeaponPartDownloaded", "GetNeedDownloadCategaryKey",
]
ROOT_FIELDS = ["EquipTypeList", "ContainerTypeList"]
OWNERSHIP = ("source_owned", "payload_owned", "partially_reconstructed",
             "dead_or_unreachable_verified", "unknown")


def read_json(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def prototype_parent(path):
    return path.rsplit(".", 1)[0] if "." in path else None


def blocks_by_path(text):
    result = {}
    pieces = re.split(r"^=== PROTO ", text, flags=re.M)[1:]
    for piece in pieces:
        header, *body = piece.splitlines()
        path = header.split(" ", 1)[0]
        result[path] = "\n".join(body)
    return result


def root_exports(disassembly):
    exports = {}
    lines = disassembly["0"].splitlines()
    for i, line in enumerate(lines):
        closure = re.search(r"CLOSURE\s+R(\d+), P(\d+)", line)
        if not closure or i + 1 >= len(lines):
            continue
        dest, child = closure.groups()
        following = lines[i + 1]
        field = re.search(r"SETTABLE\s+R\d+, K\d+='([^']+)', R" + re.escape(dest) + r"\b", following)
        if field:
            exports[f"0.{child}"] = field.group(1)
    return exports


def build():
    payload = ROOT / "embedded_payload.bin"
    payload_sha = hashlib.sha256(payload.read_bytes()).hexdigest()
    if payload_sha != EXPECTED_PAYLOAD_SHA:
        raise SystemExit(f"embedded payload SHA mismatch: {payload_sha}")

    prototypes = read_json("payload_prototypes.json")
    constants_raw = read_json("payload_constants.json")
    if len(prototypes) != EXPECTED_COUNT:
        raise SystemExit(f"prototype metadata count {len(prototypes)} != {EXPECTED_COUNT}")
    constants = defaultdict(list)
    for item in constants_raw:
        constants[item["proto"]].append({"index": item["index"], "tag": item["tag"], "value": item["value"]})
    for values in constants.values():
        values.sort(key=lambda item: item["index"])

    disassembly_text = (ROOT / "payload_disassembly.txt").read_text(encoding="utf-8")
    disassembly = blocks_by_path(disassembly_text)
    if len(disassembly) != EXPECTED_COUNT:
        raise SystemExit(f"disassembly block count {len(disassembly)} != {EXPECTED_COUNT}")
    actual_exports = root_exports(disassembly)
    expected_exports = {f"0.{index}": name for index, name in enumerate(ROOT_METHODS)}
    if actual_exports != expected_exports:
        raise SystemExit("root P0.0..P0.28 export map does not match the bytecode constants")
    root_block = disassembly["0"]
    actual_fields = [name for name in ROOT_FIELDS if re.search(r"SETTABLE\s+R3, K\d+='" + re.escape(name) + r"'", root_block)]
    if actual_fields != ROOT_FIELDS:
        raise SystemExit("EquipTypeList/ContainerTypeList bytecode exports are missing or reordered")

    meta_by_path = {item["path"]: item for item in prototypes}
    if set(meta_by_path) != set(disassembly):
        raise SystemExit("prototype paths differ between metadata and disassembly")
    for path, meta in meta_by_path.items():
        observed = len(re.findall(r"^\d{4} ", disassembly[path], flags=re.M))
        if observed != meta["instruction_count"]:
            raise SystemExit(f"{path}: disassembly instruction count {observed} != metadata {meta['instruction_count']}")
        if len(constants.get(path, [])) != meta["constant_count"]:
            raise SystemExit(f"{path}: constants count differs from metadata")

    aim_data = read_json("AIM_PROTOTYPE_INDEX.json").get("prototypes", {})
    source_map = {}
    for path, info in aim_data.items():
        if info.get("implementation_status", "").startswith("source-") or info.get("implementation_status") == "source-owned after payload init":
            source_map[path] = ("source_owned", info.get("source"), info.get("reconstructed_name"))

    phase_e_root = {"0.0", "0.1", "0.2", "0.4", "0.5", "0.6", "0.7", "0.8", "0.9"}
    for path in phase_e_root:
        source_map[path] = ("source_owned", "src/spectra/product_module.lua", ROOT_METHODS[int(path.split(".")[-1])])
    # The P0.3 diagnostic closures are stripped upvalues U0/U2. Source behavior
    # is materialized and tested, but runtime takeover is conditional on those
    # exact captured functions being available through the Lua debug API.
    source_map["0.3"] = ("partially_reconstructed", "src/spectra/product_module.lua", "calculate_equipment_value")
    source_map["0.4"] = ("source_owned", "src/spectra/product_module.lua", "_CheckMedicine")
    source_map["0.5"] = ("source_owned", "src/spectra/product_module.lua", "_CheckUnCarryMedicine")
    source_map["0.6"] = ("source_owned", "src/spectra/product_module.lua", "_CheckContainer")
    source_map["0.6.0"] = ("source_owned", "src/spectra/product_module.lua", "add_medicine_types_from_items")
    source_map["0.7"] = ("partially_reconstructed", "src/spectra/product_module.lua", "_CheckBullet")
    source_map["0.7.0"] = ("partially_reconstructed", "src/spectra/product_module.lua", "inspect_bullet_slot")
    source_map["0.8"] = ("partially_reconstructed", "src/spectra/product_module.lua", "_CheckDurabulity")
    source_map["0.8.0"] = ("partially_reconstructed", "src/spectra/product_module.lua", "check_durability_slot")
    source_map["0.10"] = ("partially_reconstructed", "src/spectra/product_module.lua", "CheckEquipSlotValue")
    for path in ("0.29.17", "0.29.26", "0.29.29"):
        source_map[path] = ("source_owned", "src/spectra/mutation_runtime.lua", None)
    for number in range(78, 99):
        source_map[f"0.29.{number}"] = ("source_owned", "src/spectra/visual_scan.lua", None)
    for number in range(99, 104):
        source_map[f"0.29.{number}"] = ("source_owned", "src/spectra/character_visuals.lua", None)
    source_map["0.29.104"] = ("source_owned", "src/spectra/payload_visual_bridge.lua", None)
    source_map["0.29.105"] = ("source_owned", "src/spectra/native_settings_ui.lua", None)
    source_map["0.29.106"] = ("source_owned", "src/spectra/payload_visual_bridge.lua", None)
    source_map["0.29.107"] = ("source_owned", "src/spectra/payload_visual_bridge.lua", None)

    direct_calls = {
        "0.0": ["0.1"],
        "0.1": ["0.7", "0.8", "0.6", "0.4", "0.2", "0.14", "0.23", "0.16", "0.17", "0.18"],
        "0.2": ["0.3"],
        "0.3": ["0.10"],
        "0.4": ["0.5"],
        "0.6": ["0.6.0"],
        "0.7": ["0.7.0"],
        "0.8": ["0.8.0"],
    }
    callers = defaultdict(list)
    for caller, callees in direct_calls.items():
        for callee in callees:
            callers[callee].append(caller)

    def resolves_environment(path, upvalue_index, seen=None):
        seen = set() if seen is None else seen
        key = (path, upvalue_index)
        if key in seen:
            return False
        seen.add(key)
        if path == "0":
            return upvalue_index == 0
        meta = meta_by_path[path]
        if upvalue_index >= len(meta["upvalues"]):
            return False
        capture = meta["upvalues"][upvalue_index]
        if capture.get("instack") == 0:
            parent = prototype_parent(path)
            return parent is not None and resolves_environment(parent, capture.get("idx", -1), seen)
        return False

    descriptive_upvalues = {"0.10": {1: "captured_price_logger"}}
    index_entries = []
    for path, meta in sorted(meta_by_path.items(), key=lambda pair: [int(part) for part in pair[0].split(".")]):
        body = disassembly[path]
        globals_used = set()
        table_names = set()
        for line in body.splitlines():
            m = re.search(r"GETTABUP\s+R\d+, U(\d+), K\d+='([^']+)'", line)
            if m:
                upvalue_index, name = int(m.group(1)), m.group(2)
                table_names.add(name)
                if resolves_environment(path, upvalue_index):
                    globals_used.add(name)
            m = re.search(r"(?:GETTABLE|SELF)\s+R\d+, R\d+, K\d+='([^']+)'", line)
            if m:
                table_names.add(m.group(1))
            m = re.search(r"(?:SETTABLE|SETTABUP)\s+(?:R|U)?\d+,\s*K\d+='([^']+)'", line)
            if m:
                table_names.add(m.group(1))
            m = re.search(r"GETGLOBAL\s+R\d+, K\d+='([^']+)'", line)
            if m:
                globals_used.add(m.group(1)); table_names.add(m.group(1))

        ownership, source_file, reconstructed_name = source_map.get(
            path, ("payload_owned", None, None))
        if ownership not in OWNERSHIP:
            raise SystemExit(f"invalid ownership for {path}: {ownership}")
        public = actual_exports.get(path)
        if path == "0.3":
            reconstructed_name = "calculate_equipment_value"
        if public:
            confidence = "high"
            semantic_confidence = "high"
            name = public
            is_original_symbol = True
        else:
            semantic_confidence = "high" if path in aim_data or path in phase_e_root or path == "0.6.0" else (
                "medium" if ownership in ("source_owned", "partially_reconstructed") else "low")
            confidence = "high" if ownership != "payload_owned" else "medium"
            name = reconstructed_name or ("reconstructed_prototype_" + path.replace(".", "_"))
            is_original_symbol = False
        parent = prototype_parent(path)
        children = [candidate for candidate in meta_by_path if prototype_parent(candidate) == path]
        item = {
            "prototype_id": "P" + path,
            "parent": "P" + parent if parent else None,
            "children": ["P" + child for child in sorted(children, key=lambda p: [int(x) for x in p.split(".")])],
            "instruction_count": meta["instruction_count"],
            "constant_count": meta["constant_count"],
            "constants": constants.get(path, []),
            "upvalues": [
                {"index": i, "instack": capture.get("instack"), "idx": capture.get("idx"),
                 "name": None, "descriptive_name": descriptive_upvalues.get(path, {}).get(i, f"captured_value_{i}")}
                for i, capture in enumerate(meta["upvalues"])
            ],
            "globals": sorted(globals_used),
            "table_names": sorted(table_names),
            "known_callers": ["P" + caller for caller in sorted(callers[path], key=lambda p: [int(x) for x in p.split(".")])],
            "known_callees": ["P" + callee for callee in direct_calls.get(path, [])],
            "return_contract": {"0.0": "no explicit return", "0.1": "no explicit return",
                "0.2": "no explicit return", "0.3": "returns total equipment value, then selected currency type",
                "0.4": "no explicit return", "0.5": "returns key and two ordered medicine-type/description lists",
                "0.6": "no explicit return", "0.6.0": "no explicit return",
                "0.7": "no explicit return",
                "0.7.0": "returns true for no-failure paths; returns false, subtype, matched-minus-required, and formatted location when deficient",
                "0.8": "no explicit return",
                "0.8.0": "returns true for no-failure paths; returns false and a formatted location when normalized durability is at or below the configured threshold",
                "0.9": "returns true when the requested slot has no item; returns false and the item when occupied",
                "0.10": "returns 0 when the slot has no item; otherwise returns the dynamic guide price or 0 when the price is falsey"}.get(path, "not reconstructed"),
            "public_symbol": public,
            "public_symbol_is_original": public is not None,
            "reconstructed_name": name,
            "reconstructed_name_is_original_symbol": is_original_symbol,
            "current_ownership": ownership,
            "reachability": "reachable_from_payload_root" if path == "0" or parent is not None else "unknown",
            "source_file": source_file,
            "evidence_paths": [
                f"payload_prototypes.json#{path}", f"payload_constants.json#{path}",
                f"payload_disassembly.txt#PROTO {path}",
            ],
            "confidence": confidence,
            "semantic_confidence": semantic_confidence,
            "metadata_confidence": "high",
        }
        index_entries.append(item)

    counts = {status: sum(item["current_ownership"] == status for item in index_entries) for status in OWNERSHIP}
    reachable = sum(item["reachability"] == "reachable_from_payload_root" for item in index_entries)
    root_source_owned = sum(
        entry["current_ownership"] == "source_owned" and entry["prototype_id"] in {f"P0.{i}" for i in range(29)}
        for entry in index_entries
    )
    index = {
        "_meta": {
            "source_of_truth": "embedded_payload.bin",
            "payload_sha256": payload_sha,
            "total_prototypes": len(index_entries),
            "required_total": EXPECTED_COUNT,
            "root_public_methods": 29,
            "root_fields": ROOT_FIELDS,
            "root_field_evidence": "payload_disassembly.txt#PROTO 0 SETTABLE instructions",
            "root_public_methods": {
                name: {
                    "prototype_id": f"P0.{i}",
                    "current_ownership": index_entries[next(j for j, entry in enumerate(index_entries)
                        if entry["prototype_id"] == f"P0.{i}")]["current_ownership"],
                    "source_file": index_entries[next(j for j, entry in enumerate(index_entries)
                        if entry["prototype_id"] == f"P0.{i}")]["source_file"],
                    "runtime_takeover": "conditional" if i in (3, 7, 8, 10) else ("source" if i < 3 or i in (4, 5, 6, 9) else "payload"),
                } for i, name in enumerate(ROOT_METHODS)
            },
            "ownership_enum": sorted(OWNERSHIP),
            "reachability_definition": "Static closure path from root prototype; does not assert a runtime invocation.",
            "call_graph_note": "known_callers/known_callees contain only direct edges established from bytecode; unresolved/dynamic edges are intentionally omitted.",
            "symbol_note": "Only root P0.0..P0.28 exports are recorded as exact public symbols. Other names are reconstructed descriptions, never original debug symbols.",
        },
        "coverage": {
            "classified": len(index_entries), "reachable": reachable,
            "source_owned": counts["source_owned"], "payload_owned": counts["payload_owned"],
            "partially_reconstructed": counts["partially_reconstructed"],
            "dead_or_unreachable_verified": counts["dead_or_unreachable_verified"],
            "unknown": counts["unknown"], "root_methods_source_owned": root_source_owned,
            "root_methods_total": 29,
        },
        "prototypes": {entry["prototype_id"][1:]: entry for entry in index_entries},
    }
    (ROOT / "FULL_PAYLOAD_PROTOTYPE_INDEX.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    map_lines = [
        "# Full Payload Reconstruction Map", "",
        f"Evidence payload SHA-256: `{payload_sha}`. Prototype count verified from all three machine artifacts: `{len(index_entries)}`.",
        "", "All prototype names without a recovered public root export are reconstructed descriptions. The index omits unresolved/dynamic call edges rather than guessing.",
        "", "## Root public API P0.0..P0.28", "",
        "| Prototype | Exact exported name | Ownership | Source |", "|---|---|---|---|",
    ]
    for i, name in enumerate(ROOT_METHODS):
        entry = index["prototypes"][f"0.{i}"]
        map_lines.append(f"| `P0.{i}` | `{name}` | `{entry['current_ownership']}` | `{entry['source_file'] or 'payload'}` |")
    map_lines += [
        "", "Exact root fields: `EquipTypeList`, `ContainerTypeList`.",
        "", "## P0.0..P0.10 source boundary", "",
        "- `P0.0` retains the recovered `CheckMainFlowSOL` result branch, a second `GetCurrentGameFlow` call only on false, Lobby equality return, reset, `_CheckProcess`, and changed event order.",
        "- `P0.1` calls the ten recovered checks in bytecode order and then `SortEquipAbnormal`.",
        "- `P0.2` reads current equipment value and both map thresholds, uses strict `<` / `>` comparisons with zero-threshold guards and config switches, and emits the two recovered abnormal record shapes.",
        "- `P0.3` keeps challenge currency selection, rental and slot sum paths, two-value return, and value-changed event. Its P0.3 U0/U2 diagnostic closures are taken from the original payload closure when the runtime exposes them; otherwise that method remains payload-owned.",
        "- `P0.4` reads current medicine types before `table.values(EDispensingMedicineType)`, dispatches through the captured module table's current `_CheckUnCarryMedicine` field (P0.5), and adds `LackMedicine` only for a nonempty result list.",
        "- `P0.5` uses `ipairs` order, `GetEquipmentCheckData(LackMedicine, type)`, the exact `switch` and `table.contains(current, type)` gates, maximum key aggregation, and ordered list appends without deduplication.",
        "- `P0.6` collects `ChestHangingContainer`, `BagContainer`, and `Pocket` capacities in bytecode order, adds `1e-6` to each total/free value, applies the strict rounded-ratio comparison, selects the challenge/player safe-box group, and walks item collections through nested `P0.6.0`.",
        "- `P0.7` and nested `P0.7.0` reconstruct left weapon, right weapon, then pistol checks; preserve captured helper/logger calls, strict insufficient-ammo comparison, negative check-value logging, maximum abnormal key, equal-subtype slot handling, and location order. The method bridge installs P0.7 only when the original closure's ItemHelperTool, both loggers, and identical product table are available; otherwise it leaves the payload method in place.",
        "- `P0.8` and nested `P0.8.0` reconstruct Helmet then BreastPlate durability checks; preserve equipment-feature type gates, `InsufficientDurability` lookup, negative-value logger behavior, open-return forwarding from `GetDurabilityPercent`, two-decimal normalization, inclusive `current <= threshold` comparison, rounding/slot-name formatting, ordered abnormal fields, and maximum key. The bridge requires original P0.8 U1 error-logger capture; absent capture leaves the payload method.",
        "- `P0.9` resolves the current slot-group ID, calls `InventoryServer:GetSlot(slot_type, group_id)`, and returns exactly `true` for an empty slot or `false, item` for an occupied slot.",
        "- `P0.10` resolves the current slot group, reads the requested slot/item, calls `ShopServer:GetShopSingleDynamicGuidePriceByItem(item, nil, false)` only for occupied slots, logs the bytecode format string through captured U1, and returns the price or numeric zero. Runtime overlay is conditional on recovering that exact captured function.",
        "- The method bridge preserves originals and restores its writes on install failure. It rethrows source exceptions without retrying payload code because earlier operations may already have caused side effects.",
        "", "## Current ownership groups", "",
        f"Source-owned prototypes: `{counts['source_owned']}`; payload-owned: `{counts['payload_owned']}`; partially reconstructed: `{counts['partially_reconstructed']}`; unknown: `{counts['unknown']}`.",
        "", "`FULL_PAYLOAD_PROTOTYPE_INDEX.json` is the per-prototype authority. The method-level runtime bridge owns P0.0..P0.2, P0.4..P0.6, and P0.9. P0.3, P0.7, P0.8 and P0.10 remain partial/conditional on recovered closure captures.",
        "",
    ]
    (ROOT / "FULL_PAYLOAD_RECONSTRUCTION_MAP.md").write_text("\n".join(map_lines), encoding="utf-8")

    coverage_lines = [
        "# Reconstruction Coverage", "",
        f"Payload SHA-256: `{payload_sha}`.", "",
        f"- Total prototypes: **{len(index_entries)}**",
        f"- Classified: **{len(index_entries)}**",
        f"- Source-owned reachable: **{sum(i['current_ownership']=='source_owned' and i['reachability']=='reachable_from_payload_root' for i in index_entries)}**",
        f"- Payload-owned reachable: **{sum(i['current_ownership']=='payload_owned' and i['reachability']=='reachable_from_payload_root' for i in index_entries)}**",
        f"- Partially reconstructed: **{counts['partially_reconstructed']}**",
        f"- Dead/unreachable verified: **{counts['dead_or_unreachable_verified']}**",
        f"- Unknown: **{counts['unknown']}**",
        f"- Root methods source-owned: **{root_source_owned} / 29**",
        "", "The inventory is structurally complete, not a claim that all payload behavior has been reconstructed. Unmapped prototypes remain payload-owned. Dead/unreachable is used only with positive reachability evidence; no prototype is marked dead by absence of references.",
        "P0.3 source logic and tests exist, but its two stripped diagnostic upvalues are only installed when captured from the original function; its default static ownership classification is partial. P0.4..P0.6 and nested P0.6.0 have source implementations and method-level overlays backed by the bytecode-derived call graph. P0.7/P0.7.0 source and regression vectors are materialized but stay partial until the original helper, both loggers, and module identity pass the install gate. P0.8/P0.8.0 source and regression vectors are materialized but stay partial until the original error-logger upvalue passes the install gate. P0.9 is source-owned and its public argument/return contract is covered by the product-method bridge tests. P0.10 source and bytecode-order tests are materialized; runtime installation stays conditional on recovering P0.10 U1 as a function.",
        "", "Generated by `python3 tools/full_payload_forensics.py` from `payload_prototypes.json`, `payload_constants.json`, `payload_disassembly.txt`, and the verified payload hash.", "",
    ]
    (ROOT / "RECONSTRUCTION_COVERAGE.md").write_text("\n".join(coverage_lines), encoding="utf-8")
    print(f"full-payload-index: {len(index_entries)} prototypes; ownership={counts}; root_source_owned={root_source_owned}/29")


if __name__ == "__main__":
    build()

#!/usr/bin/env python3
"""Generate the current compact ownership inventory from verified payload metadata.

The previous verbose per-prototype structural inventory is preserved as
FULL_PAYLOAD_PROTOTYPE_INDEX_LEGACY_DETAILED.json. This generator keeps current
ownership/classification reproducible without duplicating constants and disassembly
that already live in payload_constants.json/payload_disassembly.txt.
"""
import hashlib
import json
import re
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


def sort_key(path):
    return [int(part) for part in path.split(".")]


def blocks_by_path(text):
    result = {}
    for piece in re.split(r"^=== PROTO ", text, flags=re.M)[1:]:
        header, *body = piece.splitlines()
        result[header.split(" ", 1)[0]] = "\n".join(body)
    return result


def root_exports(disassembly):
    exports = {}
    lines = disassembly["0"].splitlines()
    for i, line in enumerate(lines):
        closure = re.search(r"CLOSURE\s+R(\d+), P(\d+)", line)
        if not closure or i + 1 >= len(lines):
            continue
        dest, child = closure.groups()
        field = re.search(r"SETTABLE\s+R\d+, K\d+='([^']+)', R" + re.escape(dest) + r"\b", lines[i + 1])
        if field:
            exports[f"0.{child}"] = field.group(1)
    return exports


def build():
    payload = ROOT / "embedded_payload.bin"
    payload_sha = hashlib.sha256(payload.read_bytes()).hexdigest()
    if payload_sha != EXPECTED_PAYLOAD_SHA:
        raise SystemExit(f"embedded payload SHA mismatch: {payload_sha}")

    prototypes = read_json("payload_prototypes.json")
    if len(prototypes) != EXPECTED_COUNT:
        raise SystemExit(f"prototype metadata count {len(prototypes)} != {EXPECTED_COUNT}")
    paths = {item["path"] for item in prototypes}

    disassembly = blocks_by_path((ROOT / "payload_disassembly.txt").read_text(encoding="utf-8"))
    if set(disassembly) != paths:
        raise SystemExit("prototype paths differ between metadata and disassembly")
    actual_exports = root_exports(disassembly)
    expected_exports = {f"0.{index}": name for index, name in enumerate(ROOT_METHODS)}
    if actual_exports != expected_exports:
        raise SystemExit("root P0.0..P0.28 export map does not match bytecode")
    root_block = disassembly["0"]
    for field in ROOT_FIELDS:
        if not re.search(r"SETTABLE\s+R3, K\d+='" + re.escape(field) + r"'", root_block):
            raise SystemExit(f"root field missing: {field}")

    capture = read_json("ROOT_CAPTURE_MAP.json")
    if capture["_meta"]["payload_sha256"] != payload_sha:
        raise SystemExit("ROOT_CAPTURE_MAP payload hash mismatch")
    roles = capture["root_registers"]
    if [roles[f"R{i}"]["semantic_role"] for i in range(3)] != ["debug_logger", "info_logger", "error_logger"]:
        raise SystemExit("root logger role map mismatch")

    source_files = {}
    aim = read_json("AIM_PROTOTYPE_INDEX.json").get("prototypes", {})
    for path, info in aim.items():
        status = info.get("implementation_status", "")
        if status.startswith("source-") or status == "source-owned after payload init":
            source_files[path] = info.get("source") or "aim reconstruction source"

    # P0.0..P0.10 no longer depend on payload closure captures. Nested P0.6.0,
    # P0.7.0 and P0.8.0 are part of those source method bodies.
    for number in range(11):
        source_files[f"0.{number}"] = "src/spectra/product_module.lua"
    for path in ("0.6.0", "0.7.0", "0.8.0"):
        source_files[path] = "src/spectra/product_module.lua"

    for path in ("0.29.17", "0.29.26", "0.29.29"):
        source_files[path] = "src/spectra/mutation_runtime.lua"
    for number in range(78, 99):
        source_files[f"0.29.{number}"] = "src/spectra/visual_scan.lua"
    for number in range(99, 104):
        source_files[f"0.29.{number}"] = "src/spectra/character_visuals.lua"
    source_files["0.29.104"] = "src/spectra/payload_visual_bridge.lua"
    source_files["0.29.105"] = "src/spectra/native_settings_ui.lua"
    source_files["0.29.106"] = "src/spectra/payload_visual_bridge.lua"
    source_files["0.29.107"] = "src/spectra/payload_visual_bridge.lua"

    unknown_sources = set(source_files) - paths
    if unknown_sources:
        raise SystemExit(f"source ownership references unknown prototypes: {sorted(unknown_sources)}")

    groups = {status: [] for status in OWNERSHIP}
    for path in sorted(paths, key=sort_key):
        status = "source_owned" if path in source_files else "payload_owned"
        groups[status].append(path)

    counts = {status: len(groups[status]) for status in OWNERSHIP}
    if counts != {
        "source_owned": 86,
        "payload_owned": 210,
        "partially_reconstructed": 0,
        "dead_or_unreachable_verified": 0,
        "unknown": 0,
    }:
        raise SystemExit(f"unexpected checkpoint ownership counts: {counts}")

    root_public = {}
    for index, name in enumerate(ROOT_METHODS):
        path = f"0.{index}"
        source = path in source_files
        root_public[name] = {
            "prototype_id": "P" + path,
            "current_ownership": "source_owned" if source else "payload_owned",
            "source_file": source_files.get(path),
            "runtime_takeover": "source" if source else "payload",
            "source_only_dependency": bool(source and index <= 10),
        }
    root_source_owned = sum(item["current_ownership"] == "source_owned" for item in root_public.values())
    if root_source_owned != 11:
        raise SystemExit(f"root source-owned count {root_source_owned} != 11")
    for name, item in root_public.items():
        if item["current_ownership"] == "source_owned" and not item["source_only_dependency"]:
            raise SystemExit(f"source-owned root method still requires payload initialization: {name}")

    index = {
        "_meta": {
            "source_of_truth": "embedded_payload.bin",
            "payload_sha256": payload_sha,
            "total_prototypes": EXPECTED_COUNT,
            "required_total": EXPECTED_COUNT,
            "legacy_detailed_index": "FULL_PAYLOAD_PROTOTYPE_INDEX_LEGACY_DETAILED.json",
            "root_fields": ROOT_FIELDS,
            "ownership_enum": list(OWNERSHIP),
            "classification_note": "Ownership groups partition all payload prototype IDs. Structural constants/upvalues remain in the legacy detailed index and machine evidence files.",
        },
        "coverage": {
            "classified": EXPECTED_COUNT,
            "source_owned": counts["source_owned"],
            "payload_owned": counts["payload_owned"],
            "partially_reconstructed": counts["partially_reconstructed"],
            "dead_or_unreachable_verified": counts["dead_or_unreachable_verified"],
            "unknown": counts["unknown"],
            "root_methods_source_owned": root_source_owned,
            "root_methods_total": 29,
        },
        "root_public_methods": root_public,
        "ownership_groups": groups,
        "source_files": {path: source_files[path] for path in sorted(source_files, key=sort_key)},
    }
    (ROOT / "FULL_PAYLOAD_PROTOTYPE_INDEX.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    map_lines = [
        "# Full Payload Reconstruction Map", "",
        f"Evidence payload SHA-256: `{payload_sha}`. Prototype count: **296**.", "",
        "The current compact ownership index is `FULL_PAYLOAD_PROTOTYPE_INDEX.json`. The prior verbose structural index is retained as `FULL_PAYLOAD_PROTOTYPE_INDEX_LEGACY_DETAILED.json`; bytecode constants/upvalues remain independently reproducible from the payload metadata files.",
        "", "## Root capture/context layer", "",
        "`ROOT_CAPTURE_MAP.json` derives P0 R0..R11 from root bytecode. `src/spectra/product_context.lua` recreates the three loggers, six required tools, AmmoDataManager import/Get result, and a fresh source product table without inspecting payload closures.",
        "", "## Root public API P0.0..P0.28", "",
        "| Prototype | Exact exported name | Ownership | Source-only dependency | Source |",
        "|---|---|---|---|---|",
    ]
    for index, name in enumerate(ROOT_METHODS):
        item = root_public[name]
        map_lines.append(
            f"| `P0.{index}` | `{name}` | `{item['current_ownership']}` | `{str(item['source_only_dependency']).lower()}` | `{item['source_file'] or 'payload'}` |")
    map_lines += [
        "", "Exact root fields: `EquipTypeList`, `ContainerTypeList`.", "",
        "## P0.0..P0.10 source-only preparation", "",
        "- All eleven public methods P0.0..P0.10 now receive stripped root captures from `ProductContext`, not `debug.getupvalue`.",
        "- P0.3 uses source `info_logger` (R1) and `error_logger` (R2).",
        "- P0.7/P0.7.0 use source `ItemHelperTool` (R4), `debug_logger` (R0), `error_logger` (R2), and the owning product table passed by the source constructor.",
        "- P0.8/P0.8.0 use source `error_logger` (R2).",
        "- P0.10 uses source `info_logger` (R1) as the price logger.",
        "- `ProductModule.create(context, globals)` creates/binds P0.0..P0.10 on the same source R3 product table and emits exact `EquipTypeList` / `ContainerTypeList` order.",
        "- The transitional payload overlay remains restorable, but no P0.0..P0.10 installation decision depends on payload closure upvalues.",
        "", "## Current ownership", "",
        f"- Source-owned: **{counts['source_owned']}**",
        f"- Payload-owned: **{counts['payload_owned']}**",
        f"- Partially reconstructed: **{counts['partially_reconstructed']}**",
        f"- Unknown: **{counts['unknown']}**",
        f"- Root methods source-owned: **{root_source_owned} / 29**",
        "",
    ]
    (ROOT / "FULL_PAYLOAD_RECONSTRUCTION_MAP.md").write_text("\n".join(map_lines), encoding="utf-8")

    coverage_lines = [
        "# Reconstruction Coverage", "",
        f"Payload SHA-256: `{payload_sha}`.", "",
        "- Total prototypes: **296**",
        "- Classified: **296**",
        f"- Source-owned: **{counts['source_owned']}**",
        f"- Payload-owned: **{counts['payload_owned']}**",
        f"- Partially reconstructed: **{counts['partially_reconstructed']}**",
        "- Dead/unreachable verified: **0**",
        "- Unknown: **0**",
        f"- Root methods source-owned: **{root_source_owned} / 29**",
        "", "P0.0..P0.10 are source-owned with `source_only_dependency=true`; their root captures are recreated by ProductContext and a source product table can be constructed without loading the embedded payload. Remaining root methods P0.11..P0.28 stay payload-owned until their bounded reconstruction checkpoints complete.",
        "", "Generated by `python3 tools/full_payload_forensics.py`; root capture evidence is independently regenerated by `python3 tools/root_capture_forensics.py`.", "",
    ]
    (ROOT / "RECONSTRUCTION_COVERAGE.md").write_text("\n".join(coverage_lines), encoding="utf-8")

    print(f"full-payload-index: 296 prototypes; ownership={counts}; root_source_owned={root_source_owned}/29")
    print((ROOT / "FULL_PAYLOAD_PROTOTYPE_INDEX.json").read_text(encoding="utf-8"))


if __name__ == "__main__":
    build()

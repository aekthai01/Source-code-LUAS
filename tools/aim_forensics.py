#!/usr/bin/env python3
"""Reproducible runtime-status index for the verified aim reconstruction.

The detailed structural index from the pre-takeover checkpoint is preserved as
AIM_PROTOTYPE_INDEX_LEGACY_DETAILED.json. This generator emits the current,
reviewer-facing implementation/ownership map and verifies every indexed prototype
still exists in payload_prototypes.json.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
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
ALL = [*PRIMARY, *OUTER, *NESTED]
assert len(PRIMARY) == 26
assert len(OUTER) == 2
assert len(NESTED) == 11
assert len(ALL) == 39 and len(set(ALL)) == 39
missing = [pid for pid in ALL if pid not in P]
assert not missing, f"missing payload prototypes: {missing}"

def source_for(pid):
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

index = {
    "_meta": {
        "source_of_truth": "embedded_payload.bin",
        "payload_sha256": "a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263",
        "primary_requested_prototypes": 26,
        "outer_dispatch_prototypes": 2,
        "nested_callbacks": 11,
        "indexed_entries_total": 39,
        "detailed_legacy_index": "AIM_PROTOTYPE_INDEX_LEGACY_DETAILED.json",
        "runtime_ownership": {"aim": True, "anti_shake": True},
        "game_runtime_test": False,
        "note": "Names are reconstructed descriptions unless an exact public/global symbol is stated.",
    },
    "prototypes": {},
}

for pid in ALL:
    category = "primary_requested" if pid in PRIMARY else "outer_dispatch" if pid in OUTER else "nested_callback"
    item = {
        "category": category,
        "source": source_for(pid),
        "implementation_status": (
            "source-owned after payload init"
            if category != "nested_callback"
            else "source-reconstructed and owned through reconstructed parent flow"
        ),
        "name_is_original_symbol": False,
    }
    if pid == "0.29.65":
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
    f"({len(PRIMARY)} primary + {len(OUTER)} outer + {len(NESTED)} nested)"
)

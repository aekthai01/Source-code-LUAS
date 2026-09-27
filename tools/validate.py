#!/usr/bin/env python3
import base64
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))
from remap_lua53 import Scanner, transform  # noqa: E402

BASELINE = ROOT / "baseline_original.luac"
PAYLOAD_BIN = ROOT / "embedded_payload.bin"
PAYLOAD_B64 = ROOT / "embedded_payload.b64"
PAYLOAD_EMBED = ROOT / "src" / "spectra" / "payload_embed.lua"
SOURCE = ROOT / "spectra_wrapper_source.lua"
STANDARD = ROOT / "spectra_wrapper.standard.luac"
CUSTOM = ROOT / "spectra_wrapper.custom.luac"
VALIDATION = ROOT / "validation.json"

EXPECTED_BASELINE_SHA = "35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536"
EXPECTED_PAYLOAD_SHA = "a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263"
EXPECTED_BASELINE_SIZE = 180034
EXPECTED_PAYLOAD_SIZE = 108533


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_record(path: Path):
    data = path.read_bytes()
    return {"size": len(data), "sha256": sha_bytes(data)}


def lua53_program(name):
    path = shutil.which(name)
    if not path:
        return None
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write("print(_VERSION)\n")
        probe = f.name
    try:
        out = subprocess.run([path, probe], text=True, capture_output=True)
        version = (out.stdout + out.stderr).strip()
    finally:
        Path(probe).unlink(missing_ok=True)
    if out.returncode == 0 and "Lua 5.3" in version:
        return path, version
    return None


def find_lua_runner():
    for name in ("texlua", "lua5.3", "lua"):
        found = lua53_program(name)
        if found:
            return found
    raise RuntimeError("Lua 5.3 runner not found")


def run_checked(cmd):
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(
            "command failed: " + " ".join(map(str, cmd)) + "\n" + proc.stdout + proc.stderr
        )
    return (proc.stdout + proc.stderr).strip()


def parse_embed_chunks(text: str):
    chunks = []
    inside = False
    for line in text.splitlines():
        if line.strip() == "S.PayloadBase64Chunks = {":
            inside = True
            continue
        if inside and line.strip() == "}":
            break
        if inside:
            m = re.fullmatch(r'\s*"([A-Za-z0-9+/=]+)",\s*', line)
            if m:
                chunks.append(m.group(1))
    return chunks


def combined_opcode_observation():
    outer = {x["raw"]: x for x in json.loads((ROOT / "outer_opcode_usage.json").read_text())}
    payload = {x["raw"]: x for x in json.loads((ROOT / "payload_opcode_usage.json").read_text())}
    observed = []
    inferred = []
    rows = []
    for raw in range(47):
        semantic = outer.get(raw, payload.get(raw, {})).get("semantic")
        oc = outer.get(raw, {}).get("count", 0)
        pc = payload.get(raw, {}).get("count", 0)
        direct = (oc + pc) > 0
        (observed if direct else inferred).append(raw)
        rows.append({
            "raw": raw,
            "semantic": semantic,
            "outer_count": oc,
            "payload_count": pc,
            "directly_observed": direct,
        })
    return observed, inferred, rows


def validate():
    checks = {}

    baseline = BASELINE.read_bytes()
    assert len(baseline) == EXPECTED_BASELINE_SIZE
    assert sha_bytes(baseline) == EXPECTED_BASELINE_SHA
    checks["baseline_identity"] = True

    payload = PAYLOAD_BIN.read_bytes()
    assert len(payload) == EXPECTED_PAYLOAD_SIZE
    assert sha_bytes(payload) == EXPECTED_PAYLOAD_SHA
    checks["payload_identity"] = True

    b64_text = PAYLOAD_B64.read_text(encoding="ascii").strip()
    decoded = base64.b64decode(b64_text, validate=True)
    assert decoded == payload
    checks["payload_b64_decodes_exact"] = True

    chunks = parse_embed_chunks(PAYLOAD_EMBED.read_text(encoding="utf-8"))
    assert len(chunks) == 801, len(chunks)
    assert "".join(chunks) == b64_text
    checks["payload_embed_801_fragments_exact"] = True

    baseline_std = transform(baseline, "to-standard", 8)
    baseline_back = transform(baseline_std, "to-custom", 4)
    assert baseline_back == baseline
    checks["baseline_opcode_roundtrip_exact"] = True

    payload_std = transform(payload, "to-standard", 8)
    payload_back = transform(payload_std, "to-custom", 4)
    assert payload_back == payload
    checks["payload_opcode_roundtrip_exact"] = True

    standard = STANDARD.read_bytes()
    custom = CUSTOM.read_bytes()
    custom_std = transform(custom, "to-standard", 8)
    assert custom_std == standard
    custom_back = transform(custom_std, "to-custom", 4)
    assert custom_back == custom
    checks["custom_standard_roundtrip_exact"] = True

    standard_scanner = Scanner(standard)
    standard_header = standard_scanner.scan()
    custom_scanner = Scanner(custom)
    custom_header = custom_scanner.scan()
    assert standard_header["version"] == 0x53
    assert custom_header["version"] == 0x53
    assert custom_header["sizet_size"] == 4
    checks["lua53_chunk_structure"] = True

    lua, lua_version = find_lua_runner()
    smoke_out = run_checked([lua, str(ROOT / "tests" / "smoke.lua"), str(ROOT)])
    assert "smoke: ok" in smoke_out
    checks["smoke_tests"] = "passed"

    protocol_out = run_checked([lua, str(ROOT / "tests" / "protocol_fixture.lua"), str(ROOT)])
    assert "protocol-fixture: ok" in protocol_out
    checks["protocol_fixture"] = "passed"

    observed, inferred, opcode_rows = combined_opcode_observation()

    report = {
        "baseline": file_record(BASELINE),
        "embedded_payload": file_record(PAYLOAD_BIN),
        "rebuild_source": file_record(SOURCE),
        "rebuild_standard": file_record(STANDARD),
        "rebuild_custom": file_record(CUSTOM),
        "toolchain": {
            "lua_runner": lua,
            "lua_version": lua_version,
        },
        "opcode_evidence": {
            "directly_observed_raw_opcodes": observed,
            "inferred_only_raw_opcodes": inferred,
            "rows": opcode_rows,
        },
        "protocol_fixture": {
            "card": "CARD-TEST-001",
            "device": "DEVICE-TEST",
            "timestamp": 1700000000,
            "challenge": "42421700000000",
            "sign": "53d59cfbc96297ca3b013ad9784b6951",
            "wire_app_value": "3731343338",
            "cipher_hex_sha256": sha_bytes(bytes.fromhex(
                "a47752dde6fa03b45bba176f86ababddd664e4b7fb7f97ac91f2f56c50179d54"
                "feaeecee37fb7eff97a81c48fe9bc189543630549e4f544ac8402bd3e9ece7de"
                "7f6573db5c2dafa622a1dff85916cbb471fa64362b1ee7756e98a9091d5cd04d"
                "f22d10f6bfe5a5603db949dfbb0332"
            )),
        },
        "checks": {
            **checks,
            "crypto_rc4_vector": "bbf316e8d940af0ad3",
            "crypto_md5_vector": "900150983cd24fb0d6963f7d28e17f72",
            "game_runtime_test": False,
        },
    }
    VALIDATION.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"validation: ok -> {VALIDATION}")
    print(f"direct opcodes: {len(observed)}/47; inferred-only: {inferred}")
    return report


if __name__ == "__main__":
    validate()

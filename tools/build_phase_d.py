#!/usr/bin/env python3
import hashlib
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "spectra"
BUNDLE = ROOT / "spectra_wrapper_phase_d_source.lua"
STANDARD = ROOT / "spectra_wrapper_phase_d.standard.luac"
CUSTOM = ROOT / "spectra_wrapper_phase_d.custom.luac"
REMAP = ROOT / "tools" / "remap_lua53.py"

MODULES = [
    "runtime.lua", "crypto.lua", "storage.lua", "transport.lua", "payload_embed.lua",
    "aim_runtime.lua", "visual_runtime.lua", "aim_abi.lua", "p029_runtime_helpers.lua", "mutation_runtime.lua", "aim_mutation.lua", "aim_bones.lua", "aim_chain.lua", "aim_refresh.lua", "visual_scan.lua", "feature_control.lua", "character_visuals.lua", "native_settings_ui.lua", "payload_feature_bridge.lua", "payload_visual_bridge.lua", "product_context.lua", "product_module.lua", "product_constructor.lua", "product_module_bridge.lua", "payload_ui_bridge.lua", "payload_loader.lua",
    "auth.lua", "login_ui.lua", "bootstrap.lua",
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def find_luac():
    for name in ("luac5.3", "texluac", "luac"):
        path = shutil.which(name)
        if path:
            out = subprocess.run([path, "-v"], text=True, capture_output=True)
            if "Lua 5.3" in (out.stdout + out.stderr):
                return path
    raise SystemExit("Lua 5.3 compiler not found")

def bundle():
    parts = [
        "-- SPECTRA Phase-D wrapper: clean auth + reconstructed UI/feature/visual runtime.",
        "-- Embedded payload remains byte-identical; source owns no_recoil/converge, aim/anti_shake, and public visual entries after init with transactional fallback.",
        "local S = {}",
    ]
    for name in MODULES:
        text = (SRC / name).read_text(encoding="utf-8")
        parts += [f"\n-- BEGIN {name}", ";(function(...)", text, "end)(S)", f"-- END {name}"]
    parts += ["", "return S.Bootstrap.start()", ""]
    BUNDLE.write_text("\n".join(parts), encoding="utf-8")

def main():
    bundle()
    luac = find_luac()
    subprocess.run([luac, "-p", str(BUNDLE)], check=True)
    subprocess.run([luac, "-s", "-o", str(STANDARD), str(BUNDLE)], check=True)
    subprocess.run([sys.executable, str(REMAP), "--to-custom", "--target-size-t", "4", str(STANDARD), str(CUSTOM)], check=True)
    print(f"source:   {BUNDLE} size={BUNDLE.stat().st_size} sha256={sha(BUNDLE)}")
    print(f"standard: {STANDARD} size={STANDARD.stat().st_size} sha256={sha(STANDARD)}")
    print(f"custom:   {CUSTOM} size={CUSTOM.stat().st_size} sha256={sha(CUSTOM)}")

if __name__ == "__main__": main()

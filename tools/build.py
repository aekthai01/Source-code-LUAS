#!/usr/bin/env python3
import hashlib
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "spectra"
BUNDLE = ROOT / "spectra_wrapper_source.lua"
STANDARD = ROOT / "spectra_wrapper.standard.luac"
CUSTOM = ROOT / "spectra_wrapper.custom.luac"
REMAP = ROOT / "tools" / "remap_lua53.py"
VALIDATE = ROOT / "tools" / "validate.py"

MODULES = [
    "runtime.lua",
    "crypto.lua",
    "storage.lua",
    "transport.lua",
    "payload_embed.lua",
    "payload_loader.lua",
    "auth.lua",
    "login_ui.lua",
    "bootstrap.lua",
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def find_luac():
    for name in ("luac5.3", "texluac", "luac"):
        path = shutil.which(name)
        if path:
            out = subprocess.run([path, "-v"], text=True, capture_output=True)
            version = (out.stdout + out.stderr).strip()
            if "Lua 5.3" in version:
                return path
    raise SystemExit("Lua 5.3 compiler not found (tried luac5.3, texluac, luac)")

def bundle():
    parts = [
        "-- Reconstructed SPECTRA wrapper from verified Lua 5.3 baseline.",
        "-- Embedded payload remains byte-identical to the baseline payload.",
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
    subprocess.run([
        sys.executable, str(REMAP), "--to-custom", "--target-size-t", "4",
        str(STANDARD), str(CUSTOM)
    ], check=True)

    print(f"source:   {BUNDLE} sha256={sha(BUNDLE)}")
    print(f"standard: {STANDARD} sha256={sha(STANDARD)}")
    print(f"custom:   {CUSTOM} sha256={sha(CUSTOM)}")

    subprocess.run([sys.executable, str(VALIDATE)], check=True)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

# Production order is AimABI -> P029RuntimeHelpers -> MutationRuntime/VisualScan.
# Unit files may load modules directly, so normalize only those direct loaders.
for test in sorted((ROOT / "tests").glob("*.lua")):
    text = test.read_text(encoding="utf-8")
    if "src/spectra/mutation_runtime.lua" not in text and "src/spectra/visual_scan.lua" not in text:
        continue

    direct = re.search(
        r'(?m)^(?P<line>[^\n]*loadfile\([^\n]*(?:mutation_runtime|visual_scan)\.lua[^\n]*\)\(S\)\s*)$',
        text,
    )
    if not direct:
        raise SystemExit(f"{test}: could not locate direct runtime/visual loader")

    # Remove any later/earlier direct helper loads first so there is exactly one
    # dependency sequence immediately before the first consumer.
    text = re.sub(
        r'(?m)^\s*assert\(loadfile\([^\n]*src/spectra/(?:aim_abi|p029_runtime_helpers)\.lua[^\n]*\)\)\(S\)\s*\n?',
        '',
        text,
    )
    direct = re.search(
        r'(?m)^(?P<line>[^\n]*loadfile\([^\n]*(?:mutation_runtime|visual_scan)\.lua[^\n]*\)\(S\)\s*)$',
        text,
    )
    if not direct:
        raise SystemExit(f"{test}: consumer loader disappeared during normalization")

    preload = (
        'assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)\n'
        'assert(loadfile(root .. "/src/spectra/p029_runtime_helpers.lua"))(S)\n'
    )
    text = text[:direct.start()] + preload + text[direct.start():]
    test.write_text(text, encoding="utf-8")
    print(f"normalized {test.relative_to(ROOT)}")

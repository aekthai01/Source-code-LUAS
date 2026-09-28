#!/usr/bin/env python3
"""Focused exact-fidelity validator for source-owned P0.29.73."""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PAY="a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263"

def block_map():
    out={}
    text=(ROOT/"payload_disassembly.txt").read_text()
    for piece in re.split(r"^=== PROTO ",text,flags=re.M)[1:]:
        header,*body=piece.splitlines(); out[header.split(" ",1)[0]]="\n".join(body)
    return out

def lua_runner():
    for name in ("lua5.3","texlua","lua"):
        path=shutil.which(name)
        if path:
            q=subprocess.run([path,"-e","print(_VERSION)"],text=True,capture_output=True)
            if q.returncode==0 and "Lua 5.3" in q.stdout+q.stderr: return path
    raise RuntimeError("Lua 5.3 runner not found")

meta={x["path"]:x for x in json.loads((ROOT/"payload_prototypes.json").read_text())}
p=meta["0.29.73"]
expected=[{"instack":1,"idx":0},{"instack":0,"idx":0},{"instack":1,"idx":85},{"instack":1,"idx":37},{"instack":1,"idx":93},{"instack":1,"idx":96},{"instack":1,"idx":97}]
assert (p["numparams"],p["instruction_count"],len(p["upvalues"]),p["child_count"])==(2,81,7,0)
assert p["upvalues"]==expected
D=block_map(); root=D["0.29"]; p73=D["0.29.73"]
for pc,reg,child in ((332,37,17),(1045,85,60),(1053,93,68),(1056,96,71),(1057,97,72),(1058,98,73)):
    assert re.search(rf"^{pc:04d} CLOSURE\s+R{reg}, P{child}$",root,re.M),(pc,reg,child)
assert re.search(r"^1063 LOADK\s+R103, K330='set_dongdong_feature_config'$",root,re.M)
assert re.search(r"^1064 SETTABLE\s+R0, R103, R98$",root,re.M)

# Toggle-table type gate and aim/anti strict-boolean branch.
patterns=[
 r"^0003 GETTABUP\s+R2, U0, K0='custom_dongdong_toggle_state'$",
 r"^0004 GETTABUP\s+R3, U1, K1='type'$",
 r"^0007 EQ\s+A=1 R3, K2='table'$",
 r"^0011 SETTABUP\s+U0, K0='custom_dongdong_toggle_state', R2$",
 r"^0012 EQ\s+A=1 R0, K3='aim'$", r"^0014 EQ\s+A=0 R0, K4='anti_shake'$",
 r"^0016 EQ\s+A=0 R1, K5=True$", r"^0018 SETTABLE\s+R2, R0, K5=True$",
 r"^0021 SETTABLE\s+R2, K4='anti_shake', K6=False$", r"^0023 SETTABLE\s+R2, K3='aim', K6=False$",
 r"^0025 SETTABLE\s+R2, R0, K6=False$",
 r"^0026 GETUPVAL\s+R3, U2$", r"^0027 CALL\s+A=3 B=1 C=1$",
 r"^0028 GETUPVAL\s+R3, U3$", r"^0029 LOADK\s+R4, K4='anti_shake'$", r"^0030 CALL\s+A=3 B=2 C=1$",
 r"^0031 GETUPVAL\s+R3, U3$", r"^0032 LOADK\s+R4, K3='aim'$", r"^0033 CALL\s+A=3 B=2 C=1$",
 r"^0034 GETTABLE\s+R3, R2, K3='aim'$", r"^0035 EQ\s+A=1 R3, K5=True$",
 r"^0037 GETTABLE\s+R3, R2, K4='anti_shake'$", r"^0038 EQ\s+A=1 R3, K5=True$",
 r"^0044 GETUPVAL\s+R4, U4$", r"^0045 LOADK\s+R5, K3='aim'$", r"^0046 CALL\s+A=4 B=2 C=1$",
 r"^0047 GETUPVAL\s+R4, U5$", r"^0049 CALL\s+A=4 B=2 C=1$",
 r"^0050 GETUPVAL\s+R4, U6$", r"^0051 GETTABLE\s+R5, R2, K3='aim'$", r"^0052 EQ\s+A=1 R5, K5=True$", r"^0056 CALL\s+A=4 B=2 C=1$",
 r"^0057 LOADBOOL\s+A=4 B=1 C=0$", r"^0058 RETURN\s+A=4 B=2 C=0$",
 # non-aim literal-true normalization and supported-feature gate
 r"^0059 EQ\s+A=1 R1, K5=True$", r"^0063 SETTABLE\s+R2, R0, R3$",
 r"^0064 EQ\s+A=1 R0, K7='no_recoil'$", r"^0066 EQ\s+A=1 R0, K8='converge'$",
 r"^0068 LOADBOOL\s+A=3 B=0 C=0$", r"^0069 RETURN\s+A=3 B=2 C=0$",
 r"^0070 GETUPVAL\s+R3, U3$", r"^0072 CALL\s+A=3 B=2 C=1$",
 r"^0073 EQ\s+A=0 R1, K5=True$", r"^0075 GETUPVAL\s+R3, U4$", r"^0077 CALL\s+A=3 B=2 C=1$",
 r"^0078 LOADBOOL\s+A=3 B=1 C=0$", r"^0079 RETURN\s+A=3 B=2 C=0$",
]
for pattern in patterns: assert re.search(pattern,p73,re.M),pattern

artifact=json.loads((ROOT/"P029_FEATURE_CONTROL_MAP.json").read_text())
assert artifact["_meta"]["payload_sha256"]==PAY
assert artifact["_meta"]["ownership_boundary"]==["0.29.73"]
assert artifact["_meta"]["payload_closure_rebinding"] is False
e=artifact["prototypes"]["0.29.73"]
assert (e["params"],e["instruction_count"],len(e["upvalues"]),e["children"])==(2,81,7,0)
assert e["p029_parent_register"]=="R98" and e["p029_closure_instruction"]==1058
assert [(x["upvalue"],x.get("register"),x.get("prototype")) for x in e["captured_helper_prototype_register_mapping"]]==[
    ("U2","R85","0.29.60"),("U3","R37","0.29.17"),("U4","R93","0.29.68"),("U5","R96","0.29.71"),("U6","R97","0.29.72")]
assert e["source_only_dependency"] is True and e["current_ownership"]=="source_owned" and e["payload_closure_rebinding"] is False

inv=json.loads((ROOT/"FULL_PAYLOAD_PROTOTYPE_INDEX.json").read_text())
assert "0.29.73" in inv["ownership_groups"]["source_owned"]
assert inv["source_files"]["0.29.73"]=="src/spectra/feature_control.lua"
assert {"0.29.69","0.29.70"} <= set(inv["ownership_groups"]["payload_owned"])
assert "0.29.77" in inv["ownership_groups"]["source_owned"]

source=(ROOT/"src/spectra/feature_control.lua").read_text()
bridge=(ROOT/"src/spectra/payload_feature_bridge.lua").read_text()
assert 'function M.make_feature_config(captured_state, captured_deps)' in source
assert 'return function(feature, enabled)' in source
assert 'local feature_config_029_73 = FeatureControl.make_feature_config(_G, deps)' in bridge
assert 'local feature_entry = make_feature_entry(feature_config_029_73)' in bridge
assert 'make_aim_part_entry(deps, feature_config_029_73)' in bridge
assert 'if not source_owned(feature' not in bridge

lua=lua_runner()
run=subprocess.run([lua,str(ROOT/"tests/p029_feature_control.lua"),str(ROOT)],text=True,capture_output=True,cwd=ROOT)
if run.returncode:
    raise RuntimeError(run.stdout+run.stderr)
assert "p029-feature-control: ok" in run.stdout+run.stderr
print("p029-feature-control-validation: ok")

#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def rep(path,old,new,count=1):
 p=ROOT/path; s=p.read_text(); n=s.count(old); assert n==count,(path,n,old[:100]); p.write_text(s.replace(old,new,count))

rep('tools/aim_forensics.py',
'''NESTED = [\n    "0.29.62.0",\n''',
'''NESTED = [\n    "0.29.17.0",\n    "0.29.62.0",\n''')
rep('tools/aim_forensics.py','''assert len(NESTED) == 11\n''','''assert len(NESTED) == 12\n''')
rep('tools/aim_forensics.py','''assert len(ALL) == 56 and len(set(ALL)) == 56\n''','''assert len(ALL) == 57 and len(set(ALL)) == 57\n''')
rep('tools/aim_forensics.py',
'''    if pid in AIM_RUNTIME:\n        return "src/spectra/aim_runtime.lua"\n    if pid.startswith("0.29.77"):\n''',
'''    if pid in AIM_RUNTIME:\n        return "src/spectra/aim_runtime.lua"\n    if pid == "0.29.17.0":\n        return "src/spectra/mutation_runtime.lua"\n    if pid.startswith("0.29.77"):\n''')
rep('tools/aim_forensics.py','''        "nested_callbacks": 11,\n''','''        "nested_callbacks": 12,\n''')
rep('tools/aim_forensics.py','''        "indexed_entries_total": 56,\n''','''        "indexed_entries_total": 57,\n''')
rep('tools/aim_forensics.py',
'''    elif pid == "0.29.10":\n        item.update(reconstructed_name="normalize_identifier", evidence_status="17-instruction environment-only gsub tail-return helper; two-value return pinned")\n''',
'''    elif pid == "0.29.17.0":\n        item.update(reconstructed_name="restore_feature_snapshot assignment child", evidence_status="8-instruction P17 child; captures parent R8 record; object/key/value assignment; zero-value return pinned")\n    elif pid == "0.29.10":\n        item.update(reconstructed_name="normalize_identifier", evidence_status="17-instruction environment-only gsub tail-return helper; two-value return pinned")\n''')

rep('tests/p029_mutation_primitives.lua',
'''_G.ULuaArrayHelper=nil\n\nprint("p029-mutation-primitives: ok")\n''',
'''_G.ULuaArrayHelper=nil\n\n-- P0.29.17.0 is the zero-return child assignment closure used by P17 restore.\nlocal restore_obj={x=9}\nlocal restore_state={\n  custom_dongdong_feature_snapshots={\n    demo={records={{object=restore_obj,key="x",value=4}},seen={}}\n  }\n}\nlocal restored=packed(M.restore_feature_snapshot,restore_state,"demo")\neq(restored.n,1,"P17 parent arity"); eq(restored[1],true,"P17 child success"); eq(restore_obj.x,4,"P17 child assignment")\neq(restore_state.custom_dongdong_feature_snapshots.demo,nil,"P17 snapshot cleared")\n\n-- Assignment error is swallowed by the parent pcall; child is not retried.\nlocal writes=0\nlocal blocked=setmetatable({}, {__newindex=function() writes=writes+1; error("blocked") end})\nlocal fail_state={\n  custom_dongdong_feature_snapshots={\n    demo={records={{object=blocked,key="x",value=7}},seen={}}\n  }\n}\nlocal failed=packed(M.restore_feature_snapshot,fail_state,"demo")\neq(failed.n,1,"P17 failure arity"); eq(failed[1],false,"P17 child failure"); eq(writes,1,"P17 child no retry")\neq(fail_state.custom_dongdong_feature_snapshots.demo,nil,"P17 failed snapshot cleared")\n\nprint("p029-mutation-primitives: ok")\n''')

rep('tools/validate_phase_d.py',
'''    # P0.29.15 is not migrated here, but its active source reconstruction must\n''',
'''    # P0.29.17.0 is the exact assignment child already executed by source-owned P17.\n    p170=prototypes['0.29.17.0']\n    assert (p170['numparams'],p170['instruction_count'],len(p170['upvalues']),p170['child_count'])==(0,8,1,0)\n    assert p170['upvalues']==[{'instack':1,'idx':8}]\n    assert '0.29.17' in groups['source_owned'] and '0.29.17.0' in groups['source_owned']\n    assert source_files['0.29.17.0']=='src/spectra/mutation_runtime.lua'\n    p17=body('0.29.17'); p170_body=body('0.29.17.0')\n    assert re.search(r"^0044 GETTABUP\\s+R9, U1, K9='pcall'$",p17,re.M)\n    assert re.search(r'^0045 CLOSURE\\s+R10, P0$',p17,re.M)\n    assert re.search(r'^0046 CALL\\s+A=9 B=2 C=2$',p17,re.M)\n    assert re.search(r"^0003 GETTABUP\\s+R0, U0, K0='object'$",p170_body,re.M)\n    assert re.search(r"^0004 GETTABUP\\s+R1, U0, K1='key'$",p170_body,re.M)\n    assert re.search(r"^0005 GETTABUP\\s+R2, U0, K2='value'$",p170_body,re.M)\n    assert re.search(r'^0006 SETTABLE\\s+R0, R1, R2$',p170_body,re.M)\n    assert re.search(r'^0007 RETURN\\s+A=0 B=1 C=0$',p170_body,re.M)\n\n    # P0.29.15 is not migrated here, but its active source reconstruction must\n''')
rep('tools/validate_phase_d.py',"'phase':'E5.12-p029-mutation-primitives-source-only'","'phase':'E5.13-p029-17-child-source-only'")
rep('tools/validate_phase_d.py',"'p029_mutation_helper_map':'passed',","'p029_mutation_helper_map':'passed','p029_17_child_exact':'passed',")
print('p029-17-child-patch: ok')

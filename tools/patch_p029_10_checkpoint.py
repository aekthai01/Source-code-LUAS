#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def replace(path, old, new, count=1):
    p=ROOT/path
    s=p.read_text(encoding='utf-8')
    actual=s.count(old)
    assert actual==count, (path, actual, old[:80])
    p.write_text(s.replace(old,new,count),encoding='utf-8')

# aim_forensics: add P0.29.10 as a distinct source-owned mutation helper.
replace('tools/aim_forensics.py',
'''RUNTIME_HELPERS = ["0.29.5", "0.29.6", "0.29.8", "0.29.11", "0.29.13"]\nAIM_RUNTIME = ["0.29.71", "0.29.71.0", "0.29.72", "0.29.72.0"]\nALL = [*PRIMARY, *OUTER, *NESTED, *ABI_HELPERS, *RUNTIME_HELPERS, *AIM_RUNTIME]\n''',
'''RUNTIME_HELPERS = ["0.29.5", "0.29.6", "0.29.8", "0.29.11", "0.29.13"]\nMUTATION_HELPERS = ["0.29.10"]\nAIM_RUNTIME = ["0.29.71", "0.29.71.0", "0.29.72", "0.29.72.0"]\nALL = [*PRIMARY, *OUTER, *NESTED, *ABI_HELPERS, *RUNTIME_HELPERS, *MUTATION_HELPERS, *AIM_RUNTIME]\n''')
replace('tools/aim_forensics.py',
'''assert len(RUNTIME_HELPERS) == 5\nassert len(AIM_RUNTIME) == 4\nassert len(ALL) == 53 and len(set(ALL)) == 53\n''',
'''assert len(RUNTIME_HELPERS) == 5\nassert len(MUTATION_HELPERS) == 1\nassert len(AIM_RUNTIME) == 4\nassert len(ALL) == 54 and len(set(ALL)) == 54\n''')
replace('tools/aim_forensics.py',
'''    if pid in RUNTIME_HELPERS:\n        return "src/spectra/p029_runtime_helpers.lua"\n    if pid in AIM_RUNTIME:\n''',
'''    if pid in RUNTIME_HELPERS:\n        return "src/spectra/p029_runtime_helpers.lua"\n    if pid in MUTATION_HELPERS:\n        return "src/spectra/mutation_runtime.lua"\n    if pid in AIM_RUNTIME:\n''')
replace('tools/aim_forensics.py',
'''assert set(RUNTIME_HELPERS) <= set(D)\nassert set(AIM_RUNTIME) <= set(D)\n''',
'''assert set(RUNTIME_HELPERS) <= set(D)\nassert set(MUTATION_HELPERS) <= set(D)\nassert set(AIM_RUNTIME) <= set(D)\n''')
replace('tools/aim_forensics.py',
'''    "0.29.8": "R25",\n    "0.29.11": "R31",\n''',
'''    "0.29.8": "R25",\n    "0.29.10": "R30",\n    "0.29.11": "R31",\n''')
replace('tools/aim_forensics.py',
'''        "runtime_helpers": 5,\n        "aim_runtime": 4,\n        "indexed_entries_total": 53,\n''',
'''        "runtime_helpers": 5,\n        "mutation_helpers": 1,\n        "aim_runtime": 4,\n        "indexed_entries_total": 54,\n''')
replace('tools/aim_forensics.py',
'''    elif pid in RUNTIME_HELPERS:\n        category = "runtime_helper"\n    elif pid in AIM_RUNTIME:\n''',
'''    elif pid in RUNTIME_HELPERS:\n        category = "runtime_helper"\n    elif pid in MUTATION_HELPERS:\n        category = "mutation_helper"\n    elif pid in AIM_RUNTIME:\n''')
replace('tools/aim_forensics.py',
'''    elif pid in RUNTIME_HELPERS:\n        item.update(\n            reconstructed_name=RUNTIME_SOURCE_SYMBOLS[pid],\n            evidence_status="exact bytecode shape, root register/captures, source integration, capture identity and return contract pinned",\n        )\n    elif pid == "0.29.71":\n''',
'''    elif pid in RUNTIME_HELPERS:\n        item.update(\n            reconstructed_name=RUNTIME_SOURCE_SYMBOLS[pid],\n            evidence_status="exact bytecode shape, root register/captures, source integration, capture identity and return contract pinned",\n        )\n    elif pid == "0.29.10":\n        item.update(\n            reconstructed_name="MutationRuntime.normalize_identifier",\n            evidence_status="17-instruction R30 helper; env-only capture; TESTSET value-or-empty semantics; gsub tailcall exact two-return ABI pinned",\n        )\n    elif pid == "0.29.71":\n''')

# Focused exact-return regression in the existing mutation runtime suite.
replace('tests/mutation_runtime.lua',
'''local function truth(v,m) if not v then error(m or "expected truthy",2) end end\n\n-- Exact path inventory recovered from the parent constants feeding P0.29.68.\n''',
'''local function truth(v,m) if not v then error(m or "expected truthy",2) end end\nlocal function packed(fn,...) return table.pack(fn(...)) end\n\n-- P0.29.10 normalize_identifier is a gsub tailcall and therefore returns\n-- exactly two values: normalized string plus replacement count.\nlocal p10_nil=packed(M.normalize_identifier,nil)\neq(p10_nil.n,2,"P10 nil arity"); eq(p10_nil[1],"","P10 nil value"); eq(p10_nil[2],0,"P10 nil replacement count")\nlocal p10_false=packed(M.normalize_identifier,false)\neq(p10_false.n,2,"P10 false arity"); eq(p10_false[1],"","P10 false value"); eq(p10_false[2],0,"P10 false replacement count")\nlocal p10_text=packed(M.normalize_identifier,"A-B")\neq(p10_text.n,2,"P10 text arity"); eq(p10_text[1],"ab","P10 normalized text"); eq(p10_text[2],1,"P10 replacement count")\nlocal p10_number=packed(M.normalize_identifier,123)\neq(p10_number.n,2,"P10 number arity"); eq(p10_number[1],"123","P10 number text"); eq(p10_number[2],0,"P10 number replacement count")\n\n-- Exact path inventory recovered from the parent constants feeding P0.29.68.\n''')

# Validator: pin P10 metadata, root closure placement, bytecode ABI and source mapping.
replace('tools/validate_phase_d.py',
'''    # P0.29.15 is not migrated here, but its active source reconstruction must\n''',
'''    # P0.29.10 normalize_identifier: env-only helper at root R30. The gsub\n    # TAILCALL intentionally forwards both string.gsub results.\n    p10_meta=prototypes['0.29.10']\n    assert (p10_meta['numparams'],p10_meta['instruction_count'],len(p10_meta['upvalues']),p10_meta['child_count'])==(1,17,1,0)\n    assert p10_meta['upvalues']==[{'instack':0,'idx':0}]\n    assert '0.29.10' in groups['source_owned']\n    assert source_files['0.29.10']=='src/spectra/mutation_runtime.lua'\n    p10=body('0.29.10')\n    assert re.search(r'^0325 CLOSURE\\s+R30, P10$',body('0.29'),re.M)\n    assert re.search(r"^0003 GETTABUP\\s+R1, U0, K0='string'$",p10,re.M)\n    assert re.search(r"^0005 GETTABUP\\s+R2, U0, K2='tostring'$",p10,re.M)\n    assert re.search(r'^0006 TESTSET\\s+R3, R0 C=1$',p10,re.M)\n    assert re.search(r"^0008 LOADK\\s+R3, K3=''$",p10,re.M)\n    assert re.search(r"^0011 SELF\\s+R1, R1, K4='gsub'$",p10,re.M)\n    assert re.search(r"^0012 LOADK\\s+R3, K5='\\[\\^%w\\]'$",p10,re.M)\n    assert re.search(r'^0014 TAILCALL\\s+A=1 B=4 C=0$',p10,re.M)\n    assert re.search(r'^0015 RETURN\\s+A=1 B=0 C=0$',p10,re.M)\n    mutation_p10_source=(ROOT/'src/spectra/mutation_runtime.lua').read_text()\n    assert 'function M.normalize_identifier(value)' in mutation_p10_source\n    assert 'return string.lower(tostring(value or "")):gsub("[^%w]", "")' in mutation_p10_source\n\n    # P0.29.15 is not migrated here, but its active source reconstruction must\n''')
replace('tools/validate_phase_d.py',
'''      'phase':'E5.11-p029-71-72-source-only',\n''',
'''      'phase':'E5.12-p029-10-source-only',\n''')
replace('tools/validate_phase_d.py',
'''      'checks':{'baseline_identity':True,'payload_identity':True,'payload_embed_801_fragments_exact':True,'custom_standard_roundtrip_exact':True,'lua53_chunk_structure':True,'root_capture_map':'passed','root_download_bytecode_captures':'passed','p029_abi_helper_map':'passed','p029_abi_exact_return_shapes':'passed','p029_runtime_helper_map':'passed','mutation_runtime_abi_integration':'passed',\n''',
'''      'checks':{'baseline_identity':True,'payload_identity':True,'payload_embed_801_fragments_exact':True,'custom_standard_roundtrip_exact':True,'lua53_chunk_structure':True,'root_capture_map':'passed','root_download_bytecode_captures':'passed','p029_abi_helper_map':'passed','p029_abi_exact_return_shapes':'passed','p029_runtime_helper_map':'passed','p029_10_exact_tail_return':'passed','mutation_runtime_abi_integration':'passed',\n''')
print('p029-10-patch: ok')

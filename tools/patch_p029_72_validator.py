#!/usr/bin/env python3
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'tools/validate_phase_d.py'
s=p.read_text(encoding='utf-8')

def once(old,new):
    global s
    assert s.count(old)==1,(old[:100],s.count(old))
    s=s.replace(old,new,1)

# Runtime-helper evidence now also pins fixed source capture identity.
once('''        assert evidence['source_file']=='src/spectra/p029_runtime_helpers.lua'
        captures={(x['upvalue'],x['register'],x['prototype']) for x in evidence['captured_helper_registers']}
''','''        assert evidence['source_file']=='src/spectra/p029_runtime_helpers.lua'
        assert evidence['source_capture_identity']
        captures={(x['upvalue'],x['register'],x['prototype']) for x in evidence['captured_helper_registers']}
''')

# P72 pair moves ownership only in this checkpoint; capture gate's payload-owned guard must disappear.
once("    assert '0.29.72' in groups['payload_owned'] and '0.29.72.0' in groups['payload_owned']\n",'')

anchor='''    assert 'choose("delay", RuntimeHelpers.delay)' in bridge_source

    coverage_text=(ROOT/'RECONSTRUCTION_COVERAGE.md').read_text()
'''
insert=r'''    assert 'choose("delay", RuntimeHelpers.delay)' in bridge_source

    # Exact P0.29.72/.72.0 parent-child source ownership checkpoint.
    aim_runtime_paths={'0.29.72','0.29.72.0'}
    aim_runtime_evidence=json.loads((ROOT/'P029_AIM_RUNTIME_MAP.json').read_text())
    assert aim_runtime_evidence['_meta']['payload_sha256']==PAY
    assert aim_runtime_evidence['_meta']['payload_closure_rebinding'] is False
    assert set(aim_runtime_evidence['_meta']['ownership_boundary'])==aim_runtime_paths
    assert set(aim_runtime_evidence['prototypes'])==aim_runtime_paths
    assert aim_runtime_paths <= set(groups['source_owned'])
    assert all(source_files[path]=='src/spectra/aim_runtime.lua' for path in aim_runtime_paths)
    assert {'0.29.69','0.29.70','0.29.71','0.29.71.0','0.29.73'} <= set(groups['payload_owned'])

    p72_meta=prototypes['0.29.72']; p720_meta=prototypes['0.29.72.0']
    assert (p72_meta['numparams'],p72_meta['instruction_count'],len(p72_meta['upvalues']),p72_meta['child_count'])==(1,22,3,1)
    assert p72_meta['upvalues']==[{'instack':0,'idx':0},{'instack':1,'idx':19},{'instack':1,'idx':25}]
    assert (p720_meta['numparams'],p720_meta['instruction_count'],len(p720_meta['upvalues']),p720_meta['child_count'])==(0,76,3,0)
    assert p720_meta['upvalues']==[{'instack':0,'idx':0},{'instack':0,'idx':1},{'instack':1,'idx':1}]

    p72e=aim_runtime_evidence['prototypes']['0.29.72']
    p720e=aim_runtime_evidence['prototypes']['0.29.72.0']
    assert p72e['p029_parent_register']=='R97' and p72e['p029_closure_instruction']==1057
    assert p72e['child_prototype']=='0.29.72.0' and p72e['child_closure_register']=='R2' and p72e['child_closure_instruction']==9
    assert {(x['upvalue'],x['register'],x['prototype']) for x in p72e['captured_helper_registers']}=={
        ('U1','R19','0.29.2'),('U2','R25','0.29.8')}
    assert p72e['source_only_dependency'] is True and p72e['current_ownership']=='source_owned'
    assert p720e['source_only_dependency'] is True and p720e['current_ownership']=='source_owned'
    assert [x['upvalue'] for x in p720e['parent_capture_mapping']]==['U0','U1','U2']
    assert 'P0.29.72 U0 environment' in p720e['parent_capture_mapping'][0]['from']
    assert 'P0.29.2' in p720e['parent_capture_mapping'][1]['from']
    assert 'R1 command string' in p720e['parent_capture_mapping'][2]['from']

    p72=body('0.29.72')
    assert re.search(r'^0003 EQ\s+A=0 R0, K0=True$',p72,re.M)
    assert re.search(r"^0005 LOADK\s+R1, K1='weapon\.FireAssistedAimingDebugEnable 1'$",p72,re.M)
    assert re.search(r"^0008 LOADK\s+R1, K2='weapon\.FireAssistedAimingDebugEnable 0'$",p72,re.M)
    assert re.search(r'^0009 CLOSURE\s+R2, P0$',p72,re.M)
    assert re.search(r'^0011 CALL\s+A=3 B=1 C=2$',p72,re.M)
    assert re.search(r'^0012 GETUPVAL\s+R4, U2$',p72,re.M)
    assert re.search(r'^0013 LOADK\s+R5, K3=0\.35$',p72,re.M)
    assert re.search(r'^0015 CALL\s+A=4 B=3 C=1$',p72,re.M)
    assert re.search(r'^0016 GETUPVAL\s+R4, U2$',p72,re.M)
    assert re.search(r'^0017 LOADK\s+R5, K4=1\.2$',p72,re.M)
    assert re.search(r'^0019 CALL\s+A=4 B=3 C=1$',p72,re.M)
    assert re.search(r'^0020 RETURN\s+A=3 B=2 C=0$',p72,re.M)
    assert re.search(r'^1057 CLOSURE\s+R97, P72$',body('0.29'),re.M)

    p720=body('0.29.72.0')
    assert re.search(r"^0003 GETTABUP\s+R0, U0, K0='rawget'$",p720,re.M)
    assert re.search(r"^0005 LOADK\s+R2, K2='UKismetSystemLibrary'$",p720,re.M)
    assert re.search(r"^0009 LOADK\s+R3, K3='GetGameInstance'$",p720,re.M)
    assert re.search(r'^0011 EQ\s+A=0 R0, K4=None$',p720,re.M)
    assert re.search(r"^0015 LOADK\s+R4, K5='import'$",p720,re.M)
    assert re.search(r"^0020 EQ\s+A=0 R3, K7='function'$",p720,re.M)
    assert re.search(r"^0024 LOADK\s+R5, K2='UKismetSystemLibrary'$",p720,re.M)
    assert re.search(r'^0025 CALL\s+A=3 B=3 C=3$',p720,re.M)
    assert re.search(r'^0029 EQ\s+A=1 R0, K4=None$',p720,re.M)
    assert re.search(r"^0034 EQ\s+A=1 R2, K7='function'$",p720,re.M)
    assert re.search(r'^0040 CALL\s+A=2 B=2 C=3$',p720,re.M)
    assert re.search(r'^0043 EQ\s+A=0 R3, K4=None$',p720,re.M)
    assert re.search(r'^0047 GETUPVAL\s+R4, U1$',p720,re.M)
    assert re.search(r"^0049 LOADK\s+R6, K9='ExecuteConsoleCommand'$",p720,re.M)
    assert re.search(r'^0050 CALL\s+A=4 B=3 C=2$',p720,re.M)
    assert re.search(r"^0054 EQ\s+A=1 R5, K7='function'$",p720,re.M)
    assert re.search(r'^0061 GETUPVAL\s+R8, U2$',p720,re.M)
    assert re.search(r'^0062 LOADNIL\s+A=9 B=0 C=0$',p720,re.M)
    assert re.search(r'^0063 CALL\s+A=5 B=5 C=2$',p720,re.M)
    assert re.search(r'^0068 MOVE\s+R8, R0$',p720,re.M)
    assert re.search(r'^0070 GETUPVAL\s+R10, U2$',p720,re.M)
    assert re.search(r'^0071 LOADNIL\s+A=11 B=0 C=0$',p720,re.M)
    assert re.search(r'^0072 CALL\s+A=6 B=6 C=2$',p720,re.M)
    assert re.search(r'^0074 RETURN\s+A=5 B=2 C=0$',p720,re.M)

    aim_runtime_source=(ROOT/'src/spectra/aim_runtime.lua').read_text()
    assert 'local ABI = assert(S.AimABI, "AimABI required")' in aim_runtime_source
    assert 'local RuntimeHelpers = assert(S.P029RuntimeHelpers, "P0.29 runtime helpers required")' in aim_runtime_source
    assert 'local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")' in aim_runtime_source
    assert 'local delay_029_8 = assert(RuntimeHelpers.delay, "P0.29.8 required")' in aim_runtime_source
    assert 'function M.set_fire_assisted_aim_debug(enabled)' in aim_runtime_source
    assert 'delay_029_8(0.35, apply)' in aim_runtime_source and 'delay_029_8(1.2, apply)' in aim_runtime_source
    assert 'Runtime.delay' not in aim_runtime_source
    assert 'S.P029RuntimeHelpers.delay(' not in aim_runtime_source
    assert 'AimRuntime.set_fire_assisted_aim_debug(Runtime.delay' not in bridge_source
    assert 'AimRuntime.set_fire_assisted_aim_debug(enabled)' in bridge_source

    coverage_text=(ROOT/'RECONSTRUCTION_COVERAGE.md').read_text()
'''
assert s.count(anchor)==1
s=s.replace(anchor,insert,1)

once("      'phase':'E5.9a-p029-capture-identity-fidelity',", "      'phase':'E5.10-p029-72-source-only',")
once("'p029_runtime_helpers':True,'payload_upvalue_introspection':False", "'p029_runtime_helpers':True,'p029_aim_runtime':True,'payload_upvalue_introspection':False")
once("'p029_capture_identity':'passed','source_only_product_constructor'", "'p029_capture_identity':'passed','p029_aim_runtime_map':'passed','p029_72_exact_parent_child':'passed','source_only_product_constructor'")

p.write_text(s,encoding='utf-8')
print('patched exact P0.29.72 validator')

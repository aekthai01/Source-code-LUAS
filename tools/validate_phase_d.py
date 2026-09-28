#!/usr/bin/env python3
import base64, hashlib, json, re, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from remap_lua53 import Scanner, transform
BASE='35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536'
PAY='a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263'
OWN={'source_owned','payload_owned','partially_reconstructed','dead_or_unreachable_verified','unknown'}

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def rec(p): p=Path(p); return {'size':p.stat().st_size,'sha256':sha(p)}
def lua_runner():
    for name in ('texlua','lua5.3','lua'):
        p=shutil.which(name)
        if p:
            q=subprocess.run([p,'-e','print(_VERSION)'],text=True,capture_output=True)
            if q.returncode==0 and 'Lua 5.3' in q.stdout+q.stderr: return p
    raise RuntimeError('Lua 5.3 runner not found')
def run(cmd):
    p=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if p.returncode: raise RuntimeError(' '.join(map(str,cmd))+'\n'+p.stdout+p.stderr)
    return p.stdout+p.stderr

def main():
    baseline=ROOT/'baseline_original.luac'; payload=ROOT/'embedded_payload.bin'
    source=ROOT/'spectra_wrapper_phase_d_source.lua'; standard=ROOT/'spectra_wrapper_phase_d.standard.luac'; custom=ROOT/'spectra_wrapper_phase_d.custom.luac'
    assert baseline.stat().st_size==180034 and sha(baseline)==BASE
    assert payload.stat().st_size==108533 and sha(payload)==PAY

    inv=json.loads((ROOT/'FULL_PAYLOAD_PROTOTYPE_INDEX.json').read_text())
    meta=json.loads((ROOT/'payload_prototypes.json').read_text())
    paths={p['path'] for p in meta}; groups=inv['ownership_groups']; coverage=inv['coverage']
    assert len(meta)==296 and inv['_meta']['total_prototypes']==296 and set(groups)==OWN
    classified=[p for status in OWN for p in groups[status]]
    assert len(classified)==296 and len(set(classified))==296 and set(classified)==paths
    assert coverage['classified']==296 and coverage['unknown']==0
    for status in OWN: assert coverage[status]==len(groups[status])
    source_files=inv['source_files']
    assert set(source_files)==set(groups['source_owned'])
    for source_file in set(source_files.values()): assert (ROOT/source_file).is_file(),source_file
    roots=inv['root_public_methods']; assert len(roots)==29
    assert [v['prototype_id'] for v in roots.values()]==[f'P0.{i}' for i in range(29)]
    root_source_owned=0
    for i,(name,item) in enumerate(roots.items()):
        path=f'0.{i}'
        owned=next(status for status in OWN if path in groups[status])
        assert item['current_ownership']==owned,name
        if owned=='source_owned':
            root_source_owned+=1
            assert item['source_only_dependency'] is True and item['source_file']==source_files[path],name
        else:
            assert item['source_only_dependency'] is False,name
    assert coverage['root_methods_source_owned']==root_source_owned
    assert coverage['root_methods_total']==len(roots)
    source_root_indices=[i for i,name in enumerate(roots) if f'0.{i}' in groups['source_owned']]
    assert source_root_indices==list(range(root_source_owned))
    assert all(roots[name]['source_only_dependency'] for name in list(roots)[:root_source_owned])
    assert all(not roots[name]['source_only_dependency'] for name in list(roots)[root_source_owned:])
    assert root_source_owned==29
    assert {'0.12','0.12.0','0.13','0.13.0'} <= set(groups['source_owned'])
    for source_file in ('product_context.lua','product_constructor.lua','product_module_bridge.lua'):
        text=(ROOT/'src/spectra'/source_file).read_text()
        assert 'debug.getupvalue' not in text,source_file
    assert {'0.3','0.7','0.7.0','0.8','0.8.0','0.10'} <= set(groups['source_owned'])
    assert (ROOT/inv['_meta']['legacy_detailed_index']).exists()

    cap=json.loads((ROOT/'ROOT_CAPTURE_MAP.json').read_text()); r=cap['root_registers']
    assert cap['_meta']['payload_sha256']==PAY and cap['_meta']['root_instruction_count']==127
    assert [r[f'R{i}']['semantic_role'] for i in range(3)]==['debug_logger','info_logger','error_logger']
    def captured(reg,p,u): return {'prototype':p,'upvalue':u} in r[reg]['direct_child_upvalue_captures']
    assert captured('R1','P0.3','U0') and captured('R2','P0.3','U2')
    assert captured('R4','P0.7','U1') and captured('R0','P0.7','U2') and captured('R3','P0.7','U3') and captured('R2','P0.7','U4')
    assert captured('R2','P0.8','U1') and captured('R1','P0.10','U1')
    assert captured('R3','P0.11','U1')
    assert captured('R2','P0.12','U0') and captured('R3','P0.12','U2') and captured('R1','P0.12','U3')
    prototypes={p['path']:p for p in meta}
    assert prototypes['0.12']['numparams']==1 and len(prototypes['0.12']['upvalues'])==4
    assert prototypes['0.12.0']['numparams']==1 and len(prototypes['0.12.0']['upvalues'])==8
    assert prototypes['0.12']['upvalues'][0]=={'instack':1,'idx':2}
    assert prototypes['0.12']['upvalues'][2]=={'instack':1,'idx':3}
    assert prototypes['0.12']['upvalues'][1]=={'instack':0,'idx':0}
    assert prototypes['0.12']['upvalues'][3]=={'instack':1,'idx':1}
    assert prototypes['0.12.0']['upvalues'][0]=={'instack':0,'idx':1}
    assert prototypes['0.12.0']['upvalues'][1]=={'instack':1,'idx':4}
    assert prototypes['0.12.0']['upvalues'][2]=={'instack':1,'idx':0}
    assert prototypes['0.12.0']['upvalues'][3]=={'instack':0,'idx':2}
    assert prototypes['0.12.0']['upvalues'][4]=={'instack':1,'idx':2}
    assert prototypes['0.12.0']['upvalues'][5]=={'instack':0,'idx':3}
    assert prototypes['0.12.0']['upvalues'][6]=={'instack':1,'idx':3}
    assert prototypes['0.12.0']['upvalues'][7]=={'instack':0,'idx':0}
    assert prototypes['0.12.0']['upvalues'][3]=={'instack':0,'idx':2}
    assert captured('R2','P0.12','U0') and captured('R3','P0.12','U2') and captured('R1','P0.12','U3')
    assert captured('R11','P0.13','U1') and captured('R6','P0.13','U2')
    assert prototypes['0.13']['numparams']==2 and len(prototypes['0.13']['upvalues'])==3
    assert prototypes['0.13.0']['numparams']==2 and len(prototypes['0.13.0']['upvalues'])==4
    assert prototypes['0.13']['upvalues'][1]=={'instack':1,'idx':11}
    assert prototypes['0.13']['upvalues'][2]=={'instack':1,'idx':6}
    assert prototypes['0.13.0']['upvalues'][1]=={'instack':1,'idx':1}
    assert prototypes['0.13.0']['upvalues'][2]=={'instack':0,'idx':1}
    assert prototypes['0.13.0']['upvalues'][3]=={'instack':1,'idx':2}
    assert {'0.13','0.13.0'} <= set(groups['source_owned'])
    assert inv['source_files']['0.13']==inv['source_files']['0.13.0']=='src/spectra/product_module.lua'
    assert captured('R8','P0.14','U1') and captured('R3','P0.14','U2')
    assert captured('R3','P0.15','U1') and captured('R8','P0.15','U2')
    assert prototypes['0.14']['numparams']==0 and prototypes['0.14']['instruction_count']==72 and len(prototypes['0.14']['upvalues'])==3
    assert prototypes['0.14']['upvalues'][1]=={'instack':1,'idx':8} and prototypes['0.14']['upvalues'][2]=={'instack':1,'idx':3}
    assert prototypes['0.15']['numparams']==1 and prototypes['0.15']['instruction_count']==76 and len(prototypes['0.15']['upvalues'])==3
    assert prototypes['0.15']['upvalues'][1]=={'instack':1,'idx':3} and prototypes['0.15']['upvalues'][2]=={'instack':1,'idx':8}
    assert {'0.14','0.15'} <= set(groups['source_owned'])
    assert inv['source_files']['0.14']==inv['source_files']['0.15']=='src/spectra/product_module.lua'
    assert captured('R3','P0.18','U1') and captured('R9','P0.18','U2')
    assert prototypes['0.16']['numparams']==0 and prototypes['0.16']['instruction_count']==48 and len(prototypes['0.16']['upvalues'])==1
    assert prototypes['0.17']['numparams']==0 and prototypes['0.17']['instruction_count']==48 and len(prototypes['0.17']['upvalues'])==1
    assert prototypes['0.18']['numparams']==0 and prototypes['0.18']['instruction_count']==106 and len(prototypes['0.18']['upvalues'])==3
    assert prototypes['0.18']['upvalues'][0]=={'instack':0,'idx':0}
    assert prototypes['0.18']['upvalues'][1]=={'instack':1,'idx':3}
    assert prototypes['0.18']['upvalues'][2]=={'instack':1,'idx':9}
    assert {'0.16','0.17','0.18'} <= set(groups['source_owned'])
    assert all(inv['source_files'][p]=='src/spectra/product_module.lua' for p in ('0.16','0.17','0.18'))
    assert roots['_CheckSafeBoxExpiredStatus']['source_only_dependency'] is True
    assert roots['_CheckKeyChainExpiredStatus']['source_only_dependency'] is True
    assert roots['_CheckPropExpiredStatus']['source_only_dependency'] is True
    assert captured('R2','P0.19','U0') and captured('R4','P0.19','U2') and captured('R6','P0.19','U3') and captured('R3','P0.19','U4')
    assert captured('R3','P0.20','U0') and captured('R3','P0.21','U0')
    assert captured('R4','P0.22','U1') and captured('R5','P0.22','U2') and captured('R6','P0.22','U3') and captured('R3','P0.22','U4') and captured('R2','P0.22','U5')
    assert prototypes['0.19']['numparams']==1 and prototypes['0.19']['instruction_count']==87 and len(prototypes['0.19']['upvalues'])==5
    assert prototypes['0.19.0']['numparams']==1 and prototypes['0.19.0']['instruction_count']==57 and len(prototypes['0.19.0']['upvalues'])==5
    assert prototypes['0.20']['numparams']==1 and prototypes['0.20']['instruction_count']==8 and len(prototypes['0.20']['upvalues'])==1
    assert prototypes['0.21']['numparams']==1 and prototypes['0.21']['instruction_count']==8 and len(prototypes['0.21']['upvalues'])==1
    assert prototypes['0.22']['numparams']==1 and prototypes['0.22']['instruction_count']==103 and len(prototypes['0.22']['upvalues'])==6
    assert prototypes['0.22.0']['numparams']==2 and prototypes['0.22.0']['instruction_count']==9 and len(prototypes['0.22.0']['upvalues'])==0
    assert prototypes['0.22.1']['numparams']==2 and prototypes['0.22.1']['instruction_count']==9 and len(prototypes['0.22.1']['upvalues'])==0
    assert prototypes['0.22.2']['numparams']==1 and prototypes['0.22.2']['instruction_count']==131 and len(prototypes['0.22.2']['upvalues'])==6
    assert prototypes['0.23']['numparams']==0 and prototypes['0.23']['instruction_count']==51 and len(prototypes['0.23']['upvalues'])==1
    migrated={'0.19','0.19.0','0.20','0.21','0.22','0.22.0','0.22.1','0.22.2','0.23'}
    assert migrated <= set(groups['source_owned'])
    assert all(inv['source_files'][p]=='src/spectra/product_module.lua' for p in migrated)
    for name in ('CheckPlayerBodyItemsByList','CheckNightVisionLimitByList','CheckThermalImagingLimitByList','CheckPlayerBodyItemsEntryQuality','CheckRentalConsumableID'):
        assert roots[name]['source_only_dependency'] is True
    # Final root download group: pin stripped bytecode shape and capture
    # descriptors, including parent-local captures of both recursive walkers.
    download_shape={
        '0.24':(3,25,3,0), '0.25':(1,31,2,1), '0.25.0':(1,91,4,0),
        '0.26':(1,27,3,0), '0.27':(0,15,2,0),
        '0.28':(1,59,3,1), '0.28.0':(1,48,2,0),
    }
    for path,(params,instructions,upvalues,children) in download_shape.items():
        item=prototypes[path]
        assert (item['numparams'],item['instruction_count'],len(item['upvalues']),
                item['child_count'])==(params,instructions,upvalues,children),path
    capture_expectations={
        '0.24':[(0,0),(1,12),(1,1)],
        '0.25':[(0,0),(1,3)],
        '0.25.0':[(0,0),(0,1),(1,1),(1,2)],
        '0.26':[(0,0),(1,13),(1,1)],
        '0.27':[(0,0),(1,1)],
        '0.28':[(1,4),(0,0),(1,1)],
        '0.28.0':[(0,1),(1,5)],
    }
    for path,expected in capture_expectations.items():
        assert prototypes[path]['upvalues']==[
            {'instack':instack,'idx':index} for instack,index in expected],path
        assert path in groups['source_owned']
        assert source_files[path]=='src/spectra/product_module.lua'
    for reg,proto,u in (
        ('R12','P0.24','U1'),('R1','P0.24','U2'),('R3','P0.25','U1'),
        ('R13','P0.26','U1'),('R1','P0.26','U2'),('R1','P0.27','U1'),
        ('R4','P0.28','U0'),('R1','P0.28','U2')):
        assert captured(reg,proto,u),(reg,proto,u)
    disassembly=(ROOT/'payload_disassembly.txt').read_text()
    blocks={}
    for block in re.split(r'^=== PROTO ',disassembly,flags=re.M)[1:]:
        key,_,text=block.partition('\n')
        blocks[key.split(' ',1)[0]]=text
    assert set(blocks)==paths
    def body(path): return blocks[path]
    # Verify the two branch/return details with direct opcode evidence.
    assert re.search(r'^0043 TAILCALL\s+A=9 B=2 C=0$',body('0.28.0'),re.M)
    assert re.search(r'^0044 CALL\s+A=6 B=2 C=2$',body('0.28'),re.M)
    assert re.search(r'^0045 RETURN\s+A=6 B=2 C=0$',body('0.28'),re.M)
    assert re.search(r'^0107 NEWTABLE\s+A=12 B=0 C=0$',body('0'),re.M)
    assert re.search(r'^0112 NEWTABLE\s+A=13 B=0 C=0$',body('0'),re.M)

    # P0.29 ABI helper checkpoint. Ownership is source reconstruction for
    # source-owned consumers only; this does not claim captured payload helper
    # closures were rebound for unreconstructed payload callers.
    abi_paths={'0.29.2','0.29.2.0','0.29.3','0.29.4','0.29.12'}
    abi_evidence=json.loads((ROOT/'P029_ABI_HELPER_MAP.json').read_text())
    assert abi_evidence['_meta']['payload_sha256']==PAY
    assert abi_evidence['_meta']['payload_closure_rebinding'] is False
    assert set(abi_evidence['helpers'])==abi_paths
    assert abi_paths <= set(groups['source_owned'])
    assert all(source_files[path]=='src/spectra/aim_abi.lua' for path in abi_paths)
    abi_shape={
        '0.29.2':(2,17,1,1), '0.29.2.0':(0,7,2,0),
        '0.29.3':(2,43,2,0), '0.29.4':(2,43,2,0),
        '0.29.12':(2,31,1,0),
    }
    for path,(params,instructions,upvalues,children) in abi_shape.items():
        item=prototypes[path]
        assert (item['numparams'],item['instruction_count'],len(item['upvalues']),item['child_count']) == \
            (params,instructions,upvalues,children),path
        evidence=abi_evidence['helpers'][path]
        assert evidence['numparams']==params and evidence['instruction_count']==instructions
        assert len(evidence['upvalues'])==upvalues and evidence['children']==children
        assert evidence['source_file']=='src/spectra/aim_abi.lua'
        assert evidence['source_only_dependency'] is True
        assert evidence['known_source_consumers'],path
    assert prototypes['0.29.2']['upvalues']==[{'instack':0,'idx':0}]
    assert prototypes['0.29.2.0']['upvalues']==[{'instack':1,'idx':0},{'instack':1,'idx':1}]
    assert prototypes['0.29.3']['upvalues']==[{'instack':1,'idx':19},{'instack':0,'idx':0}]
    assert prototypes['0.29.4']['upvalues']==[{'instack':1,'idx':19},{'instack':0,'idx':0}]
    assert prototypes['0.29.12']['upvalues']==[{'instack':0,'idx':0}]
    expected_abi_registers={'0.29.2':'R19','0.29.3':'R20','0.29.4':'R21','0.29.12':'R32'}
    for path,register in expected_abi_registers.items():
        assert abi_evidence['helpers'][path]['p029_parent_register']==register
    assert abi_evidence['helpers']['0.29.2.0']['p029_parent_register'] is None
    assert abi_evidence['helpers']['0.29.2.0']['parent_local_capture_registers']==['R0','R1']
    assert re.search(r'^0138 CLOSURE\s+R19, P2$',body('0.29'),re.M)
    assert re.search(r'^0139 CLOSURE\s+R20, P3$',body('0.29'),re.M)
    assert re.search(r'^0140 CLOSURE\s+R21, P4$',body('0.29'),re.M)
    assert re.search(r'^0327 CLOSURE\s+R32, P12$',body('0.29'),re.M)

    p2=body('0.29.2'); p20=body('0.29.2.0')
    assert re.search(r'^0009 CALL\s+A=2 B=2 C=3$',p2,re.M)
    assert re.search(r'^0012 TESTSET\s+R4, R3 C=1$',p2,re.M)
    assert re.search(r'^0015 RETURN\s+A=4 B=2 C=0$',p2,re.M)
    assert re.search(r'^0004 GETTABUP\s+R0, U0, R0$',p20,re.M)
    assert re.search(r'^0005 RETURN\s+A=0 B=2 C=0$',p20,re.M)

    p3=body('0.29.3')
    assert re.search(r'^0019 CALL\s+A=3 B=0 C=4$',p3,re.M)
    assert re.search(r'^0025 RETURN\s+A=6 B=4 C=0$',p3,re.M)
    assert re.search(r'^0029 CALL\s+A=6 B=0 C=4$',p3,re.M)
    assert re.search(r'^0038 RETURN\s+A=6 B=4 C=0$',p3,re.M)
    assert re.search(r'^0014 RETURN\s+A=3 B=3 C=0$',p3,re.M)
    assert re.search(r'^0041 RETURN\s+A=6 B=3 C=0$',p3,re.M)

    p4=body('0.29.4')
    assert re.search(r'^0018 CALL\s+A=3 B=0 C=4$',p4,re.M)
    assert re.search(r'^0024 RETURN\s+A=6 B=4 C=0$',p4,re.M)
    assert re.search(r'^0029 CALL\s+A=6 B=0 C=4$',p4,re.M)
    assert re.search(r'^0038 RETURN\s+A=6 B=4 C=0$',p4,re.M)
    assert re.search(r'^0014 RETURN\s+A=3 B=3 C=0$',p4,re.M)
    assert re.search(r'^0041 RETURN\s+A=6 B=3 C=0$',p4,re.M)

    p12=body('0.29.12')
    assert re.search(r'^0010 RETURN\s+A=2 B=3 C=0$',p12,re.M)
    assert re.search(r'^0015 CALL\s+A=2 B=0 C=3$',p12,re.M)
    assert re.search(r'^0020 RETURN\s+A=4 B=3 C=0$',p12,re.M)
    assert re.search(r'^0024 CALL\s+A=4 B=0 C=3$',p12,re.M)
    assert re.search(r'^0029 RETURN\s+A=4 B=3 C=0$',p12,re.M)
    abi_source=(ROOT/'src/spectra/aim_abi.lua').read_text()
    assert 'debug.getupvalue' not in abi_source
    assert 'return pcall(fn, ...)' not in abi_source
    assert 'local fallback_ok, fallback_value = pcall(fn, ...)' in abi_source
    assert 'return fallback_ok, fallback_value' in abi_source

    # Bounded P0.29.5/.6/.8/.11/.13 runtime-helper checkpoint.
    runtime_paths={'0.29.5','0.29.6','0.29.8','0.29.11','0.29.13'}
    runtime_evidence=json.loads((ROOT/'P029_RUNTIME_HELPER_MAP.json').read_text())
    assert runtime_evidence['_meta']['payload_sha256']==PAY
    assert runtime_evidence['_meta']['payload_closure_rebinding'] is False
    assert set(runtime_evidence['helpers'])==runtime_paths
    assert runtime_paths <= set(groups['source_owned'])
    assert all(source_files[path]=='src/spectra/p029_runtime_helpers.lua' for path in runtime_paths)
    runtime_shape={
        '0.29.5':(2,15,2,0), '0.29.6':(1,33,2,0), '0.29.8':(2,33,2,0),
        '0.29.11':(0,19,2,0), '0.29.13':(1,20,3,0),
    }
    expected_runtime_upvalues={
        '0.29.5':[(0,0),(1,19)], '0.29.6':[(0,0),(1,20)],
        '0.29.8':[(0,0),(1,19)], '0.29.11':[(0,0),(1,19)],
        '0.29.13':[(1,31),(1,19),(1,32)],
    }
    expected_runtime_registers={
        '0.29.5':'R22','0.29.6':'R23','0.29.8':'R25','0.29.11':'R31','0.29.13':'R33'}
    expected_runtime_captures={
        '0.29.5':{('U1','R19','0.29.2')},
        '0.29.6':{('U1','R20','0.29.3')},
        '0.29.8':{('U1','R19','0.29.2')},
        '0.29.11':{('U1','R19','0.29.2')},
        '0.29.13':{('U0','R31','0.29.11'),('U1','R19','0.29.2'),('U2','R32','0.29.12')},
    }
    for path,(params,instructions,upvalues,children) in runtime_shape.items():
        item=prototypes[path]
        assert (item['numparams'],item['instruction_count'],len(item['upvalues']),item['child_count']) == \
            (params,instructions,upvalues,children),path
        assert item['upvalues']==[{'instack':i,'idx':idx} for i,idx in expected_runtime_upvalues[path]],path
        evidence=runtime_evidence['helpers'][path]
        assert evidence['p029_parent_register']==expected_runtime_registers[path]
        assert evidence['source_implementation_exists'] is True
        assert evidence['current_ownership']=='source_owned'
        assert evidence['active_source_consumer'] is True
        assert evidence['payload_closure_rebinding'] is False
        assert evidence['source_only_dependency'] is True
        assert evidence['source_file']=='src/spectra/p029_runtime_helpers.lua'
        assert evidence['source_capture_identity']
        captures={(x['upvalue'],x['register'],x['prototype']) for x in evidence['captured_helper_registers']}
        assert captures==expected_runtime_captures[path],(path,captures)
    for instruction,reg,child in ((141,22,5),(142,23,6),(144,25,8),(326,31,11),(328,33,13)):
        assert re.search(rf'^{instruction:04d} CLOSURE\s+R{reg}, P{child}$',body('0.29'),re.M)

    def payload_consumers(path):
        return {x['prototype'] for x in runtime_evidence['helpers'][path]['known_payload_capture_consumers']}
    assert '0.29.81' in payload_consumers('0.29.5')
    assert '0.29.85' in payload_consumers('0.29.6')
    assert '0.29.77' in payload_consumers('0.29.8')

    p5=body('0.29.5')
    assert re.search(r"^0003 GETTABUP\s+R2, U0, K0='type'$",p5,re.M)
    assert re.search(r'^0004 GETUPVAL\s+R3, U1$',p5,re.M)
    assert re.search(r'^0007 CALL\s+A=3 B=3 C=0$',p5,re.M)
    assert re.search(r'^0008 CALL\s+A=2 B=0 C=2$',p5,re.M)
    assert re.search(r"^0009 EQ\s+A=1 R2, K1='function'$",p5,re.M)
    assert re.search(r'^0013 RETURN\s+A=2 B=2 C=0$',p5,re.M)

    p6=body('0.29.6')
    assert re.search(r'^0006 RETURN\s+A=1 B=2 C=0$',p6,re.M)
    assert re.search(r"^0009 LOADK\s+R3, K3='GetFullName'$",p6,re.M)
    assert re.search(r"^0010 LOADK\s+R4, K4='GetName'$",p6,re.M)
    assert re.search(r'^0017 CALL\s+A=6 B=3 C=3$',p6,re.M)
    assert re.search(r'^0024 TAILCALL\s+A=8 B=2 C=0$',p6,re.M)
    assert re.search(r"^0028 GETTABUP\s+R1, U0, K5='tostring'$",p6,re.M)
    assert re.search(r'^0030 TAILCALL\s+A=1 B=2 C=0$',p6,re.M)

    p8=body('0.29.8')
    assert re.search(r"^0005 LOADK\s+R4, K2='Timer'$",p8,re.M)
    assert re.search(r"^0009 LOADK\s+R5, K3='DelayCall'$",p8,re.M)
    assert re.search(r'^0017 CALL\s+A=4 B=1 C=1$',p8,re.M)
    assert re.search(r'^0018 RETURN\s+A=0 B=1 C=0$',p8,re.M)
    assert re.search(r'^0023 CALL\s+A=4 B=4 C=2$',p8,re.M)
    assert re.search(r'^0031 CALL\s+A=5 B=5 C=1$',p8,re.M)
    assert re.search(r'^0032 RETURN\s+A=0 B=1 C=0$',p8,re.M)

    p11=body('0.29.11')
    assert re.search(r"^0005 LOADK\s+R2, K2='Facade'$",p11,re.M)
    assert re.search(r"^0009 LOADK\s+R3, K3='TableManager'$",p11,re.M)
    assert re.search(r'^0011 TEST\s+R1 C=1$',p11,re.M)
    assert re.search(r"^0015 LOADK\s+R3, K3='TableManager'$",p11,re.M)
    assert re.search(r'^0017 RETURN\s+A=1 B=2 C=0$',p11,re.M)

    p13=body('0.29.13')
    assert re.search(r'^0003 GETUPVAL\s+R1, U0$',p13,re.M)
    assert re.search(r'^0004 CALL\s+A=1 B=1 C=2$',p13,re.M)
    assert re.search(r"^0007 LOADK\s+R4, K0='GetTable'$",p13,re.M)
    assert re.search(r'^0008 CALL\s+A=2 B=3 C=2$',p13,re.M)
    assert re.search(r'^0013 CALL\s+A=3 B=4 C=3$',p13,re.M)
    assert re.search(r'^0014 TEST\s+R3 C=0$',p13,re.M)
    assert re.search(r'^0016 RETURN\s+A=4 B=2 C=0$',p13,re.M)
    assert re.search(r'^0018 RETURN\s+A=5 B=2 C=0$',p13,re.M)

    # P0.29.17.0 is the exact assignment child already executed by source-owned P17.
    p170=prototypes['0.29.17.0']
    assert (p170['numparams'],p170['instruction_count'],len(p170['upvalues']),p170['child_count'])==(0,8,1,0)
    assert p170['upvalues']==[{'instack':1,'idx':8}]
    assert '0.29.17' in groups['source_owned'] and '0.29.17.0' in groups['source_owned']
    assert source_files['0.29.17.0']=='src/spectra/mutation_runtime.lua'
    p17=body('0.29.17'); p170_body=body('0.29.17.0')
    assert re.search(r"^0044 GETTABUP\s+R9, U1, K9='pcall'$",p17,re.M)
    assert re.search(r'^0045 CLOSURE\s+R10, P0$',p17,re.M)
    assert re.search(r'^0046 CALL\s+A=9 B=2 C=2$',p17,re.M)
    assert re.search(r"^0003 GETTABUP\s+R0, U0, K0='object'$",p170_body,re.M)
    assert re.search(r"^0004 GETTABUP\s+R1, U0, K1='key'$",p170_body,re.M)
    assert re.search(r"^0005 GETTABUP\s+R2, U0, K2='value'$",p170_body,re.M)
    assert re.search(r'^0006 SETTABLE\s+R0, R1, R2$',p170_body,re.M)
    assert re.search(r'^0007 RETURN\s+A=0 B=1 C=0$',p170_body,re.M)

    # Exact P0.29.14/.15/.15.0/.16 captured snapshot-helper family.
    snap_paths={'0.29.14','0.29.15','0.29.15.0','0.29.16'}
    assert snap_paths <= set(groups['source_owned'])
    assert all(source_files[path]=='src/spectra/mutation_runtime.lua' for path in snap_paths)
    p14m,p15m,p150m,p16m=(prototypes[x] for x in ('0.29.14','0.29.15','0.29.15.0','0.29.16'))
    assert (p14m['numparams'],p14m['instruction_count'],p14m['upvalues'],p14m['child_count'])==(1,27,[{'instack':1,'idx':0},{'instack':0,'idx':0}],0)
    assert (p15m['numparams'],p15m['instruction_count'],p15m['upvalues'],p15m['child_count'])==(4,48,[{'instack':1,'idx':19},{'instack':1,'idx':34},{'instack':0,'idx':0}],1)
    assert (p150m['numparams'],p150m['instruction_count'],p150m['upvalues'],p150m['child_count'])==(0,7,[{'instack':1,'idx':1},{'instack':1,'idx':2},{'instack':1,'idx':3}],0)
    assert (p16m['numparams'],p16m['instruction_count'],p16m['upvalues'],p16m['child_count'])==(1,11,[{'instack':1,'idx':0},{'instack':0,'idx':0}],0)
    root=body('0.29')
    assert re.search(r'^0329 CLOSURE\s+R34, P14$',root,re.M)
    assert re.search(r'^0330 CLOSURE\s+R35, P15$',root,re.M)
    assert re.search(r'^0331 CLOSURE\s+R36, P16$',root,re.M)
    p14,p15,p150,p16=(body(x) for x in ('0.29.14','0.29.15','0.29.15.0','0.29.16'))
    assert re.search(r"^0003 GETTABUP\s+R1, U0, K0='custom_dongdong_feature_snapshots'$",p14,re.M)
    assert re.search(r'^0025 RETURN\s+A=2 B=2 C=0$',p14,re.M)
    assert re.search(r'^0009 GETUPVAL\s+R4, U0$',p15,re.M) and re.search(r'^0012 CALL\s+A=4 B=3 C=2$',p15,re.M)
    assert re.search(r'^0017 GETUPVAL\s+R5, U1$',p15,re.M) and re.search(r'^0019 CALL\s+A=5 B=2 C=2$',p15,re.M)
    assert re.search(r'^0044 CLOSURE\s+R8, P0$',p15,re.M) and re.search(r'^0045 TAILCALL\s+A=7 B=2 C=0$',p15,re.M) and re.search(r'^0046 RETURN\s+A=7 B=0 C=0$',p15,re.M)
    assert re.search(r'^0003 GETUPVAL\s+R0, U1$',p150,re.M) and re.search(r'^0005 SETTABUP\s+U0, R0, R1$',p150,re.M) and re.search(r'^0006 RETURN\s+A=0 B=1 C=0$',p150,re.M)
    assert re.search(r"^0003 GETTABUP\s+R1, U0, K0='custom_dongdong_feature_snapshots'$",p16,re.M) and re.search(r'^0010 RETURN\s+A=0 B=1 C=0$',p16,re.M)

    runtime_source=(ROOT/'src/spectra/p029_runtime_helpers.lua').read_text()
    mutation_source=(ROOT/'src/spectra/mutation_runtime.lua').read_text()
    visual_source=(ROOT/'src/spectra/visual_scan.lua').read_text()
    bridge_source=(ROOT/'src/spectra/payload_feature_bridge.lua').read_text()
    assert 'local ABI = assert(S.AimABI, "AimABI required")' in runtime_source
    assert 'local safe_get = assert(ABI.get, "P0.29.2 required")' in runtime_source
    assert 'local self_first = assert(ABI.self_first, "P0.29.3 required")' in runtime_source
    assert 'local call_optional_self = assert(ABI.call_optional_self, "P0.29.12 required")' in runtime_source
    assert 'local manager = get_table_manager_impl()' in runtime_source
    assert 'M.get_table_manager = get_table_manager_impl' in runtime_source
    assert 'M.get_data_table = get_data_table_impl' in runtime_source
    assert 'ABI.self_first(' not in runtime_source
    assert 'M.get_table_manager(' not in runtime_source
    assert 'ABI.call_optional_self(' not in runtime_source
    assert 'local function safe_get' not in mutation_source
    assert 'local function call_optional_self' not in mutation_source
    assert 'local safe_get = ABI.get' in mutation_source
    assert 'local call_optional_self = ABI.call_optional_self' in mutation_source
    assert 'M.get_table_manager = RuntimeHelpers.get_table_manager' in mutation_source
    assert 'M.get_data_table = RuntimeHelpers.get_data_table' in mutation_source
    assert 'local snapshot_state_029 = _G' in mutation_source
    assert 'local snapshot_safe_get_029_2 = safe_get' in mutation_source
    assert 'local ensure_feature_snapshot_capture_029_14 = ensure_feature_snapshot_029_14' in mutation_source
    assert 'M.p029_ensure_feature_snapshot = ensure_feature_snapshot_029_14' in mutation_source
    assert 'M.p029_snapshot_set = snapshot_set_029_15' in mutation_source
    assert 'M.p029_clear_feature_snapshot = clear_feature_snapshot_029_16' in mutation_source
    assert 'local object_name = RuntimeHelpers.object_name' in visual_source
    assert 'RuntimeHelpers.is_function_field' in visual_source
    assert 'choose("delay", RuntimeHelpers.delay)' in bridge_source

    # Exact P0.29.71/.71.0 and P0.29.72/.72.0 aim-runtime source ownership checkpoint.
    aim_runtime_paths={'0.29.71','0.29.71.0','0.29.72','0.29.72.0'}
    aim_runtime_evidence=json.loads((ROOT/'P029_AIM_RUNTIME_MAP.json').read_text())
    assert aim_runtime_evidence['_meta']['payload_sha256']==PAY
    assert aim_runtime_evidence['_meta']['payload_closure_rebinding'] is False
    assert set(aim_runtime_evidence['_meta']['ownership_boundary'])==aim_runtime_paths
    assert set(aim_runtime_evidence['prototypes'])==aim_runtime_paths
    assert aim_runtime_paths <= set(groups['source_owned'])
    assert all(source_files[path]=='src/spectra/aim_runtime.lua' for path in aim_runtime_paths)
    assert {'0.29.69','0.29.70','0.29.73'} <= set(groups['payload_owned'])

    p71_meta=prototypes['0.29.71']; p710_meta=prototypes['0.29.71.0']; p72_meta=prototypes['0.29.72']; p720_meta=prototypes['0.29.72.0']
    assert (p71_meta['numparams'],p71_meta['instruction_count'],len(p71_meta['upvalues']),p71_meta['child_count'])==(1,108,4,1)
    assert p71_meta['upvalues']==[{'instack':1,'idx':0},{'instack':0,'idx':0},{'instack':1,'idx':19},{'instack':1,'idx':32}]
    assert (p710_meta['numparams'],p710_meta['instruction_count'],len(p710_meta['upvalues']),p710_meta['child_count'])==(0,6,2,0)
    assert p710_meta['upvalues']==[{'instack':1,'idx':10},{'instack':1,'idx':11}]
    assert (p72_meta['numparams'],p72_meta['instruction_count'],len(p72_meta['upvalues']),p72_meta['child_count'])==(1,22,3,1)
    assert p72_meta['upvalues']==[{'instack':0,'idx':0},{'instack':1,'idx':19},{'instack':1,'idx':25}]
    assert (p720_meta['numparams'],p720_meta['instruction_count'],len(p720_meta['upvalues']),p720_meta['child_count'])==(0,76,3,0)
    assert p720_meta['upvalues']==[{'instack':0,'idx':0},{'instack':0,'idx':1},{'instack':1,'idx':1}]

    p71e=aim_runtime_evidence['prototypes']['0.29.71']; p710e=aim_runtime_evidence['prototypes']['0.29.71.0']
    assert p71e['p029_parent_register']=='R96' and p71e['p029_closure_instruction']==1056
    assert p71e['captured_state']=={'upvalue':'U0','register':'R0','semantic':'P0.29 invocation state table'}
    assert p71e['child_prototype']=='0.29.71.0' and p71e['child_closure_register']=='R13' and p71e['child_closure_instruction']==88
    assert {(x['upvalue'],x['register'],x['prototype']) for x in p71e['captured_helper_registers']}=={('U2','R19','0.29.2'),('U3','R32','0.29.12')}
    assert p71e['source_only_dependency'] is True and p71e['current_ownership']=='source_owned'
    assert p710e['source_only_dependency'] is True and p710e['current_ownership']=='source_owned'
    assert [x['upvalue'] for x in p710e['parent_capture_mapping']]==['U0','U1']

    p71=body('0.29.71')
    assert re.search(r"^0003 GETTABUP\s+R1, U0, K0='custom_dongdong_native_aim_state'$",p71,re.M)
    assert re.search(r'^0035 CALL\s+A=4 B=3 C=3$',p71,re.M) and re.search(r'^0038 CALL\s+A=6 B=2 C=3$',p71,re.M)
    assert re.search(r'^0049 GETUPVAL\s+R8, U2$',p71,re.M) and re.search(r'^0052 CALL\s+A=8 B=3 C=2$',p71,re.M)
    assert re.search(r'^0053 GETUPVAL\s+R9, U3$',p71,re.M) and re.search(r'^0057 CALL\s+A=9 B=4 C=3$',p71,re.M)
    assert re.search(r'^0068 GETUPVAL\s+R11, U2$',p71,re.M)
    assert re.search(r'^0088 CLOSURE\s+R13, P0$',p71,re.M) and re.search(r'^0089 CALL\s+A=12 B=2 C=2$',p71,re.M)
    assert re.search(r'^0090 GETUPVAL\s+R13, U2$',p71,re.M) and re.search(r'^0093 CALL\s+A=13 B=3 C=2$',p71,re.M)
    assert re.search(r'^0102 CALL\s+A=14 B=3 C=1$',p71,re.M)
    assert re.search(r'^0105 SETTABLE\s+R1, K12=\'saved\', K17=False$',p71,re.M)
    assert re.search(r'^0106 RETURN\s+A=12 B=2 C=0$',p71,re.M)
    assert re.search(r'^1056 CLOSURE\s+R96, P71$',body('0.29'),re.M)
    p710=body('0.29.71.0')
    assert re.search(r'^0003 GETUPVAL\s+R0, U1$',p710,re.M)
    assert re.search(r"^0004 SETTABUP\s+U0, K0='bIsAimAssistOpen', R0$",p710,re.M)
    assert re.search(r'^0005 RETURN\s+A=0 B=1 C=0$',p710,re.M)

    p72e=aim_runtime_evidence['prototypes']['0.29.72']; p720e=aim_runtime_evidence['prototypes']['0.29.72.0']
    assert p72e['p029_parent_register']=='R97' and p72e['p029_closure_instruction']==1057
    assert p72e['child_prototype']=='0.29.72.0' and p72e['child_closure_register']=='R2' and p72e['child_closure_instruction']==9
    assert {(x['upvalue'],x['register'],x['prototype']) for x in p72e['captured_helper_registers']}=={('U1','R19','0.29.2'),('U2','R25','0.29.8')}
    assert [x['upvalue'] for x in p720e['parent_capture_mapping']]==['U0','U1','U2']
    p72=body('0.29.72')
    assert re.search(r'^0003 EQ\s+A=0 R0, K0=True$',p72,re.M)
    assert re.search(r'^0009 CLOSURE\s+R2, P0$',p72,re.M) and re.search(r'^0011 CALL\s+A=3 B=1 C=2$',p72,re.M)
    assert re.search(r'^0013 LOADK\s+R5, K3=0\.35$',p72,re.M) and re.search(r'^0017 LOADK\s+R5, K4=1\.2$',p72,re.M)
    assert re.search(r'^0020 RETURN\s+A=3 B=2 C=0$',p72,re.M)
    assert re.search(r'^1057 CLOSURE\s+R97, P72$',body('0.29'),re.M)
    p720=body('0.29.72.0')
    assert re.search(r'^0063 CALL\s+A=5 B=5 C=2$',p720,re.M) and re.search(r'^0072 CALL\s+A=6 B=6 C=2$',p720,re.M)
    assert re.search(r'^0074 RETURN\s+A=5 B=2 C=0$',p720,re.M)

    aim_runtime_source=(ROOT/'src/spectra/aim_runtime.lua').read_text()
    assert 'local native_aim_state_029_71 = _G' in aim_runtime_source
    assert 'local safe_get_029_2 = assert(ABI.get, "P0.29.2 required")' in aim_runtime_source
    assert 'local call_optional_self_029_12 = assert(ABI.call_optional_self, "P0.29.12 required")' in aim_runtime_source
    assert 'function M.set_native_aim_assist(enabled)' in aim_runtime_source
    assert 'function M.set_native_aim_assist(state, enabled)' not in aim_runtime_source
    assert 'p71_safe_get' not in aim_runtime_source and 'p71_invoke' not in aim_runtime_source
    assert 'local delay_029_8 = assert(RuntimeHelpers.delay, "P0.29.8 required")' in aim_runtime_source
    assert 'function M.set_fire_assisted_aim_debug(enabled)' in aim_runtime_source
    assert 'delay_029_8(0.35, apply)' in aim_runtime_source and 'delay_029_8(1.2, apply)' in aim_runtime_source
    assert 'AimRuntime.set_native_aim_assist(_G, enabled)' not in bridge_source
    assert 'AimRuntime.set_native_aim_assist(enabled)' in bridge_source
    assert 'AimRuntime.set_fire_assisted_aim_debug(enabled)' in bridge_source

    # Mutation primitive source-ownership checkpoint: exact ABI and fixed captures.
    mutation_paths={'0.29.10','0.29.14','0.29.15','0.29.16','0.29.18','0.29.49','0.29.57','0.29.58'}
    mutation_evidence=json.loads((ROOT/'P029_MUTATION_HELPER_MAP.json').read_text())
    assert mutation_evidence['_meta']['payload_sha256']==PAY
    assert mutation_evidence['_meta']['payload_closure_rebinding'] is False
    assert set(mutation_evidence['_meta']['ownership_boundary'])==mutation_paths
    assert set(mutation_evidence['helpers'])==mutation_paths
    assert mutation_paths <= set(groups['source_owned'])
    assert all(source_files[path]=='src/spectra/mutation_runtime.lua' for path in mutation_paths)
    mutation_shape={'0.29.10':(1,17,1,0),'0.29.18':(1,40,2,0),'0.29.49':(2,71,3,0),'0.29.57':(3,80,3,2),'0.29.58':(2,50,2,2)}
    mutation_upvalues={'0.29.10':[(0,0)],'0.29.18':[(0,0),(1,19)],'0.29.49':[(0,0),(1,19),(1,32)],'0.29.57':[(0,0),(1,19),(1,32)],'0.29.58':[(0,0),(1,82)]}
    mutation_registers={'0.29.10':('R30',325),'0.29.18':('R38',333),'0.29.49':('R74',1034),'0.29.57':('R82',1042),'0.29.58':('R83',1043)}
    mutation_captures={'0.29.10':set(),'0.29.18':{('U1','R19','0.29.2')},'0.29.49':{('U1','R19','0.29.2'),('U2','R32','0.29.12')},'0.29.57':{('U1','R19','0.29.2'),('U2','R32','0.29.12')},'0.29.58':{('U1','R82','0.29.57')}}
    for path,(params,instructions,upvalues,children) in mutation_shape.items():
        item=prototypes[path]
        assert (item['numparams'],item['instruction_count'],len(item['upvalues']),item['child_count'])==(params,instructions,upvalues,children),path
        assert item['upvalues']==[{'instack':a,'idx':b} for a,b in mutation_upvalues[path]],path
        evidence=mutation_evidence['helpers'][path]
        assert (evidence['p029_parent_register'],evidence['p029_closure_instruction'])==mutation_registers[path]
        assert evidence['current_ownership']=='source_owned' and evidence['source_only_dependency'] is True
        assert evidence['source_file']=='src/spectra/mutation_runtime.lua' and evidence['payload_closure_rebinding'] is False
        captures={(x['upvalue'],x['register'],x['prototype']) for x in evidence['captured_helper_registers']}
        assert captures==mutation_captures[path],(path,captures)
    root29=body('0.29')
    for path,(reg,pc) in mutation_registers.items():
        child=int(path.rsplit('.',1)[1]); assert re.search(rf'^{pc:04d} CLOSURE\s+{reg}, P{child}$',root29,re.M)
    p10=body('0.29.10')
    assert re.search(r"^0003 GETTABUP\s+R1, U0, K0='string'$",p10,re.M)
    assert re.search(r"^0011 SELF\s+R1, R1, K4='gsub'$",p10,re.M)
    assert re.search(r'^0014 TAILCALL\s+A=1 B=4 C=0$',p10,re.M)
    p18=body('0.29.18')
    assert re.search(r"^0011 LOADK\s+R3, K2='TableExtend'$",p18,re.M)
    assert re.search(r'^0022 CALL\s+A=2 B=3 C=3$',p18,re.M)
    assert re.search(r'^0027 CALL\s+A=4 B=2 C=3$',p18,re.M)
    assert re.search(r'^0037 RETURN\s+A=3 B=2 C=0$',p18,re.M) and re.search(r'^0038 RETURN\s+A=0 B=2 C=0$',p18,re.M)
    p49=body('0.29.49')
    assert "'ULuaArrayHelper'" in p49 and "'Get'" in p49
    assert re.search(r'^0009 GETTABLE\s+R2, R0, R2$',p49,re.M) and re.search(r'^0010 RETURN\s+A=2 B=2 C=0$',p49,re.M)
    p57=body('0.29.57')
    assert re.search(r'^0010 CLOSURE\s+R5, P0$',p57,re.M) and re.search(r'^0011 TAILCALL\s+A=4 B=2 C=0$',p57,re.M)
    assert re.search(r'^0020 GETUPVAL\s+R4, U1$',p57,re.M) and re.search(r'^0031 GETUPVAL\s+R7, U2$',p57,re.M)
    assert re.search(r'^0036 CALL\s+A=7 B=5 C=0$',p57,re.M) and re.search(r'^0037 CALL\s+A=5 B=0 C=2$',p57,re.M)
    assert re.search(r'^0055 GETTABUP\s+R7, U0, K3=\'pcall\'$',p57,re.M) and re.search(r'^0060 CALL\s+A=7 B=5 C=2$',p57,re.M)
    assert re.search(r'^0063 GETTABUP\s+R8, U0, K3=\'pcall\'$',p57,re.M) and re.search(r'^0069 CALL\s+A=8 B=6 C=2$',p57,re.M)
    assert re.search(r'^0076 CLOSURE\s+R8, P1$',p57,re.M) and re.search(r'^0077 TAILCALL\s+A=7 B=2 C=0$',p57,re.M)
    for child in ('0.29.57.0','0.29.57.1'):
        item=prototypes[child]
        assert (item['numparams'],item['instruction_count'],item['upvalues'],item['child_count'])==(0,7,[{'instack':1,'idx':0},{'instack':1,'idx':3},{'instack':1,'idx':2}],0),child
        text=body(child); assert re.search(r'^0005 SETTABUP\s+U0, R0, R1$',text,re.M) and re.search(r'^0006 RETURN\s+A=0 B=1 C=0$',text,re.M)
        assert child in groups['source_owned'] and source_files[child]=='src/spectra/mutation_runtime.lua'
    p58=body('0.29.58')
    assert re.search(r'^0017 CLOSURE\s+R3, P0$',p58,re.M) and re.search(r'^0018 CALL\s+A=2 B=2 C=2$',p58,re.M)
    assert re.search(r'^0028 GETUPVAL\s+R3, U1$',p58,re.M) and re.search(r'^0032 CALL\s+A=3 B=4 C=2$',p58,re.M)
    assert re.search(r'^0043 CLOSURE\s+R4, P1$',p58,re.M) and re.search(r'^0044 CALL\s+A=3 B=2 C=2$',p58,re.M)
    assert re.search(r'^0048 RETURN\s+A=2 B=2 C=0$',p58,re.M)
    c580=prototypes['0.29.58.0']; assert (c580['numparams'],c580['instruction_count'],c580['upvalues'],c580['child_count'])==(0,8,[{'instack':1,'idx':0},{'instack':1,'idx':1}],0)
    c581=prototypes['0.29.58.1']; assert (c581['numparams'],c581['instruction_count'],c581['upvalues'],c581['child_count'])==(0,8,[{'instack':1,'idx':0}],0)
    for child in ('0.29.58.0','0.29.58.1'):
        assert child in groups['source_owned'] and source_files[child]=='src/spectra/mutation_runtime.lua'
        assert re.search(r'^0007 RETURN\s+A=0 B=1 C=0$',body(child),re.M)
    mutation_source=(ROOT/'src/spectra/mutation_runtime.lua').read_text()
    assert 'return string.lower(tostring(value or "")):gsub("[^%w]", "")' in mutation_source
    assert 'local safe_get = ABI.get' in mutation_source and 'local call_optional_self = ABI.call_optional_self' in mutation_source
    assert 'local ok, extended = pcall(fn, value)' in mutation_source and 'if not ok then ok, extended = pcall(fn) end' in mutation_source
    assert 'function M.array_get(array, index0)' in mutation_source
    assert 'function M.array_set_raw(array, index0, value)' in mutation_source
    assert 'ok = pcall(fn, array, index1, value)' in mutation_source
    assert 'if not ok then ok = pcall(fn, helper, array, index1, value) end' in mutation_source
    assert 'local array_set_raw_029_57 = M.array_set_raw' in mutation_source
    assert 'if array_set_raw_029_57(binding.parent_array, binding.parent_index, binding.parent_value) then ok = true end' in mutation_source

    coverage_text=(ROOT/'RECONSTRUCTION_COVERAGE.md').read_text()
    for line in (
        f"- Total prototypes: **{len(paths)}**",
        f"- Classified: **{coverage['classified']}**",
        f"- Source-owned: **{coverage['source_owned']}**",
        f"- Payload-owned: **{coverage['payload_owned']}**",
        f"- Partially reconstructed: **{coverage['partially_reconstructed']}**",
        f"- Unknown: **{coverage['unknown']}**",
        f"- Root methods source-owned: **{root_source_owned} / {len(roots)}**",
    ): assert line in coverage_text
    bridge=(ROOT/'src/spectra/product_module_bridge.lua').read_text(); assert 'debug.getupvalue' not in bridge and 'payload_upvalue_introspection = false' in bridge
    constructor=(ROOT/'src/spectra/product_constructor.lua').read_text(); assert 'Product.create = M.create' in constructor

    b64=(ROOT/'embedded_payload.b64').read_text().strip(); assert base64.b64decode(b64)==payload.read_bytes()
    chunks=re.findall(r'^\s*"([A-Za-z0-9+/=]+)",\s*$',(ROOT/'src/spectra/payload_embed.lua').read_text(),re.M)
    assert len(chunks)==801 and ''.join(chunks)==b64
    std=standard.read_bytes(); cus=custom.read_bytes()
    assert transform(cus,'to-standard',8)==std and transform(std,'to-custom',4)==cus
    scan=Scanner(cus).scan(); assert scan['version']==0x53 and scan['sizet_size']==4
    assert 'M.AIM_TAKEOVER_ENABLED = true' in (ROOT/'src/spectra/payload_feature_bridge.lua').read_text()
    ui=(ROOT/'src/spectra/native_settings_ui.lua').read_text(); assert 'M.PAGE_TITLE = "@DrkZeref"' in ui and '@starrmods' not in ui

    lua=lua_runner()
    tests={
      'native_settings_ui.lua':'native-settings-ui: ok','feature_control.lua':'feature-control: ok','character_visuals.lua':'character-visuals: ok',
      'aim_runtime.lua':'aim-runtime: ok','aim_mutation.lua':'aim-mutation: ok','aim_differential.lua':'aim-differential: ok','aim_bones.lua':'aim-bones: ok',
      'aim_refresh.lua':'aim-refresh: ok','aim_abi.lua':'aim-abi: ok','aim_dispatch.lua':'aim-dispatch: ok','aim_chain.lua':'aim-chain: ok',
      'aim_chain_fidelity.lua':'aim-chain-fidelity: ok','aim_transaction.lua':'aim-transaction: ok','product_context.lua':'product-context: ok',
      'product_module.lua':'product-module: ok','product_night.lua':'product-night: ok','product_expiration.lua':'product-expiration: ok','product_body_limits.lua':'product-body-limits: ok','product_downloads.lua':'product-downloads: ok','product_source_only.lua':'product-source-only: ok','product_module_bridge.lua':'product-module-bridge: ok',
      'visual_runtime.lua':'visual-runtime: ok','mutation_runtime.lua':'mutation-runtime: ok','p029_runtime_helpers.lua':'p029-runtime-helpers: ok','p029_mutation_primitives.lua':'p029-mutation-primitives: ok','p029_array_set_raw.lua':'p029-array-set-raw: ok','p029_restore_binding.lua':'p029-restore-binding: ok','payload_feature_bridge.lua':'payload-feature-bridge: ok',
      'visual_scan.lua':'visual-scan: ok','payload_visual_bridge.lua':'payload-visual-bridge: ok','smoke.lua':'smoke: ok','protocol_fixture.lua':'protocol-fixture: ok'}
    passed={}
    for file,marker in tests.items():
        out=run([lua,str(ROOT/'tests'/file),str(ROOT)]); assert marker in out; passed[file]='passed'

    report={
      'phase':'E5.15-p029-58-restore-binding-source-only',
      'baseline':rec(baseline),'embedded_payload':rec(payload),'phase_d_source':rec(source),'phase_d_standard':rec(standard),'phase_d_custom':rec(custom),
      'inventory':{'total':len(paths),'classified':coverage['classified'],'source_owned':coverage['source_owned'],'payload_owned':coverage['payload_owned'],'partially_reconstructed':coverage['partially_reconstructed'],'unknown':coverage['unknown'],'root_methods_source_owned':root_source_owned,'root_methods_total':len(roots)},
      'source_only':{'root_capture_map_complete':True,'product_context':True,'product_constructor':True,'p0_0_through_p0_28':True,'p029_abi_helpers':True,'p029_runtime_helpers':True,'p029_mutation_helpers':True,'p029_aim_runtime':True,'payload_upvalue_introspection':False},
      'runtime_ownership':{'no_recoil':True,'converge':True,'aim':True,'anti_shake':True},
      'checks':{'baseline_identity':True,'payload_identity':True,'payload_embed_801_fragments_exact':True,'custom_standard_roundtrip_exact':True,'lua53_chunk_structure':True,'root_capture_map':'passed','root_download_bytecode_captures':'passed','p029_abi_helper_map':'passed','p029_abi_exact_return_shapes':'passed','p029_runtime_helper_map':'passed','mutation_runtime_abi_integration':'passed','p029_capture_identity':'passed','p029_mutation_helper_map':'passed','p029_17_child_exact':'passed','p029_mutation_primitive_exact_abi':'passed','p029_aim_runtime_map':'passed','p029_71_exact_parent_child':'passed','p029_72_exact_parent_child':'passed','source_only_product_constructor':'passed','no_source_owned_root_payload_capture_dependency':'passed',**passed,'game_runtime_test':False}}
    (ROOT/'validation_phase_d.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
    print('phase-d-validation: ok')

if __name__=='__main__': main()

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
    assert root_source_owned>=12
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
    assert captured('R11','P0.13','U1') and captured('R6','P0.13','U2')
    assert captured('R8','P0.14','U1') and captured('R8','P0.15','U2')

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
      'product_module.lua':'product-module: ok','product_source_only.lua':'product-source-only: ok','product_module_bridge.lua':'product-module-bridge: ok',
      'visual_runtime.lua':'visual-runtime: ok','mutation_runtime.lua':'mutation-runtime: ok','payload_feature_bridge.lua':'payload-feature-bridge: ok',
      'visual_scan.lua':'visual-scan: ok','payload_visual_bridge.lua':'payload-visual-bridge: ok','smoke.lua':'smoke: ok','protocol_fixture.lua':'protocol-fixture: ok'}
    passed={}
    for file,marker in tests.items():
        out=run([lua,str(ROOT/'tests'/file),str(ROOT)]); assert marker in out; passed[file]='passed'

    report={
      'phase':'E5.1-root-dynamic-guid-finish-fetch-source-only',
      'baseline':rec(baseline),'embedded_payload':rec(payload),'phase_d_source':rec(source),'phase_d_standard':rec(standard),'phase_d_custom':rec(custom),
      'inventory':{'total':len(paths),'classified':coverage['classified'],'source_owned':coverage['source_owned'],'payload_owned':coverage['payload_owned'],'partially_reconstructed':coverage['partially_reconstructed'],'unknown':coverage['unknown'],'root_methods_source_owned':root_source_owned,'root_methods_total':len(roots)},
      'source_only':{'root_capture_map_complete':True,'product_context':True,'product_constructor':True,'p0_0_through_p0_11':True,'payload_upvalue_introspection':False},
      'runtime_ownership':{'no_recoil':True,'converge':True,'aim':True,'anti_shake':True},
      'checks':{'baseline_identity':True,'payload_identity':True,'payload_embed_801_fragments_exact':True,'custom_standard_roundtrip_exact':True,'lua53_chunk_structure':True,'root_capture_map':'passed','source_only_product_constructor':'passed','no_source_owned_root_payload_capture_dependency':'passed',**passed,'game_runtime_test':False}}
    (ROOT/'validation_phase_d.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
    print('phase-d-validation: ok')

if __name__=='__main__': main()

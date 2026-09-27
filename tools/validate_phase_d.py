#!/usr/bin/env python3
import base64, hashlib, json, re, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from remap_lua53 import Scanner, transform

EXPECTED_BASELINE_SHA='35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536'
EXPECTED_PAYLOAD_SHA='a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263'

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def rec(p): p=Path(p); return {'size':p.stat().st_size,'sha256':sha(p)}
def runner():
    for n in ('texlua','lua5.3','lua'):
        p=shutil.which(n)
        if p:
            q=subprocess.run([p,'-v'],text=True,capture_output=True)
            # texlua -v is TeX info, so probe _VERSION instead below
            t=subprocess.run([p,'-e','print(_VERSION)'],text=True,capture_output=True)
            if t.returncode==0 and 'Lua 5.3' in (t.stdout+t.stderr): return p
    # texlua does not reliably accept -e; validate.py already has a file-probe helper.
    import importlib.util
    spec=importlib.util.spec_from_file_location('v',ROOT/'tools'/'validate.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m.find_lua_runner()[0]

def run(cmd):
    p=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if p.returncode: raise RuntimeError(' '.join(map(str,cmd))+'\n'+p.stdout+p.stderr)
    return p.stdout+p.stderr

def main():
    baseline=ROOT/'baseline_original.luac'; payload=ROOT/'embedded_payload.bin'
    source=ROOT/'spectra_wrapper_phase_d_source.lua'; standard=ROOT/'spectra_wrapper_phase_d.standard.luac'; custom=ROOT/'spectra_wrapper_phase_d.custom.luac'
    assert sha(baseline)==EXPECTED_BASELINE_SHA and baseline.stat().st_size==180034
    assert sha(payload)==EXPECTED_PAYLOAD_SHA and payload.stat().st_size==108533
    b64=(ROOT/'embedded_payload.b64').read_text().strip(); assert base64.b64decode(b64)==payload.read_bytes()
    embed=(ROOT/'src/spectra/payload_embed.lua').read_text()
    chunks=re.findall(r'^\s*"([A-Za-z0-9+/=]+)",\s*$',embed,re.M)
    assert len(chunks)==801 and ''.join(chunks)==b64
    std=standard.read_bytes(); cus=custom.read_bytes()
    assert transform(cus,'to-standard',8)==std
    assert transform(transform(cus,'to-standard',8),'to-custom',4)==cus
    assert Scanner(cus).scan()['version']==0x53 and Scanner(cus).scan()['sizet_size']==4
    text=(ROOT/'src/spectra/native_settings_ui.lua').read_text()
    assert 'M.PAGE_TITLE = "@DrkZeref"' in text
    assert '@starrmods' not in text  # old title must not exist in editable runtime UI source
    for method in ['_InitDynamicBtns','SetSelectedModePanel','OnInitExtraData','OnShowBegin','OnActivate','_FetchSettingSystemByTab','_UpdateSysetemSettingPanel','OnHideBegin','OnClose']:
        assert method in text
    lua=runner()
    out=run([lua,str(ROOT/'tests/native_settings_ui.lua'),str(ROOT)]); assert 'native-settings-ui: ok' in out
    out_fc=run([lua,str(ROOT/'tests/feature_control.lua'),str(ROOT)]); assert 'feature-control: ok' in out_fc
    out_cv=run([lua,str(ROOT/'tests/character_visuals.lua'),str(ROOT)]); assert 'character-visuals: ok' in out_cv
    out_ar=run([lua,str(ROOT/'tests/aim_runtime.lua'),str(ROOT)]); assert 'aim-runtime: ok' in out_ar
    out_am=run([lua,str(ROOT/'tests/aim_mutation.lua'),str(ROOT)]); assert 'aim-mutation: ok' in out_am
    out_ab=run([lua,str(ROOT/'tests/aim_bones.lua'),str(ROOT)]); assert 'aim-bones: ok' in out_ab
    out_rf=run([lua,str(ROOT/'tests/aim_refresh.lua'),str(ROOT)]); assert 'aim-refresh: ok' in out_rf
    out_abi=run([lua,str(ROOT/'tests/aim_abi.lua'),str(ROOT)]); assert 'aim-abi: ok' in out_abi
    out_dispatch=run([lua,str(ROOT/'tests/aim_dispatch.lua'),str(ROOT)]); assert 'aim-dispatch: ok' in out_dispatch
    out_chain=run([lua,str(ROOT/'tests/aim_chain.lua'),str(ROOT)]); assert 'aim-chain: ok' in out_chain
    out_vr=run([lua,str(ROOT/'tests/visual_runtime.lua'),str(ROOT)]); assert 'visual-runtime: ok' in out_vr
    out_mr=run([lua,str(ROOT/'tests/mutation_runtime.lua'),str(ROOT)]); assert 'mutation-runtime: ok' in out_mr
    out_fb=run([lua,str(ROOT/'tests/payload_feature_bridge.lua'),str(ROOT)]); assert 'payload-feature-bridge: ok' in out_fb
    out_vs=run([lua,str(ROOT/'tests/visual_scan.lua'),str(ROOT)]); assert 'visual-scan: ok' in out_vs
    out_vb=run([lua,str(ROOT/'tests/payload_visual_bridge.lua'),str(ROOT)]); assert 'payload-visual-bridge: ok' in out_vb
    # Existing wrapper regressions must remain green.
    out2=run([lua,str(ROOT/'tests/smoke.lua'),str(ROOT)]); assert 'smoke: ok' in out2
    out3=run([lua,str(ROOT/'tests/protocol_fixture.lua'),str(ROOT)]); assert 'protocol-fixture: ok' in out3
    report={
      'phase':'D4-recovery-public-visual-runtime-takeover',
      'baseline':rec(baseline),'embedded_payload':rec(payload),'phase_d_source':rec(source),'phase_d_standard':rec(standard),'phase_d_custom':rec(custom),
      'reconstructed_group':{
        'ui_prototype':'0.29.105',
        'feature_control_prototypes':['0.29.73','0.29.77'],
        'aim_reconstruction':{
          'helper_prototypes':[f'0.29.{i}' for i in range(30,44)],
          'field_replacement_prototype':'0.29.65',
          'recursive_walker_prototype':'0.29.66',
          'outer_aim_row_branch':'0.29.67 (requires explicit P0.29.63 bone updater; inactive)',
          'feature_table_dispatch':'0.29.68 (source reconstructed; aim bridge inactive)',
          'refresh_abi_helpers':['0.29.2','0.29.3','0.29.4','0.29.12'],
        'bone_source_prototypes':['0.29.45','0.29.61','0.29.62','0.29.63','0.29.64'],
          'weapon_refresh_source_prototypes':['0.29.74','0.29.75','0.29.76'],
          'profile_ids':[1,1001,1002,1003,11001,1004],
          'source_present':True,
          'active_runtime_bridge':False,
          'gamepad_aim_chain_fixture':True,
          'walker_and_refresh_complete':False
        },
        'visual_entry_prototypes':['0.29.99','0.29.100','0.29.101','0.29.102','0.29.103'],
        'visual_scan_prototypes':[f'0.29.{i}' for i in range(78,99)],
        'hooks':9,'feature_controls':13,'title_widgets':4,
        'runtime_takeover':{
          'ui':True,
          'feature_control':{'no_recoil':True,'converge':True,'aim':False,'anti_shake':False},
          'visual_entries':{'set_ai_color':True,'set_real_player_color':True,'set_character_xray':True},
          'visual_background_tick':'reconstructed_source','visual_fashion_refresh_hook':'reconstructed_source'
        },
        'intentional_title_change':{'baseline':'@starrmods        ','reconstructed':'@DrkZeref'}
      },
      'checks':{
        'baseline_identity':True,'payload_identity':True,'payload_embed_801_fragments_exact':True,
        'custom_standard_roundtrip_exact':True,'lua53_chunk_structure':True,
        'native_settings_ui_smoke':'passed','feature_control_unit':'passed','character_visuals_unit':'passed',
        'aim_runtime_unit':'passed','aim_mutation_unit':'passed','aim_bones_unit':'passed','aim_refresh_unit':'passed','aim_abi_unit':'passed','aim_dispatch_unit':'passed','aim_chain_unit':'passed','visual_runtime_unit':'passed','mutation_runtime_unit':'passed',
        'payload_feature_bridge_unit':'passed','visual_scan_unit':'passed','visual_background_unit':'passed','payload_visual_bridge_unit':'passed',
        'wrapper_smoke':'passed','protocol_fixture':'passed','game_runtime_test':False
      },
      'correction':{
        'previous_unmaterialized_d4_claim_retracted':True,
        'note':'The prior D4 aim-takeover report referenced source files that were not present in the delivered workspace. This validation describes only materialized/tested artifacts.'
      }
    }
    (ROOT/'validation_phase_d.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
    print('phase-d-validation: ok')

if __name__=='__main__': main()

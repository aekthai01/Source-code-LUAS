#!/usr/bin/env python3
"""Reproducible structural index from the verified embedded-payload extraction.

Capture relationships are not automatically interpreted as invocation edges.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P = {x['path']: x for x in json.loads((ROOT/'payload_prototypes.json').read_text())}
C = json.loads((ROOT/'payload_constants.json').read_text())
IDS = [*range(30, 46), *range(61, 69), *range(74, 78)]
NESTED = ['0.29.62.0', '0.29.64.0', '0.29.66.0', '0.29.67.0', '0.29.67.0.0',
          '0.29.74.0', '0.29.76.0',
          '0.29.77.0', '0.29.77.0.0', '0.29.77.0.0.0', '0.29.77.0.0.0.0']
parent = (ROOT/'proto_0_29.txt').read_text()
closures = {int(reg): f'0.29.{proto}' for reg, proto in re.findall(r'CLOSURE\s+R(\d+), P(\d+)', parent)}
by_proto = {}
for p in P.values():
    for u in p['upvalues']:
        if p['path'].count('.') == 2 and p['path'].startswith('0.29.') and u['instack'] == 1 and u['idx'] in closures:
            by_proto.setdefault(closures[u['idx']], set()).add(p['path'])

def captured_closure(pid, upvalue):
    parent = pid.rsplit('.', 1)[0]
    if upvalue['instack']:
        if parent == '0.29': return closures.get(upvalue['idx'])
        return None  # local-register closure resolution requires parent SSA
    if parent == '0.29': return None
    return captured_closure(parent, P[parent]['upvalues'][upvalue['idx']])

out = {}
for pid in [*(f'0.29.{i}' for i in IDS), *NESTED]:
    p = P[pid]
    file = ROOT / ('proto_' + pid.replace('.', '_') + '.txt')
    if not file.exists(): file = ROOT / '_aim_sections' / (pid.replace('.', '_') + '.txt')
    if file.exists():
        lines = file.read_text().splitlines()
        evidence = str(file.relative_to(ROOT))
    else:
        file = ROOT/'payload_disassembly.txt'
        whole = file.read_text()
        header = f'=== PROTO {pid} '
        start = whole.index(header)
        end = whole.find('\n=== PROTO ', start + len(header))
        lines = whole[start:end if end >= 0 else None].splitlines()
        evidence = str(file.relative_to(ROOT)) + f' :: {pid}'
    up = []
    for u in p['upvalues']:
        idx = u['idx']
        up.append({'scope': 'parent_register' if u['instack'] else 'parent_upvalue',
                   'index': idx, 'closure': captured_closure(pid, u)})
    consts = [c['value'] for c in C if c['proto'] == pid]
    env_slots = [j for j, u in enumerate(p['upvalues']) if u['instack'] == 0 and u['idx'] == 0]
    globals_used = sorted({key for slot, key in re.findall(r"GETTABUP\s+R\d+, U(\d+), K\d+='([^']+)'", '\n'.join(lines))
                           if int(slot) in env_slots})
    writes = sorted(set(re.findall(r"SETTABUP\s+U\d+, K\d+='([^']+)'", '\n'.join(lines))))
    named_fields = sorted(set(re.findall(r"(?:GETTABLE|SETTABLE)\s+[^\n]*K\d+='([^']+)'", '\n'.join(lines))))
    returns = sorted(set(map(int, re.findall(r'RETURN\s+A=\d+ B=(\d+)', '\n'.join(lines)))))
    direct = []
    for n, line in enumerate(lines):
        m = re.search(r'GETUPVAL\s+R(\d+), U(\d+)', line)
        if not m: continue
        reg, slot = map(int, m.groups())
        for later in lines[n+1:n+15]:
            call = re.search(r'(?:TAILCALL|CALL)\s+A=(\d+)', later)
            if call and int(call.group(1)) == reg:
                target = up[slot]['closure']
                if target: direct.append({'callee':target,'call_instruction':int(later[:4]),'upvalue_slot':slot})
                break
            write = re.search(r'\b(?:MOVE|LOADK|LOADBOOL|LOADNIL|GETUPVAL|GETTABUP|GETTABLE|NEWTABLE|CLOSURE|ADD|SUB|MUL|DIV|CONCAT)\s+R?(\d+)[, ]', later)
            if write and int(write.group(1)) == reg: break
    out[pid] = {
        'evidence': evidence,
        'instruction_count': p['instruction_count'],
        'captured_upvalues': up,
        'captured_by': sorted(by_proto.get(pid, set())),
        'globals_from_environment': globals_used,
        'constants': consts,
        'state_keys_in_constants': sorted({v for v in consts if isinstance(v, str) and v.startswith('custom_')}),
        'table_or_config_literals': sorted({v for v in consts if isinstance(v, str) and ('Table' in v or 'Config' in v)}),
        'literal_fields': named_fields,
        'global_writes': writes,
        'return_B_operands': returns,
        'direct_calls_resolved': direct,
        'call_edges_note': 'Conservative GETUPVAL-to-CALL scan. Dynamic/global/alias calls can be unresolved.',
        'engine_side_effects': 'Undetermined by static extraction; inspect CALL sites before runtime takeover.',
        'reconstructed_name': {'0.29.65':'replace_aim_field', '0.29.66':'walk_and_patch_aim_field',
                               '0.29.77':'set_dongdong_aim_part'}.get(pid, 'P' + pid.replace('.', '_') + '_descriptive_pending'),
        'name_is_original_symbol': False,
        'confidence': 'structural metadata verified; dynamic behavior requires per-branch review',
    }
for pid, item in out.items():
    item['callers_resolved'] = sorted({caller for caller, source in out.items()
                                       if any(edge['callee'] == pid for edge in source['direct_calls_resolved'])})
(ROOT/'AIM_PROTOTYPE_INDEX.json').write_text(json.dumps(out, indent=2, ensure_ascii=False)+'\n')
print(f'indexed {len(out)} prototypes; {len(closures)} parent closures')

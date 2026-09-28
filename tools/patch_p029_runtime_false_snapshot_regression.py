#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def rep(path,old,new):
    p=ROOT/path; s=p.read_text(); n=s.count(old)
    if n!=1: raise SystemExit(f'{path}: anchor count {n}: {old[:120]!r}')
    p.write_text(s.replace(old,new,1))

# P0.29.15 captures P0.29.2 as U0 and calls it before recording the original.
# Therefore a literal false field is normalized to nil in the payload snapshot.
rep('tests/aim_mutation.lua',
'eq(nested.bTakeEffect, false, "original value restored")',
'eq(nested.bTakeEffect, nil, "P15 snapshots false through P2 as nil")')

rep('tools/validate_phase_d.py',
"""    assert re.search(r'^0018 RETURN\\s+A=5 B=2 C=0$',p13,re.M)\n\n    runtime_source=(ROOT/'src/spectra/p029_runtime_helpers.lua').read_text()\n""",
"""    assert re.search(r'^0018 RETURN\\s+A=5 B=2 C=0$',p13,re.M)\n\n    # P0.29.15 is not migrated here, but its active source reconstruction must\n    # inherit exact P0.29.2 false->nil behavior. U0 captures R19/P2 and the\n    # original field read is the P2 call at PC0012 before snapshot recording.\n    p15=body('0.29.15')\n    assert prototypes['0.29.15']['upvalues'][0]=={'instack':1,'idx':19}\n    assert re.search(r'^0009 GETUPVAL\\s+R4, U0$',p15,re.M)\n    assert re.search(r'^0012 CALL\\s+A=4 B=3 C=2$',p15,re.M)\n\n    runtime_source=(ROOT/'src/spectra/p029_runtime_helpers.lua').read_text()\n""")
print('P0.29.15 false snapshot regression pinned')

#!/usr/bin/env python3
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'tools/validate_phase_d.py'
s=p.read_text()
old="mutation_paths={'0.29.10','0.29.18','0.29.49'}"
new="mutation_paths={'0.29.10','0.29.14','0.29.15','0.29.16','0.29.18','0.29.49'}"
assert s.count(old)==1,(old,s.count(old))
s=s.replace(old,new,1)
p.write_text(s)
print('aligned mutation evidence ownership boundary with snapshot helpers')

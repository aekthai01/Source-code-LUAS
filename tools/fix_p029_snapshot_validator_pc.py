#!/usr/bin/env python3
from pathlib import Path
p=Path(__file__).resolve().parent/'patch_p029_snapshot_helpers.py'
s=p.read_text()
repls={
"^1001 CLOSURE\\s+R34, P14$":"^0329 CLOSURE\\s+R34, P14$",
"^1002 CLOSURE\\s+R35, P15$":"^0330 CLOSURE\\s+R35, P15$",
"^1003 CLOSURE\\s+R36, P16$":"^0331 CLOSURE\\s+R36, P16$",
}
for old,new in repls.items():
    assert s.count(old)==1,(old,s.count(old))
    s=s.replace(old,new,1)
p.write_text(s)
print('fixed snapshot validator root closure PCs')

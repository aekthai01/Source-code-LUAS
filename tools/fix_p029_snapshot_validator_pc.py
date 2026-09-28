#!/usr/bin/env python3
from pathlib import Path
p=Path(__file__).resolve().parent/'patch_p029_snapshot_helpers.py'
s=p.read_text()
repls={
"1001 CLOSURE":"0329 CLOSURE",
"1002 CLOSURE":"0330 CLOSURE",
"1003 CLOSURE":"0331 CLOSURE",
}
for old,new in repls.items():
    assert s.count(old)==1,(old,s.count(old))
    s=s.replace(old,new,1)
p.write_text(s)
print('fixed snapshot validator root closure PCs')

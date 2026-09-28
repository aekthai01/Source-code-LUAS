#!/usr/bin/env python3
from pathlib import Path
p=Path(__file__).resolve().parent/'patch_p029_72_source.py'
s=p.read_text(encoding='utf-8')
old='''old=''' + "'''" + '''    \"runtime.lua\", \"crypto.lua\", \"storage.lua\", \"transport.lua\", \"payload_embed.lua\",\\n    \"aim_runtime.lua\", \"visual_runtime.lua\", \"aim_abi.lua\", \"p029_runtime_helpers.lua\", \"mutation_runtime.lua\",''' + "'''" + '''\nnew=''' + "'''" + '''    \"runtime.lua\", \"crypto.lua\", \"storage.lua\", \"transport.lua\", \"payload_embed.lua\",\\n    \"visual_runtime.lua\", \"aim_abi.lua\", \"p029_runtime_helpers.lua\", \"aim_runtime.lua\", \"mutation_runtime.lua\",''' + "'''"
new='''old=''' + "'''" + '''    \"runtime.lua\", \"crypto.lua\", \"storage.lua\", \"transport.lua\", \"payload_embed.lua\",
    \"aim_runtime.lua\", \"visual_runtime.lua\", \"aim_abi.lua\", \"p029_runtime_helpers.lua\", \"mutation_runtime.lua\",''' + "'''" + '''\nnew=''' + "'''" + '''    \"runtime.lua\", \"crypto.lua\", \"storage.lua\", \"transport.lua\", \"payload_embed.lua\",
    \"visual_runtime.lua\", \"aim_abi.lua\", \"p029_runtime_helpers.lua\", \"aim_runtime.lua\", \"mutation_runtime.lua\",''' + "'''"
assert s.count(old)==1, ('build-anchor',s.count(old))
s=s.replace(old,new,1)
old_bridge="old='set_fire_assisted_aim_debug=function(enabled) return AimRuntime.set_fire_assisted_aim_debug(Runtime.delay,enabled) end,'"
new_bridge="old='set_fire_assisted_aim_debug=function(enabled) return AimRuntime.set_fire_assisted_aim_debug(Runtime.delay, enabled) end,'"
assert s.count(old_bridge)==1, ('bridge-anchor',s.count(old_bridge))
s=s.replace(old_bridge,new_bridge,1)
p.write_text(s,encoding='utf-8')
print('fixed staging build/bridge anchors')

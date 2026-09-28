#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def rep(path,old,new):
 p=ROOT/path; s=p.read_text(); n=s.count(old)
 if n!=1: raise SystemExit(f'{path}: anchor count {n}: {old[:120]!r}')
 p.write_text(s.replace(old,new,1))

rep('src/spectra/mutation_runtime.lua',
'local S = ...\nassert(type(S) == "table", "spectra module table required")\n',
'local S = ...\nassert(type(S) == "table", "spectra module table required")\nlocal ABI = assert(S.AimABI, "AimABI required")\nlocal RuntimeHelpers = assert(S.P029RuntimeHelpers, "P0.29 runtime helpers required")\n')
rep('src/spectra/mutation_runtime.lua',
'''local function safe_get(obj, key)\n    if obj == nil then return nil end\n    local ok, value = pcall(function() return obj[key] end)\n    if ok then return value end\n    return nil\nend\nM.safe_get = safe_get\n\nlocal function call_optional_self(fn, self, ...)\n    if type(fn) ~= "function" then return false, nil end\n    local ok, a, b = pcall(fn, self, ...)\n    if ok then return true, a, b end\n    ok, a, b = pcall(fn, ...)\n    if ok then return true, a, b end\n    return false, nil\nend\nM.call_optional_self = call_optional_self\n''',
'''local safe_get = ABI.get\nlocal call_optional_self = ABI.call_optional_self\nM.safe_get = safe_get\nM.call_optional_self = call_optional_self\n''')
rep('src/spectra/mutation_runtime.lua',
'''function M.get_table_manager()\n    local facade = rawget(_G, "Facade")\n    local manager = safe_get(facade, "TableManager")\n    if manager ~= nil then return manager end\n    return rawget(_G, "TableManager")\nend\n\nfunction M.get_data_table(name)\n    local manager = M.get_table_manager()\n    local fn = safe_get(manager, "GetTable")\n    local ok, value = call_optional_self(fn, manager, name)\n    if ok then return value end\n    return nil\nend\n''',
'''M.get_table_manager = RuntimeHelpers.get_table_manager\nM.get_data_table = RuntimeHelpers.get_data_table\n''')

rep('src/spectra/visual_scan.lua',
'local S = ...\nassert(type(S) == "table", "spectra module table required")\n',
'local S = ...\nassert(type(S) == "table", "spectra module table required")\nlocal RuntimeHelpers = assert(S.P029RuntimeHelpers, "P0.29 runtime helpers required")\n')
rep('src/spectra/visual_scan.lua',
'''local function object_name(obj)\n    if obj==nil then return "" end\n    for _,n in ipairs({"GetFullName","GetName"}) do\n        local ok,v=method(obj,n)\n        if ok and v~=nil then return tostring(v) end\n    end\n    return tostring(obj)\nend\n''',
'local object_name = RuntimeHelpers.object_name\n')
rep('src/spectra/visual_scan.lua',
'''function M.is_mesh_component(value)\n    if not is_valid(value) then return false end\n    local ok=method(value,"GetNumMaterials")\n    if not ok then return false end\n    local setm=safe_get(value,"SetMaterial"); if type(setm)~="function" then return false end\n    return type(safe_get(value,"SetOverlayMaterial"))=="function"\nend\n''',
'''function M.is_mesh_component(value)\n    if not is_valid(value) then return false end\n    local ok=method(value,"GetNumMaterials")\n    if not ok then return false end\n    if not RuntimeHelpers.is_function_field(value,"SetMaterial") then return false end\n    return RuntimeHelpers.is_function_field(value,"SetOverlayMaterial")\nend\n''')

rep('src/spectra/payload_feature_bridge.lua',
'    local Runtime, _, Mutation, AimChain, AimBones, AimABI, AimRefresh, AimRuntime = source_modules()\n    local deps = {}\n',
'    local Runtime, _, Mutation, AimChain, AimBones, AimABI, AimRefresh, AimRuntime = source_modules()\n    local RuntimeHelpers = assert(S.P029RuntimeHelpers, "P0.29.8 delay helper required")\n    local deps = {}\n')
rep('src/spectra/payload_feature_bridge.lua','    choose("delay", Runtime.delay)\n','    choose("delay", RuntimeHelpers.delay)\n')
rep('src/spectra/payload_feature_bridge.lua',
'    local Runtime, FeatureControl, Mutation, AimChain, AimBones, AimABI, AimRefresh, AimRuntime = source_modules()\n    local required = {\n        {Runtime, "delay"}, {FeatureControl, "set_dongdong_feature_config"},\n',
'    local Runtime, FeatureControl, Mutation, AimChain, AimBones, AimABI, AimRefresh, AimRuntime = source_modules()\n    local RuntimeHelpers = S.P029RuntimeHelpers\n    local required = {\n        {Runtime, "delay"}, {RuntimeHelpers, "delay"}, {FeatureControl, "set_dongdong_feature_config"},\n')

rep('tests/mutation_runtime.lua',
'local root = assert(arg[1], "root path required")\nlocal S = {}\nassert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)\n',
'local root = assert(arg[1], "root path required")\nlocal S = {}\nassert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)\nassert(loadfile(root .. "/src/spectra/p029_runtime_helpers.lua"))(S)\nassert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)\n')
rep('tests/visual_scan.lua',
"local root=assert(arg[1]); local S={}\nassert(loadfile(root..'/src/spectra/visual_scan.lua'))(S)\n",
"local root=assert(arg[1]); local S={}\nassert(loadfile(root..'/src/spectra/aim_abi.lua'))(S)\nassert(loadfile(root..'/src/spectra/p029_runtime_helpers.lua'))(S)\nassert(loadfile(root..'/src/spectra/visual_scan.lua'))(S)\n")
rep('tests/payload_feature_bridge.lua',
'S.AimABI = { get=function(o,k) return o and o[k] or nil end }\n',
'S.AimABI = { get=function(o,k) return o and o[k] or nil end }\nS.P029RuntimeHelpers = { delay=function(_, cb) cb(); return nil end }\n')

# Unit tests that directly load MutationRuntime/VisualScan must mirror the new
# explicit production dependency order. This is test-loader plumbing, not a
# fallback inside the production modules.
for test in (ROOT/'tests').glob('*.lua'):
 s=test.read_text()
 if ('src/spectra/mutation_runtime.lua' not in s and 'src/spectra/visual_scan.lua' not in s):
  continue
 if 'src/spectra/aim_abi.lua' in s:
  continue
 preload='assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)\nassert(loadfile(root .. "/src/spectra/p029_runtime_helpers.lua"))(S)\n'
 for marker in ('local S = {}\n','local S={}\n'):
  if marker in s:
   s=s.replace(marker,marker+preload,1)
   test.write_text(s)
   break
 else:
  raise SystemExit(f'{test}: direct source loader has no recognized S initialization')

print('source integration patched')

#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def put(path,text):
    path.write_text(text,encoding='utf-8')

# Exact captured-state P0.29.14/.15/.15.0/.16 implementations. Preserve the
# existing state-explicit compatibility API for already-migrated source layers.
p=ROOT/'src/spectra/mutation_runtime.lua'; s=p.read_text()
anchor='M.get_table_manager = RuntimeHelpers.get_table_manager\nM.get_data_table = RuntimeHelpers.get_data_table\n\n'
assert s.count(anchor)==1
block=r'''M.get_table_manager = RuntimeHelpers.get_table_manager
M.get_data_table = RuntimeHelpers.get_data_table

-- Exact P0.29 snapshot-helper closure family. P0.29 is constructed with _G as
-- its captured state; P14/P16 capture that R0 identity and P15 captures the
-- fixed P2/P14 sibling closures. Compatibility functions below remain state-
-- explicit for older source layers, while ownership evidence targets these
-- exact closures.
local snapshot_state_029 = _G
local snapshot_safe_get_029_2 = safe_get

local function ensure_feature_snapshot_029_14(feature)
    local snapshots = snapshot_state_029.custom_dongdong_feature_snapshots
    if type(snapshots) ~= "table" then
        snapshots = {}
        snapshot_state_029.custom_dongdong_feature_snapshots = snapshots
    end
    local snapshot = snapshots[feature]
    if type(snapshot) ~= "table" then
        snapshot = { records = {}, seen = {} }
        snapshots[feature] = snapshot
    end
    return snapshot
end

local ensure_feature_snapshot_capture_029_14 = ensure_feature_snapshot_029_14
local function snapshot_set_029_15(feature, object, key, value)
    if object == nil or key == nil then return false end
    local previous = snapshot_safe_get_029_2(object, key)
    if previous == value then return true end
    local snapshot = ensure_feature_snapshot_capture_029_14(feature)
    local identity = tostring(object) .. "\0" .. tostring(key)
    if snapshot.seen[identity] ~= true then
        snapshot.seen[identity] = true
        snapshot.records[#snapshot.records + 1] = {
            object = object,
            key = key,
            value = previous,
        }
    end
    return pcall(function() object[key] = value end)
end

local function clear_feature_snapshot_029_16(feature)
    local snapshots = snapshot_state_029.custom_dongdong_feature_snapshots
    if type(snapshots) == "table" then snapshots[feature] = nil end
end

M.p029_ensure_feature_snapshot = ensure_feature_snapshot_029_14
M.p029_snapshot_set = snapshot_set_029_15
M.p029_clear_feature_snapshot = clear_feature_snapshot_029_16

'''
s=s.replace(anchor,block,1); put(p,s)

# Focused exact ABI/arity/capture regressions.
p=ROOT/'tests/mutation_runtime.lua'; s=p.read_text(); marker='-- Exact path inventory recovered from the parent constants feeding P0.29.68.\n'; assert s.count(marker)==1
tests=r'''-- Exact P0.29.14/.15/.15.0/.16 captured-state ABI.
local saved_feature_snapshots=rawget(_G,"custom_dongdong_feature_snapshots")
rawset(_G,"custom_dongdong_feature_snapshots",nil)
local function packcall(fn,...) return table.pack(fn(...)) end
local p14=M.p029_ensure_feature_snapshot
local p15=M.p029_snapshot_set
local p16=M.p029_clear_feature_snapshot
truth(type(p14)=="function" and type(p15)=="function" and type(p16)=="function","exact snapshot helpers exported")
local a=packcall(p14,"aim"); eq(a.n,1,"P14 return count"); truth(type(a[1])=="table","P14 snapshot")
eq(type(a[1].records),"table","P14 records"); eq(type(a[1].seen),"table","P14 seen")
eq(packcall(p14,"aim").n,1,"P14 existing return count")
local owner={Value=3,FalseValue=false}
local r=packcall(p15,"aim",nil,"Value",4); eq(r.n,1,"P15 nil owner arity"); eq(r[1],false,"P15 nil owner")
r=packcall(p15,"aim",owner,nil,4); eq(r.n,1,"P15 nil key arity"); eq(r[1],false,"P15 nil key")
r=packcall(p15,"aim",owner,"Value",3); eq(r.n,1,"P15 unchanged arity"); eq(r[1],true,"P15 unchanged")
eq(#_G.custom_dongdong_feature_snapshots.aim.records,0,"P15 unchanged no record")
r=packcall(p15,"aim",owner,"Value",9); eq(r.n,1,"P15 success pcall arity"); eq(r[1],true,"P15 success")
eq(owner.Value,9,"P15 write"); eq(#_G.custom_dongdong_feature_snapshots.aim.records,1,"P15 one record")
eq(_G.custom_dongdong_feature_snapshots.aim.records[1].value,3,"P15 original")
r=packcall(p15,"aim",owner,"Value",10); eq(r.n,1,"P15 repeated success arity")
eq(#_G.custom_dongdong_feature_snapshots.aim.records,1,"P15 dedupe")
-- P2 semantics collapse a literal false field to nil before it is recorded.
r=packcall(p15,"aim",owner,"FalseValue",true); eq(r.n,1,"P15 false write arity"); eq(r[1],true,"P15 false write")
eq(_G.custom_dongdong_feature_snapshots.aim.records[2].value,nil,"P15 P2 false->nil snapshot")
local rejecting=setmetatable({}, {__newindex=function() error("blocked-write") end})
r=packcall(p15,"aim",rejecting,"Blocked",1); eq(r.n,2,"P15 failure pcall arity"); eq(r[1],false,"P15 failure flag"); truth(tostring(r[2]):find("blocked%-write")~=nil,"P15 failure error preserved")
-- P15 captures P14 once. Replacing the exported P14 symbol cannot redirect it.
M.p029_ensure_feature_snapshot=function() error("mutated P14 export observed") end
r=packcall(p15,"capture",{},"X",1); eq(r.n,1,"P15 fixed P14 capture arity"); eq(r[1],true,"P15 fixed P14 capture")
M.p029_ensure_feature_snapshot=p14
r=packcall(p16,"aim"); eq(r.n,0,"P16 clear arity"); eq(_G.custom_dongdong_feature_snapshots.aim,nil,"P16 clears")
rawset(_G,"custom_dongdong_feature_snapshots",nil); r=packcall(p16,"aim"); eq(r.n,0,"P16 absent arity")
rawset(_G,"custom_dongdong_feature_snapshots",saved_feature_snapshots)

'''
s=s.replace(marker,tests+marker,1); put(p,s)

# Extend generated ownership/evidence through the existing mutation-helper map.
p=ROOT/'tools/aim_forensics.py'; s=p.read_text()
s=s.replace('    "0.29.17.0",\n','    "0.29.15.0",\n    "0.29.17.0",\n',1)
s=s.replace('MUTATION_HELPERS = ["0.29.10", "0.29.18", "0.29.49"]','MUTATION_HELPERS = ["0.29.10", "0.29.14", "0.29.15", "0.29.16", "0.29.18", "0.29.49"]',1)
s=s.replace('assert len(NESTED) == 12','assert len(NESTED) == 13',1)
s=s.replace('assert len(MUTATION_HELPERS) == 3','assert len(MUTATION_HELPERS) == 6',1)
s=s.replace('assert len(ALL) == 57 and len(set(ALL)) == 57','assert len(ALL) == 61 and len(set(ALL)) == 61',1)
s=s.replace('    if pid == "0.29.17.0":\n        return "src/spectra/mutation_runtime.lua"','    if pid in {"0.29.15.0", "0.29.17.0"}:\n        return "src/spectra/mutation_runtime.lua"',1)
s=s.replace('    "0.29.13": "R33",\n    "0.29.10": "R30",','    "0.29.13": "R33",\n    "0.29.10": "R30",\n    "0.29.14": "R34",\n    "0.29.15": "R35",\n    "0.29.16": "R36",',1)
old='mutation_symbols={"0.29.10":"MutationRuntime.normalize_identifier","0.29.18":"MutationRuntime.table_extend","0.29.49":"MutationRuntime.array_get"}'
new='mutation_symbols={"0.29.10":"MutationRuntime.normalize_identifier","0.29.14":"MutationRuntime.p029_ensure_feature_snapshot","0.29.15":"MutationRuntime.p029_snapshot_set","0.29.16":"MutationRuntime.p029_clear_feature_snapshot","0.29.18":"MutationRuntime.table_extend","0.29.49":"MutationRuntime.array_get"}'
assert s.count(old)==1; s=s.replace(old,new,1)
s=s.replace('  "0.29.10":"tail-return string.gsub: exactly normalized string plus substitution count",\n', '  "0.29.10":"tail-return string.gsub: exactly normalized string plus substitution count",\n  "0.29.14":"exactly one snapshot table; captured state table identity",\n  "0.29.15":"nil owner/key and unchanged paths exactly one boolean; assignment tailcalls pcall so success is one true and failure is false,error",\n  "0.29.16":"exactly zero returns after clearing captured state snapshot entry when snapshot root is a table",\n',1)
s=s.replace('  "0.29.10":"lower(tostring(input or empty)); tailcall gsub non-word removal",\n', '  "0.29.10":"lower(tostring(input or empty)); tailcall gsub non-word removal",\n  "0.29.14":"captured R0 snapshot root; type gates; create {records={},seen={}} only when feature snapshot is not table",\n  "0.29.15":"nil owner/key gate; fixed P2 read; equality short-circuit; fixed P14 snapshot; tostring identity dedupe; tailcall pcall assignment child",\n  "0.29.16":"captured R0 snapshot root; only clear feature when root type is table; zero-value return",\n',1)
put(p,s)

# Structural validator: exact metadata, captures, opcodes, ownership and source symbols.
p=ROOT/'tools/validate_phase_d.py'; s=p.read_text()
old='''    # P0.29.15 is not migrated here, but its active source reconstruction must\n    # inherit exact P0.29.2 false->nil behavior. U0 captures R19/P2 and the\n    # original field read is the P2 call at PC0012 before snapshot recording.\n    p15=body('0.29.15')\n    assert prototypes['0.29.15']['upvalues'][0]=={'instack':1,'idx':19}\n    assert re.search(r'^0009 GETUPVAL\\s+R4, U0$',p15,re.M)\n    assert re.search(r'^0012 CALL\\s+A=4 B=3 C=2$',p15,re.M)\n'''
new='''    # Exact P0.29.14/.15/.15.0/.16 captured snapshot-helper family.\n    snap_paths={'0.29.14','0.29.15','0.29.15.0','0.29.16'}\n    assert snap_paths <= set(groups['source_owned'])\n    assert all(source_files[path]=='src/spectra/mutation_runtime.lua' for path in snap_paths)\n    p14m,p15m,p150m,p16m=(prototypes[x] for x in ('0.29.14','0.29.15','0.29.15.0','0.29.16'))\n    assert (p14m['numparams'],p14m['instruction_count'],p14m['upvalues'],p14m['child_count'])==(1,27,[{'instack':1,'idx':0},{'instack':0,'idx':0}],0)\n    assert (p15m['numparams'],p15m['instruction_count'],p15m['upvalues'],p15m['child_count'])==(4,48,[{'instack':1,'idx':19},{'instack':1,'idx':34},{'instack':0,'idx':0}],1)\n    assert (p150m['numparams'],p150m['instruction_count'],p150m['upvalues'],p150m['child_count'])==(0,7,[{'instack':1,'idx':1},{'instack':1,'idx':2},{'instack':1,'idx':3}],0)\n    assert (p16m['numparams'],p16m['instruction_count'],p16m['upvalues'],p16m['child_count'])==(1,11,[{'instack':1,'idx':0},{'instack':0,'idx':0}],0)\n    root=body('0.29')\n    assert re.search(r'^1001 CLOSURE\\s+R34, P14$',root,re.M)\n    assert re.search(r'^1002 CLOSURE\\s+R35, P15$',root,re.M)\n    assert re.search(r'^1003 CLOSURE\\s+R36, P16$',root,re.M)\n    p14,p15,p150,p16=(body(x) for x in ('0.29.14','0.29.15','0.29.15.0','0.29.16'))\n    assert re.search(r"^0003 GETTABUP\\s+R1, U0, K0='custom_dongdong_feature_snapshots'$",p14,re.M)\n    assert re.search(r'^0025 RETURN\\s+A=2 B=2 C=0$',p14,re.M)\n    assert re.search(r'^0009 GETUPVAL\\s+R4, U0$',p15,re.M) and re.search(r'^0012 CALL\\s+A=4 B=3 C=2$',p15,re.M)\n    assert re.search(r'^0017 GETUPVAL\\s+R5, U1$',p15,re.M) and re.search(r'^0019 CALL\\s+A=5 B=2 C=2$',p15,re.M)\n    assert re.search(r'^0044 CLOSURE\\s+R8, P0$',p15,re.M) and re.search(r'^0045 TAILCALL\\s+A=7 B=2 C=0$',p15,re.M) and re.search(r'^0046 RETURN\\s+A=7 B=0 C=0$',p15,re.M)\n    assert re.search(r'^0003 GETUPVAL\\s+R0, U1$',p150,re.M) and re.search(r'^0005 SETTABUP\\s+U0, R0, R1$',p150,re.M) and re.search(r'^0006 RETURN\\s+A=0 B=1 C=0$',p150,re.M)\n    assert re.search(r"^0003 GETTABUP\\s+R1, U0, K0='custom_dongdong_feature_snapshots'$",p16,re.M) and re.search(r'^0010 RETURN\\s+A=0 B=1 C=0$',p16,re.M)\n'''
assert s.count(old)==1; s=s.replace(old,new,1)
needle="    assert 'M.get_data_table = RuntimeHelpers.get_data_table' in mutation_source\n"
add="""    assert 'local snapshot_state_029 = _G' in mutation_source\n    assert 'local snapshot_safe_get_029_2 = safe_get' in mutation_source\n    assert 'local ensure_feature_snapshot_capture_029_14 = ensure_feature_snapshot_029_14' in mutation_source\n    assert 'M.p029_ensure_feature_snapshot = ensure_feature_snapshot_029_14' in mutation_source\n    assert 'M.p029_snapshot_set = snapshot_set_029_15' in mutation_source\n    assert 'M.p029_clear_feature_snapshot = clear_feature_snapshot_029_16' in mutation_source\n"""
assert s.count(needle)==1; s=s.replace(needle,needle+add,1)
put(p,s)
print('applied exact P0.29 snapshot helper checkpoint')

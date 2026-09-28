#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BRANCH = "work/phase-d-aim-reconstruction"


def run(*args, capture=False):
    p = subprocess.run(args, cwd=ROOT, text=True, capture_output=capture)
    if p.returncode:
        if capture:
            print(p.stdout)
            print(p.stderr)
        raise SystemExit(f"command failed ({p.returncode}): {' '.join(args)}")
    return p.stdout if capture else None


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def write(path, text):
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(path, old, new):
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one replacement target, found {count}: {old[:80]!r}")
    write(path, text.replace(old, new, 1))


def patch_product_module():
    path = "src/spectra/product_module.lua"
    text = read(path)
    marker = '    GetMatchBulletNumByWeaponItem = "0.13",\n'
    if '    _CheckNightFight = "0.14",\n' not in text:
        replace_once(path, marker, marker +
            '    _CheckNightFight = "0.14",\n'
            '    _CheckPlayerSuppliesForNightSpeicalType = "0.15",\n')
    text = read(path)
    if "function M._CheckNightFight(" in text:
        return
    functions = r'''

-- P0.14 captures root R8 ItemBaseTool and root R3 product. The enum is
-- traversed with pairs and the yielded value (not key) is passed to the field
-- check. matchModeIDList is deliberately read twice because the bytecode has
-- two observable GETTABLE/TEST sequences. The supply helper is resolved from
-- the product table at call time so runtime replacement remains visible.
function M._CheckNightFight(product, globals, item_base_tool)
    globals = globals_or_default(globals)
    local match_mode_id = globals.Server.GameModeServer:GetMatchModeID()
    if not match_mode_id then return end
    if not (0 < match_mode_id) then return end

    for _, special_type in globals.pairs(item_base_tool.EItemSpeicalType) do
        local field = globals.Module.ArmedForce.Field
        local check_data = field:GetEquipmentCheckData(
            globals.Module.ArmedForce.Config.EAbnormalType.LackNight, special_type)
        if check_data and check_data.switch then
            local match_mode_id_list = check_data.matchModeIDList
            if match_mode_id_list then
                match_mode_id_list = check_data.matchModeIDList
                if match_mode_id_list
                    and globals.table.contains(match_mode_id_list, match_mode_id) then
                    local check_supplies = product._CheckPlayerSuppliesForNightSpeicalType
                    if not check_supplies(check_data.checkSubType) then
                        globals.Module.ArmedForce.Field:AddEquipAbnormal({
                            key = check_data.key,
                            abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.LackNight,
                            loc = check_data.abnormalDesc,
                            param = {
                                abnormalSubType = check_data.checkSubType,
                            },
                        })
                    end
                end
            end
        end
    end
end

-- P0.15 uses the current source product table for both traversal lists and the
-- captured root R8 ItemBaseTool for a plain/static helper call. Equipment is
-- exhausted before containers; the first supported item returns true and a
-- complete miss returns the literal boolean false.
function M._CheckPlayerSuppliesForNightSpeicalType(product, globals, item_base_tool, special_type)
    globals = globals_or_default(globals)
    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()

    for _, slot_type in globals.ipairs(product.EquipTypeList) do
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        if slot then
            local item = slot:GetEquipItem()
            if item and item_base_tool.CheckSupportNightBattleBySpeicalType(item, special_type) then
                return true
            end
        end
    end

    for _, slot_type in globals.ipairs(product.ContainerTypeList) do
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        if slot then
            local items = slot:GetItems()
            if items and not globals.table.isempty(items) then
                for _, item in globals.ipairs(items) do
                    if item and item_base_tool.CheckSupportNightBattleBySpeicalType(item, special_type) then
                        return true
                    end
                end
            end
        end
    end

    return false
end
'''
    replace_once(path, "\nreturn M", functions + "\nreturn M")


def patch_constructor():
    path = "src/spectra/product_constructor.lua"
    text = read(path)
    if 'mode == "night_zero_arg_item_base"' not in text:
        replace_once(path,
            'local function bind(product, globals, source, dependencies, mode)\n    if mode == "weapon_count" then',
            'local function bind(product, globals, source, dependencies, mode)\n'
            '    if mode == "night_zero_arg_item_base" then\n'
            '        return function()\n'
            '            return source(product, globals, dependencies.item_base_tool)\n'
            '        end\n'
            '    end\n'
            '    if mode == "night_one_arg_item_base" then\n'
            '        return function(a)\n'
            '            return source(product, globals, dependencies.item_base_tool, a)\n'
            '        end\n'
            '    end\n'
            '    if mode == "weapon_count" then')
    text = read(path)
    if 'product._CheckNightFight = bind(' not in text:
        target = '''    product.GetMatchBulletNumByWeaponItem = bind(product, globals,
        Product.GetMatchBulletNumByWeaponItem, p13, "weapon_count")

    local slot = assert(globals.ESlotType, "ESlotType required")'''
        replacement = '''    product.GetMatchBulletNumByWeaponItem = bind(product, globals,
        Product.GetMatchBulletNumByWeaponItem, p13, "weapon_count")
    local p14_p15 = { item_base_tool = context.item_base_tool }
    product._CheckNightFight = bind(product, globals,
        Product._CheckNightFight, p14_p15, "night_zero_arg_item_base")
    product._CheckPlayerSuppliesForNightSpeicalType = bind(product, globals,
        Product._CheckPlayerSuppliesForNightSpeicalType, p14_p15, "night_one_arg_item_base")

    local slot = assert(globals.ESlotType, "ESlotType required")'''
        replace_once(path, target, replacement)
    text = read(path).replace("P0.0..P0.13 boundary", "P0.0..P0.15 boundary")
    write(path, text)


def patch_bridge():
    path = "src/spectra/product_module_bridge.lua"
    text = read(path)
    if '    "_CheckNightFight",\n' not in text:
        replace_once(path,
            '    "GetMatchBulletNumByWeaponItem",\n}',
            '    "GetMatchBulletNumByWeaponItem",\n'
            '    "_CheckNightFight",\n'
            '    "_CheckPlayerSuppliesForNightSpeicalType",\n}')
    text = read(path)
    if '_CheckNightFight = {' not in text:
        target = '''        GetMatchBulletNumByWeaponItem = {
            ammo_data_manager = context.ammo_data_manager,
            weapon_assembly_tool = context.weapon_assembly_tool,
        },
    }'''
        replacement = '''        GetMatchBulletNumByWeaponItem = {
            ammo_data_manager = context.ammo_data_manager,
            weapon_assembly_tool = context.weapon_assembly_tool,
        },
        _CheckNightFight = {
            item_base_tool = context.item_base_tool,
        },
        _CheckPlayerSuppliesForNightSpeicalType = {
            item_base_tool = context.item_base_tool,
        },
    }'''
        replace_once(path, target, replacement)
    text = read(path)
    if 'elseif name == "_CheckNightFight" then' not in text:
        target = '''        elseif name == "GetMatchBulletNumByWeaponItem" then
            result = table.pack(pcall(target, product, dependencies.globals or environment,
                dependencies.ammo_data_manager, dependencies.weapon_assembly_tool,
                arguments[1], arguments[2]))
        else'''
        replacement = '''        elseif name == "GetMatchBulletNumByWeaponItem" then
            result = table.pack(pcall(target, product, dependencies.globals or environment,
                dependencies.ammo_data_manager, dependencies.weapon_assembly_tool,
                arguments[1], arguments[2]))
        elseif name == "_CheckNightFight" then
            result = table.pack(pcall(target, product, environment, dependencies.item_base_tool))
        elseif name == "_CheckPlayerSuppliesForNightSpeicalType" then
            result = table.pack(pcall(target, product, environment,
                dependencies.item_base_tool, arguments[1]))
        else'''
        replace_once(path, target, replacement)
    text = read(path)
    if '_CheckNightFight = Source._CheckNightFight' not in text:
        replace_once(path,
            '        GetMatchBulletNumByWeaponItem = Source.GetMatchBulletNumByWeaponItem,\n    }',
            '        GetMatchBulletNumByWeaponItem = Source.GetMatchBulletNumByWeaponItem,\n'
            '        _CheckNightFight = Source._CheckNightFight,\n'
            '        _CheckPlayerSuppliesForNightSpeicalType = Source._CheckPlayerSuppliesForNightSpeicalType,\n'
            '    }')
    text = read(path).replace("P0.0..P0.13", "P0.0..P0.15")
    write(path, text)


def focused_test_text():
    return r'''local root=assert(arg[1])
local S={}
assert(loadfile(root.."/src/spectra/product_module.lua"))(S)
assert(loadfile(root.."/src/spectra/product_constructor.lua"))(S)
local Product=S.ProductModule
local Constructor=S.ProductConstructor
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function field_count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end

local mode
local queries={}
local abnormals={}
local check_by_type={}
local field={}
function field:GetEquipmentCheckData(kind,special_type)
    eq(kind,"lack-night","P0.14 abnormal type")
    queries[#queries+1]=special_type
    return check_by_type[special_type]
end
function field:AddEquipAbnormal(record) abnormals[#abnormals+1]=record end
local env={
    Server={
        GameModeServer={GetMatchModeID=function() return mode end},
        ArmedForceServer={GetCurSlotGroupId=function() return "group-15" end},
        InventoryServer={},
    },
    Module={ArmedForce={
        Field=field,
        Config={EAbnormalType={LackNight="lack-night"}},
    }},
    table={
        contains=function(list,value)
            for _,candidate in pairs(list) do if candidate==value then return true end end
            return false
        end,
        isempty=function(value) return next(value)==nil end,
    },
    pairs=pairs,
    ipairs=ipairs,
    ESlotType={
        MainWeaponLeft="left",MainWeaponRight="right",Pistrol="pistol",
        BreastPlate="breast",Helmet="helmet",ChestHanging="chest",Bag="bag",
        ChestHangingContainer="chest-container",Pocket="pocket",
        BagContainer="bag-container",SafeBoxContainer="safe-container",
    },
}
local list_reads=0
local repeated=setmetatable({switch=true,checkSubType="repeat"},{__index=function(_,key)
    if key=="matchModeIDList" then list_reads=list_reads+1; return {7} end
end})
check_by_type={
    missing=nil,
    ["switch-off"]={switch=false,matchModeIDList={7}},
    ["no-list"]={switch=true},
    ["not-contained"]={switch=true,matchModeIDList={99}},
    ["supply-true"]={switch=true,matchModeIDList={7},checkSubType="yes"},
    ["supply-false"]={switch=true,matchModeIDList={7},checkSubType="no",key=41,abnormalDesc="night missing"},
    repeated=repeated,
}
local item_base={
    EItemSpeicalType={
        alpha="missing",beta="switch-off",gamma="no-list",delta="not-contained",
        epsilon="supply-true",zeta="supply-false",eta="repeated",
    },
}
local supply_calls={}
local product={_CheckPlayerSuppliesForNightSpeicalType=function(subtype)
    supply_calls[#supply_calls+1]=subtype
    return subtype~="no"
end}
local function check_no_traversal(value,label)
    mode=value; queries={}; abnormals={}; supply_calls={}
    local result=table.pack(Product._CheckNightFight(product,env,item_base))
    eq(result.n,0,"P0.14 "..label.." no-return")
    eq(#queries,0,"P0.14 "..label.." skips enum")
    eq(#abnormals,0); eq(#supply_calls,0)
end
check_no_traversal(nil,"nil mode")
check_no_traversal(false,"false mode")
check_no_traversal(0,"zero mode")
check_no_traversal(-3,"negative mode")

mode=7; queries={}; abnormals={}; supply_calls={}; list_reads=0
local positive=table.pack(Product._CheckNightFight(product,env,item_base))
eq(positive.n,0,"P0.14 positive mode no-return")
eq(#queries,7,"P0.14 pairs traverses non-array enum values")
local seen={}; for _,value in ipairs(queries) do seen[value]=(seen[value] or 0)+1 end
for _,value in ipairs({"missing","switch-off","no-list","not-contained","supply-true","supply-false","repeated"}) do
    eq(seen[value],1,"P0.14 enum value traversal "..value)
end
eq(list_reads,2,"P0.14 matchModeIDList is read twice")
local supply_seen={}; for _,value in ipairs(supply_calls) do supply_seen[value]=(supply_seen[value] or 0)+1 end
eq(supply_seen.yes,1,"P0.14 contained helper true")
eq(supply_seen.no,1,"P0.14 contained helper false")
eq(supply_seen.repeat,1,"P0.14 repeated-list helper")
eq(#abnormals,1,"P0.14 helper false inserts one abnormal")
local record=abnormals[1]
eq(field_count(record),4,"P0.14 abnormal exact top-level field count")
eq(record.key,41); eq(record.abnormalType,"lack-night"); eq(record.loc,"night missing")
eq(type(record.param),"table"); eq(field_count(record.param),1,"P0.14 abnormal exact param field count")
eq(record.param.abnormalSubType,"no")

-- Constructor binding must retain source R3 identity and resolve the helper field at call time.
local context={product={},item_base_tool=item_base}
local constructed=Constructor.create(context,env)
eq(constructed,context.product,"P0.14/P0.15 constructor uses source R3 identity")
item_base.EItemSpeicalType={named="dynamic"}
check_by_type.dynamic={switch=true,matchModeIDList={7},checkSubType="dynamic"}
mode=7; abnormals={}; queries={}
local replacement_calls=0
constructed._CheckPlayerSuppliesForNightSpeicalType=function(...)
    local args=table.pack(...); eq(args.n,1,"P0.14 dynamic helper plain ABI")
    eq(args[1],"dynamic"); replacement_calls=replacement_calls+1; return true
end
constructed._CheckNightFight()
eq(replacement_calls,1,"P0.14 observes helper replacement after product construction")
eq(#abnormals,0)

-- P0.15 fixtures: product list order, missing slots/items, static helper ABI and early returns.
local helper_calls={}
local supported=setmetatable({},{__mode="k"})
item_base.CheckSupportNightBattleBySpeicalType=function(...)
    local args=table.pack(...)
    eq(args.n,2,"P0.15 helper static ABI has no self")
    eq(args[2],"night-type","P0.15 special_type passthrough")
    helper_calls[#helper_calls+1]=args[1]
    return supported[args[1]]==true
end
local lookup_log={}
local slots={}
env.Server.InventoryServer.GetSlot=function(_,slot_type,slot_group)
    eq(slot_group,"group-15","P0.15 slot group")
    lookup_log[#lookup_log+1]=slot_type
    return slots[slot_type]
end
local function equip_slot(item) return {GetEquipItem=function() return item end} end
local function container_slot(items) return {GetItems=function() return items end} end
local e1,e2,e3={name="e1"},{name="e2"},{name="e3"}
local c_bad,c_hit={name="c-bad"},{name="c-hit"}

local p15={EquipTypeList={"e1","e2"},ContainerTypeList={"c1","c2"}}
slots={e1=equip_slot(e1),e2=equip_slot(e2)}; supported=setmetatable({[e1]=true},{__mode="k"})
lookup_log={}; helper_calls={}
local first=table.pack(Product._CheckPlayerSuppliesForNightSpeicalType(p15,env,item_base,"night-type"))
eq(first.n,1); eq(first[1],true,"P0.15 first equipment hit")
eq(table.concat(lookup_log,","),"e1","P0.15 equipment hit prevents later equipment/container lookup")
eq(#helper_calls,1)

p15.EquipTypeList={"missing-e","empty-e","hit-e"}; p15.ContainerTypeList={"never-c"}
slots={ ["empty-e"]=equip_slot(nil), ["hit-e"]=equip_slot(e3) }
supported=setmetatable({[e3]=true},{__mode="k"}); lookup_log={}; helper_calls={}
local later=Product._CheckPlayerSuppliesForNightSpeicalType(p15,env,item_base,"night-type")
eq(later,true,"P0.15 later equipment hit")
eq(table.concat(lookup_log,","),"missing-e,empty-e,hit-e","P0.15 exact EquipTypeList traversal order")
eq(#helper_calls,1,"P0.15 missing slot/item skip helper")

local weird_items={nonempty=true}
local real_ipairs=ipairs
env.ipairs=function(value)
    if value==weird_items then
        local index=0
        return function()
            index=index+1
            if index==1 then return 1,false end
            if index==2 then return 2,nil end
            if index==3 then return 3,c_bad end
            if index==4 then return 4,c_hit end
            return nil
        end,value,nil
    end
    return real_ipairs(value)
end
p15.EquipTypeList={"equip-fail"}
p15.ContainerTypeList={"missing-c","nil-c","empty-c","items-c","late-c"}
local equip_fail={name="equip-fail"}
slots={
    ["equip-fail"]=equip_slot(equip_fail),
    ["nil-c"]=container_slot(nil),
    ["empty-c"]=container_slot({}),
    ["items-c"]=container_slot(weird_items),
    ["late-c"]=container_slot({{name="late"}}),
}
supported=setmetatable({[c_hit]=true},{__mode="k"}); lookup_log={}; helper_calls={}
local container_hit=table.pack(Product._CheckPlayerSuppliesForNightSpeicalType(p15,env,item_base,"night-type"))
eq(container_hit.n,1); eq(container_hit[1],true,"P0.15 container supported item")
eq(table.concat(lookup_log,","),"equip-fail,missing-c,nil-c,empty-c,items-c",
    "P0.15 exact ContainerTypeList order and first-hit early return")
eq(#helper_calls,3,"P0.15 helper sees equip fail plus two truthy container items only")
eq(helper_calls[1],equip_fail); eq(helper_calls[2],c_bad); eq(helper_calls[3],c_hit)

env.ipairs=ipairs
local u1,u2={name="u1"},{name="u2"}
p15.EquipTypeList={"missing-e"}; p15.ContainerTypeList={"only-c"}
slots={["only-c"]=container_slot({u1,u2})}; supported=setmetatable({},{__mode="k"})
lookup_log={}; helper_calls={}
local miss=table.pack(Product._CheckPlayerSuppliesForNightSpeicalType(p15,env,item_base,"night-type"))
eq(miss.n,1,"P0.15 final false arity")
eq(miss[1],false,"P0.15 complete miss returns exact false")
eq(table.concat(lookup_log,","),"missing-e,only-c")
eq(#helper_calls,2,"P0.15 unsupported items scanned")

print("product-night: ok")
'''


def patch_tests():
    write("tests/product_night.lua", focused_test_text())
    bridge = "tests/product_module_bridge.lua"
    text = read(bridge)
    text = text.replace('eq(status.source_owned_root_methods,14,"P0.0..P0.13 public methods source-owned")',
        'eq(status.source_owned_root_methods,16,"P0.0..P0.15 public methods source-owned")')
    text = text.replace("All P0.0..P0.12 public methods", "All P0.0..P0.15 public methods")
    write(bridge, text)


def patch_inventory_generator():
    path = "tools/full_payload_forensics.py"
    text = read(path)
    if "for number in range(16):" not in text:
        if text.count("for number in range(14):") != 1:
            raise SystemExit("full_payload_forensics.py: range(14) target mismatch")
        text = text.replace("for number in range(14):", "for number in range(16):", 1)
    text = text.replace("P0.0..P0.13", "P0.0..P0.15")
    p13 = '        "- P0.13 uses root R11 AmmoDataManager plus R6 WeaponAssemblyTool; parent 0.13 and nested 0.13.0 map to this independent source. It preserves the four-container bullet scan and raw-prop open returns without substituting a generic inventory scan.",\n'
    if "- P0.14 uses root R8 ItemBaseTool" not in text:
        if p13 not in text:
            raise SystemExit("full_payload_forensics.py: P0.13 map bullet target missing")
        text = text.replace(p13, p13 +
            '        "- P0.14 uses root R8 ItemBaseTool plus source R3 product. It preserves pairs value traversal, two matchModeIDList reads, dynamic R3 helper lookup, and exact LackNight abnormal shape.",\n'
            '        "- P0.15 uses source R3 EquipTypeList/ContainerTypeList plus root R8 ItemBaseTool. It preserves ipairs order, plain two-argument support-helper ABI, early returns, and exact false on a complete miss.",\n', 1)
    write(path, text)


def patch_validator():
    path = "tools/validate_phase_d.py"
    text = read(path)
    old = "    assert captured('R8','P0.14','U1') and captured('R8','P0.15','U2')\n"
    new = """    assert captured('R8','P0.14','U1') and captured('R3','P0.14','U2')
    assert captured('R3','P0.15','U1') and captured('R8','P0.15','U2')
    assert prototypes['0.14']['numparams']==0 and prototypes['0.14']['instruction_count']==72 and len(prototypes['0.14']['upvalues'])==3
    assert prototypes['0.14']['upvalues'][1]=={'instack':1,'idx':8} and prototypes['0.14']['upvalues'][2]=={'instack':1,'idx':3}
    assert prototypes['0.15']['numparams']==1 and prototypes['0.15']['instruction_count']==76 and len(prototypes['0.15']['upvalues'])==3
    assert prototypes['0.15']['upvalues'][1]=={'instack':1,'idx':3} and prototypes['0.15']['upvalues'][2]=={'instack':1,'idx':8}
    assert {'0.14','0.15'} <= set(groups['source_owned'])
    assert inv['source_files']['0.14']==inv['source_files']['0.15']=='src/spectra/product_module.lua'
"""
    if old in text:
        text = text.replace(old, new, 1)
    elif "prototypes['0.14']['instruction_count']==72" not in text:
        raise SystemExit("validate_phase_d.py: P0.14/P0.15 capture target missing")
    text = text.replace("'product_module.lua':'product-module: ok','product_source_only.lua':'product-source-only: ok'",
        "'product_module.lua':'product-module: ok','product_night.lua':'product-night: ok','product_source_only.lua':'product-source-only: ok'")
    text = text.replace("'phase':'E5.3-root-get-match-bullet-num-source-only'",
        "'phase':'E5.4-root-night-fight-source-only'")
    text = text.replace("'p0_0_through_p0_13':True", "'p0_0_through_p0_15':True")
    write(path, text)


def main():
    if '    _CheckNightFight = "0.14",\n' in read("src/spectra/product_module.lua"):
        print("P0.14/P0.15 checkpoint already applied; no bootstrap mutation needed")
        return

    patch_product_module()
    patch_constructor()
    patch_bridge()
    patch_tests()
    patch_inventory_generator()
    patch_validator()

    lua = "lua5.3"
    run(lua, str(ROOT / "tests/product_night.lua"), str(ROOT))

    run("python3", "tools/root_capture_forensics.py")
    run("python3", "tools/aim_forensics.py")
    run("python3", "tools/full_payload_forensics.py")

    generated = [
        "ROOT_CAPTURE_MAP.json", "ROOT_CAPTURE_MAP.md", "AIM_PROTOTYPE_INDEX.json",
        "FULL_PAYLOAD_PROTOTYPE_INDEX.json", "FULL_PAYLOAD_RECONSTRUCTION_MAP.md",
        "RECONSTRUCTION_COVERAGE.md",
    ]
    before = {p: (ROOT / p).read_bytes() for p in generated}
    run("python3", "tools/root_capture_forensics.py")
    run("python3", "tools/aim_forensics.py")
    run("python3", "tools/full_payload_forensics.py")
    for path, data in before.items():
        if (ROOT / path).read_bytes() != data:
            raise SystemExit(f"non-deterministic generated file: {path}")

    run("python3", "tools/build_phase_d.py")
    run("python3", "tools/validate_phase_d.py")

    custom = ROOT / "spectra_wrapper_phase_d.custom.luac"
    original_custom_hash = run("sha256sum", str(custom), capture=True).split()[0]
    run("python3", "tools/build_phase_d.py")
    rebuilt_custom_hash = run("sha256sum", str(custom), capture=True).split()[0]
    if original_custom_hash != rebuilt_custom_hash:
        raise SystemExit(f"custom build not deterministic: {original_custom_hash} != {rebuilt_custom_hash}")

    intended = [
        "src/spectra/product_module.lua",
        "src/spectra/product_constructor.lua",
        "src/spectra/product_module_bridge.lua",
        "tests/product_night.lua",
        "tests/product_module_bridge.lua",
        "tools/full_payload_forensics.py",
        "tools/validate_phase_d.py",
        "FULL_PAYLOAD_PROTOTYPE_INDEX.json",
        "FULL_PAYLOAD_RECONSTRUCTION_MAP.md",
        "RECONSTRUCTION_COVERAGE.md",
        "validation_phase_d.json",
    ]
    run("git", "add", "--", *intended)
    staged = run("git", "diff", "--cached", "--name-only", capture=True).splitlines()
    missing = [p for p in intended if p not in staged and not (p == "tests/product_night.lua" and (ROOT / p).exists())]
    if missing:
        raise SystemExit("expected intended changes not staged: " + ", ".join(missing))
    run("git", "config", "user.name", "github-actions[bot]")
    run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    run("git", "commit", "-m", "reconstruct source-only P0.14 P0.15 night fight checks")
    run("git", "push", "origin", f"HEAD:{BRANCH}")
    print("checkpoint patch committed and pushed")


if __name__ == "__main__":
    main()

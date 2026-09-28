#!/usr/bin/env python3
from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    s = p.read_text(encoding="utf-8")
    count = s.count(old)
    assert count == 1, f"{path}: expected one match, got {count}: {old[:80]!r}"
    p.write_text(s.replace(old, new, 1), encoding="utf-8")


# product_module.lua: public mapping and bytecode-faithful implementations.
replace_once(
    "src/spectra/product_module.lua",
    '    _CheckPlayerSuppliesForNightSpeicalType = "0.15",\n}',
    '    _CheckPlayerSuppliesForNightSpeicalType = "0.15",\n'
    '    _CheckSafeBoxExpiredStatus = "0.16",\n'
    '    _CheckKeyChainExpiredStatus = "0.17",\n'
    '    _CheckPropExpiredStatus = "0.18",\n}',
)
replace_once(
    "src/spectra/product_module.lua",
    "-- P0.0..P0.10 are reconstructed descriptions of stripped closures.",
    "-- P0.0..P0.18 are reconstructed descriptions of stripped closures.",
)
module = Path("src/spectra/product_module.lua")
text = module.read_text(encoding="utf-8")
marker = "\nreturn M"
assert text.count(marker) == 1
insertion = r'''

-- P0.16 is a distinct root prototype. It uses the ExpiredStatus config keyed
-- by ESlotType.SafeBox, then invokes Module.Inventory with SELF semantics.
function M._CheckSafeBoxExpiredStatus(product, globals)
    globals = globals_or_default(globals)
    local field = globals.Module.ArmedForce.Field
    local check_data = field:GetEquipmentCheckData(
        globals.Module.ArmedForce.Config.EAbnormalType.ExpiredStatus,
        globals.ESlotType.SafeBox)
    if not check_data then return end
    if not check_data.switch then return end
    if not globals.Module.Inventory:CheckSafeBoxExpiredStatus() then return end

    globals.Module.ArmedForce.Field:AddEquipAbnormal({
        key = check_data.key,
        abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.ExpiredStatus,
        loc = check_data.abnormalDesc,
        param = {
            abnormalSubType = globals.ESlotType.SafeBox,
        },
    })
end

-- P0.17 intentionally remains separate from P0.16 because the payload exports
-- a distinct prototype and distinct Inventory method for the key-chain status.
function M._CheckKeyChainExpiredStatus(product, globals)
    globals = globals_or_default(globals)
    local field = globals.Module.ArmedForce.Field
    local check_data = field:GetEquipmentCheckData(
        globals.Module.ArmedForce.Config.EAbnormalType.ExpiredStatus,
        globals.ESlotType.KeyChain)
    if not check_data then return end
    if not check_data.switch then return end
    if not globals.Module.Inventory:CheckKeyChainExpiredStatus() then return end

    globals.Module.ArmedForce.Field:AddEquipAbnormal({
        key = check_data.key,
        abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.ExpiredStatus,
        loc = check_data.abnormalDesc,
        param = {
            abnormalSubType = globals.ESlotType.KeyChain,
        },
    })
end

-- P0.18 captures source R3 and root R9 ArmedForceExpiredLogic. CheckExpired is
-- a plain/static call. An equipment hit skips the container phase entirely.
-- In the container phase the bytecode exits the current item loop on a hit,
-- then resumes the outer container TFORCALL (instruction 85), so later
-- containers are still visited before the final single abnormal is emitted.
function M._CheckPropExpiredStatus(product, globals, armed_force_expired_logic)
    globals = globals_or_default(globals)
    local field = globals.Module.ArmedForce.Field
    local check_data = field:GetEquipmentCheckData(
        globals.Module.ArmedForce.Config.EAbnormalType.ExpiredProp, 0)
    if not check_data then return end
    if not check_data.switch then return end

    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()
    local expired = false

    for _, slot_type in globals.ipairs(product.EquipTypeList) do
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        if slot then
            local item = slot:GetEquipItem()
            if armed_force_expired_logic.CheckExpired(item) then
                expired = true
                break
            end
        end
    end

    if not expired then
        for _, slot_type in globals.ipairs(product.ContainerTypeList) do
            local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
            if slot then
                local items = slot:GetItems()
                if items and not globals.table.isempty(items) then
                    for _, item in globals.ipairs(items) do
                        if armed_force_expired_logic.CheckExpired(item) then
                            expired = true
                            break
                        end
                    end
                end
            end
        end
    end

    if expired then
        globals.Module.ArmedForce.Field:AddEquipAbnormal({
            key = check_data.key,
            abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.ExpiredProp,
            loc = check_data.abnormalDesc,
        })
    end
end
'''
module.write_text(text.replace(marker, insertion + marker, 1), encoding="utf-8")

# Constructor: use same source R3 and context R9, no second require.
replace_once(
    "src/spectra/product_constructor.lua",
    '    if mode == "weapon_count" then\n',
    '    if mode == "expired_prop" then\n'
    '        return function()\n'
    '            return source(product, globals, dependencies.armed_force_expired_logic)\n'
    '        end\n'
    '    end\n'
    '    if mode == "weapon_count" then\n',
)
replace_once(
    "src/spectra/product_constructor.lua",
    "Source-only constructor for the reconstructed P0.0..P0.15 boundary.",
    "Source-only constructor for the reconstructed P0.0..P0.18 boundary.",
)
replace_once(
    "src/spectra/product_constructor.lua",
    '    product._CheckPlayerSuppliesForNightSpeicalType = bind(product, globals,\n'
    '        Product._CheckPlayerSuppliesForNightSpeicalType, p14_p15, "night_one_arg_item_base")\n\n'
    '    local slot = assert(globals.ESlotType, "ESlotType required")',
    '    product._CheckPlayerSuppliesForNightSpeicalType = bind(product, globals,\n'
    '        Product._CheckPlayerSuppliesForNightSpeicalType, p14_p15, "night_one_arg_item_base")\n'
    '    product._CheckSafeBoxExpiredStatus = bind(product, globals, Product._CheckSafeBoxExpiredStatus)\n'
    '    product._CheckKeyChainExpiredStatus = bind(product, globals, Product._CheckKeyChainExpiredStatus)\n'
    '    local p18 = { armed_force_expired_logic = context.armed_force_expired_logic }\n'
    '    product._CheckPropExpiredStatus = bind(product, globals,\n'
    '        Product._CheckPropExpiredStatus, p18, "expired_prop")\n\n'
    '    local slot = assert(globals.ESlotType, "ESlotType required")',
)

# Bridge: extend takeover; only P0.18 needs source R9 dependency.
replace_once(
    "src/spectra/product_module_bridge.lua",
    '    "_CheckPlayerSuppliesForNightSpeicalType",\n}',
    '    "_CheckPlayerSuppliesForNightSpeicalType",\n'
    '    "_CheckSafeBoxExpiredStatus",\n'
    '    "_CheckKeyChainExpiredStatus",\n'
    '    "_CheckPropExpiredStatus",\n}',
)
replace_once(
    "src/spectra/product_module_bridge.lua",
    '        _CheckPlayerSuppliesForNightSpeicalType = {\n'
    '            item_base_tool = context.item_base_tool,\n'
    '        },\n'
    '    }',
    '        _CheckPlayerSuppliesForNightSpeicalType = {\n'
    '            item_base_tool = context.item_base_tool,\n'
    '        },\n'
    '        _CheckPropExpiredStatus = {\n'
    '            armed_force_expired_logic = context.armed_force_expired_logic,\n'
    '        },\n'
    '    }',
)
replace_once(
    "src/spectra/product_module_bridge.lua",
    '        elseif name == "_CheckPlayerSuppliesForNightSpeicalType" then\n'
    '            result = table.pack(pcall(target, product, environment,\n'
    '                dependencies.item_base_tool, arguments[1]))\n'
    '        else',
    '        elseif name == "_CheckPlayerSuppliesForNightSpeicalType" then\n'
    '            result = table.pack(pcall(target, product, environment,\n'
    '                dependencies.item_base_tool, arguments[1]))\n'
    '        elseif name == "_CheckPropExpiredStatus" then\n'
    '            result = table.pack(pcall(target, product, environment,\n'
    '                dependencies.armed_force_expired_logic))\n'
    '        else',
)
replace_once(
    "src/spectra/product_module_bridge.lua",
    '        _CheckPlayerSuppliesForNightSpeicalType = Source._CheckPlayerSuppliesForNightSpeicalType,\n'
    '    }',
    '        _CheckPlayerSuppliesForNightSpeicalType = Source._CheckPlayerSuppliesForNightSpeicalType,\n'
    '        _CheckSafeBoxExpiredStatus = Source._CheckSafeBoxExpiredStatus,\n'
    '        _CheckKeyChainExpiredStatus = Source._CheckKeyChainExpiredStatus,\n'
    '        _CheckPropExpiredStatus = Source._CheckPropExpiredStatus,\n'
    '    }',
)

# Ownership generator stays derived; only extend authoritative prototype mappings/text.
replace_once(
    "tools/full_payload_forensics.py",
    "# P0.0..P0.15 no longer depend on payload closure captures.",
    "# P0.0..P0.18 no longer depend on payload closure captures.",
)
replace_once("tools/full_payload_forensics.py", "    for number in range(16):\n", "    for number in range(19):\n")
replace_once(
    "tools/full_payload_forensics.py",
    '        "", "## P0.0..P0.15 source-only preparation", "",',
    '        "", "## P0.0..P0.18 source-only preparation", "",',
)
replace_once(
    "tools/full_payload_forensics.py",
    '        "- All sixteen public methods P0.0..P0.15 receive source-owned captures and helpers; none use `debug.getupvalue`.",',
    '        "- All nineteen public methods P0.0..P0.18 receive source-owned captures and helpers; none use `debug.getupvalue`.",',
)
replace_once(
    "tools/full_payload_forensics.py",
    '        "- P0.15 uses source R3 EquipTypeList/ContainerTypeList plus root R8 ItemBaseTool. It preserves ipairs order, plain two-argument support-helper ABI, early returns, and exact false on a complete miss.",\n'
    '        "- `ProductModule.create(context, globals)` creates/binds P0.0..P0.15 on the same source R3 product table and emits exact `EquipTypeList` / `ContainerTypeList` order.",\n'
    '        "- The transitional payload overlay remains restorable; P0.0..P0.15 neither inspect nor call payload closures and do not extract payload upvalues.",',
    '        "- P0.15 uses source R3 EquipTypeList/ContainerTypeList plus root R8 ItemBaseTool. It preserves ipairs order, plain two-argument support-helper ABI, early returns, and exact false on a complete miss.",\n'
    '        "- P0.16/P0.17 preserve distinct ExpiredStatus gates, Inventory SELF calls, slot subtypes and four-field abnormal records.",\n'
    '        "- P0.18 uses source R3 traversal lists plus root R9 ArmedForceExpiredLogic with a plain one-argument CheckExpired ABI and exact three-field ExpiredProp record.",\n'
    '        "- `ProductModule.create(context, globals)` creates/binds P0.0..P0.18 on the same source R3 product table and emits exact `EquipTypeList` / `ContainerTypeList` order.",\n'
    '        "- The transitional payload overlay remains restorable; P0.0..P0.18 neither inspect nor call payload closures and do not extract payload upvalues.",',
)
replace_once(
    "tools/full_payload_forensics.py",
    "P0.0..P0.15 are source-owned with `source_only_dependency=true`; their root captures/helpers are recreated from source without loading the embedded payload. Remaining root methods P0.16..P0.28 stay payload-owned until their bounded reconstruction checkpoints complete.",
    "P0.0..P0.18 are source-owned with `source_only_dependency=true`; their root captures/helpers are recreated from source without loading the embedded payload. Remaining root methods P0.19..P0.28 stay payload-owned until their bounded reconstruction checkpoints complete.",
)

# Existing source-only and bridge tests recognize the extended boundary.
replace_once(
    "tests/product_module_bridge.lua",
    "-- All P0.0..P0.15 public methods install from one source context.",
    "-- All P0.0..P0.18 public methods install from one source context.",
)
replace_once(
    "tests/product_module_bridge.lua",
    '    eq(status.source_owned_root_methods,16,"P0.0..P0.15 public methods source-owned")',
    '    eq(status.source_owned_root_methods,19,"P0.0..P0.18 public methods source-owned")',
)
replace_once(
    "tests/product_source_only.lua",
    '    "DynamicGuidPriceFinishFetch","CheckRaidBulletEnough","GetMatchBulletNumByWeaponItem",\n}',
    '    "DynamicGuidPriceFinishFetch","CheckRaidBulletEnough","GetMatchBulletNumByWeaponItem",\n'
    '    "_CheckNightFight","_CheckPlayerSuppliesForNightSpeicalType",\n'
    '    "_CheckSafeBoxExpiredStatus","_CheckKeyChainExpiredStatus","_CheckPropExpiredStatus",\n}',
)

# Validation derives aggregate counts and pins structural/capture evidence.
replace_once("tools/validate_phase_d.py", "    assert root_source_owned>=14\n", "    assert root_source_owned>=19\n")
replace_once(
    "tools/validate_phase_d.py",
    "    assert inv['source_files']['0.14']==inv['source_files']['0.15']=='src/spectra/product_module.lua'\n",
    "    assert inv['source_files']['0.14']==inv['source_files']['0.15']=='src/spectra/product_module.lua'\n"
    "    assert captured('R3','P0.18','U1') and captured('R9','P0.18','U2')\n"
    "    assert prototypes['0.16']['numparams']==0 and prototypes['0.16']['instruction_count']==48 and len(prototypes['0.16']['upvalues'])==1\n"
    "    assert prototypes['0.17']['numparams']==0 and prototypes['0.17']['instruction_count']==48 and len(prototypes['0.17']['upvalues'])==1\n"
    "    assert prototypes['0.18']['numparams']==0 and prototypes['0.18']['instruction_count']==106 and len(prototypes['0.18']['upvalues'])==3\n"
    "    assert prototypes['0.18']['upvalues'][0]=={'instack':0,'idx':0}\n"
    "    assert prototypes['0.18']['upvalues'][1]=={'instack':1,'idx':3}\n"
    "    assert prototypes['0.18']['upvalues'][2]=={'instack':1,'idx':9}\n"
    "    assert {'0.16','0.17','0.18'} <= set(groups['source_owned'])\n"
    "    assert all(inv['source_files'][p]=='src/spectra/product_module.lua' for p in ('0.16','0.17','0.18'))\n"
    "    assert roots['_CheckSafeBoxExpiredStatus']['source_only_dependency'] is True\n"
    "    assert roots['_CheckKeyChainExpiredStatus']['source_only_dependency'] is True\n"
    "    assert roots['_CheckPropExpiredStatus']['source_only_dependency'] is True\n"
    "    assert roots['CheckPlayerBodyItemsByList']['current_ownership']=='payload_owned'\n",
)
replace_once(
    "tools/validate_phase_d.py",
    "      'product_module.lua':'product-module: ok','product_night.lua':'product-night: ok','product_source_only.lua':'product-source-only: ok','product_module_bridge.lua':'product-module-bridge: ok',",
    "      'product_module.lua':'product-module: ok','product_night.lua':'product-night: ok','product_expiration.lua':'product-expiration: ok','product_source_only.lua':'product-source-only: ok','product_module_bridge.lua':'product-module-bridge: ok',",
)
replace_once(
    "tools/validate_phase_d.py",
    "      'phase':'E5.4-root-night-fight-source-only',",
    "      'phase':'E5.5-root-expiration-source-only',",
)
replace_once("tools/validate_phase_d.py", "'p0_0_through_p0_15':True", "'p0_0_through_p0_18':True")

expiration_test = r'''local root=assert(arg[1])
local S={}
assert(loadfile(root.."/src/spectra/product_context.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module.lua"))(S)
assert(loadfile(root.."/src/spectra/product_constructor.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module_bridge.lua"))(S)
local Product=S.ProductModule
local Constructor=S.ProductConstructor
local Bridge=S.ProductModuleBridge
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function count_fields(t) local n=0 for _ in pairs(t) do n=n+1 end return n end

-- P0.16/P0.17 remain distinct and preserve Field/Inventory SELF ABI.
do
    local check_data,engine_result
    local calls,abnormals={},{}
    local field={}
    function field:GetEquipmentCheckData(kind,subtype)
        eq(self,field,"expiration Field receiver")
        eq(kind,"expired-status","expiration abnormal type")
        calls[#calls+1]="check:"..tostring(subtype)
        return check_data
    end
    function field:AddEquipAbnormal(record)
        eq(self,field,"expiration AddEquipAbnormal receiver")
        calls[#calls+1]="add"
        abnormals[#abnormals+1]=record
    end
    local inventory={}
    function inventory:CheckSafeBoxExpiredStatus()
        eq(self,inventory,"P0.16 Inventory receiver")
        calls[#calls+1]="safe-engine"
        return engine_result
    end
    function inventory:CheckKeyChainExpiredStatus()
        eq(self,inventory,"P0.17 Inventory receiver")
        calls[#calls+1]="key-engine"
        return engine_result
    end
    local env={
        Module={ArmedForce={Field=field,Config={EAbnormalType={ExpiredStatus="expired-status"}}},Inventory=inventory},
        ESlotType={SafeBox="safe-box",KeyChain="key-chain"},
    }
    local function run(method_name,subtype,engine_label,data,result,expected_calls,expect_abnormal)
        calls={}; abnormals={}; check_data=data; engine_result=result
        local packed=table.pack(Product[method_name]({},env))
        eq(packed.n,0,method_name.." has no explicit return")
        eq(table.concat(calls,","),expected_calls,method_name.." exact call order")
        eq(#abnormals,expect_abnormal and 1 or 0,method_name.." abnormal count")
        if expect_abnormal then
            local record=abnormals[1]
            eq(count_fields(record),4,method_name.." exact record fields")
            eq(record.key,71); eq(record.abnormalType,"expired-status"); eq(record.loc,"expired status")
            eq(count_fields(record.param),1,method_name.." exact param fields")
            eq(record.param.abnormalSubType,subtype,method_name.." subtype")
        end
    end
    for _,case in ipairs({
        {"_CheckSafeBoxExpiredStatus","safe-box","safe-engine"},
        {"_CheckKeyChainExpiredStatus","key-chain","key-engine"},
    }) do
        local name,subtype,engine_label=case[1],case[2],case[3]
        run(name,subtype,engine_label,nil,true,"check:"..subtype,false)
        run(name,subtype,engine_label,{switch=false},true,"check:"..subtype,false)
        run(name,subtype,engine_label,{switch=true,key=71,abnormalDesc="expired status"},false,
            "check:"..subtype..","..engine_label,false)
        run(name,subtype,engine_label,{switch=true,key=71,abnormalDesc="expired status"},true,
            "check:"..subtype..","..engine_label..",add",true)
    end
    truth(Product._CheckSafeBoxExpiredStatus~=Product._CheckKeyChainExpiredStatus,
        "P0.16/P0.17 remain distinct source functions")
end

-- P0.18 gate, traversal order, static ABI, bytecode break targets and exact record shape.
do
    local prop_check_data
    local calls,abnormals,helper_calls={},{},{}
    local NIL={}
    local field={}
    function field:GetEquipmentCheckData(kind,subtype)
        eq(self,field,"P0.18 Field receiver")
        eq(kind,"expired-prop"); eq(subtype,0)
        calls[#calls+1]="check"
        return prop_check_data
    end
    function field:AddEquipAbnormal(record)
        eq(self,field,"P0.18 AddEquipAbnormal receiver")
        calls[#calls+1]="add"
        abnormals[#abnormals+1]=record
    end
    local slots={}
    local inventory={}
    inventory.GetSlot=function(self,slot_type,group)
        eq(self,inventory,"P0.18 InventoryServer receiver")
        eq(group,"group-18")
        calls[#calls+1]="slot:"..slot_type
        return slots[slot_type]
    end
    local armed={GetCurSlotGroupId=function(self)
        calls[#calls+1]="group"
        return "group-18"
    end}
    local expired_items=setmetatable({},{__mode="k"})
    local expired_logic={CheckExpired=function(...)
        local args=table.pack(...)
        eq(args.n,1,"P0.18 CheckExpired plain/static ABI")
        helper_calls[#helper_calls+1]=args[1]==nil and NIL or args[1]
        calls[#calls+1]="expired"
        return expired_items[args[1]]==true
    end}
    local env={
        Module={ArmedForce={Field=field,Config={EAbnormalType={ExpiredProp="expired-prop"}}}},
        Server={ArmedForceServer=armed,InventoryServer=inventory},
        table={isempty=function(items) calls[#calls+1]="isempty"; return next(items)==nil end},
        ipairs=ipairs,
        ESlotType={
            MainWeaponLeft="left",MainWeaponRight="right",Pistrol="pistol",BreastPlate="breast",
            Helmet="helmet",ChestHanging="chest",Bag="bag",ChestHangingContainer="chest-container",
            Pocket="pocket",BagContainer="bag-container",SafeBoxContainer="safe-container",
            SafeBox="safe-box",KeyChain="key-chain",
        },
    }
    local product={EquipTypeList={},ContainerTypeList={}}
    local function equip(item) return {GetEquipItem=function(self) calls[#calls+1]="equip"; return item end} end
    local function container(items) return {GetItems=function(self) calls[#calls+1]="items"; return items end} end
    local function reset(data)
        prop_check_data=data; calls={}; abnormals={}; helper_calls={}; slots={}; expired_items=setmetatable({},{__mode="k"})
    end

    reset(nil)
    local missing=table.pack(Product._CheckPropExpiredStatus(product,env,expired_logic))
    eq(missing.n,0); eq(table.concat(calls,","),"check","P0.18 missing config gate")
    reset({switch=false})
    Product._CheckPropExpiredStatus(product,env,expired_logic)
    eq(table.concat(calls,","),"check","P0.18 switch false gate")

    local first_item={name="first"}; reset({switch=true,key=81,abnormalDesc="expired prop"})
    product.EquipTypeList={"e1","e2"}; product.ContainerTypeList={"c1"}
    slots.e1=equip(first_item); slots.e2=equip({name="later"}); expired_items[first_item]=true
    Product._CheckPropExpiredStatus(product,env,expired_logic)
    eq(table.concat(calls,","),"check,group,slot:e1,equip,expired,add",
        "P0.18 first equipment hit skips later equipment and containers")
    eq(#abnormals,1)

    local late_item={name="late"}; reset({switch=true,key=82,abnormalDesc="expired prop"})
    product.EquipTypeList={"missing-e","empty-e","late-e"}; product.ContainerTypeList={"never-c"}
    slots["empty-e"]=equip(nil); slots["late-e"]=equip(late_item); expired_items[late_item]=true
    Product._CheckPropExpiredStatus(product,env,expired_logic)
    eq(table.concat(calls,","),"check,group,slot:missing-e,slot:empty-e,equip,expired,slot:late-e,equip,expired,add",
        "P0.18 later equipment hit order")
    eq(#helper_calls,2,"P0.18 existing slot with nil equipment still calls CheckExpired(nil)")
    eq(helper_calls[1],NIL,"P0.18 nil equipment forwarded to static helper")

    local equip_ok={name="equip-ok"}; local bad={name="bad"}; local hit={name="hit"}; local same_later={name="same-later"}; local after={name="after"}
    reset({switch=true,key=83,abnormalDesc="expired prop"})
    product.EquipTypeList={"equip-ok"}
    product.ContainerTypeList={"missing-c","nil-c","empty-c","hit-c","after-c"}
    slots["equip-ok"]=equip(equip_ok)
    slots["nil-c"]=container(nil)
    slots["empty-c"]=container({})
    slots["hit-c"]=container({bad,hit,same_later})
    slots["after-c"]=container({after})
    expired_items[hit]=true
    Product._CheckPropExpiredStatus(product,env,expired_logic)
    eq(table.concat(calls,","),
        "check,group,slot:equip-ok,equip,expired,slot:missing-c,slot:nil-c,items,slot:empty-c,items,isempty,slot:hit-c,items,isempty,expired,expired,slot:after-c,items,isempty,expired,add",
        "P0.18 container order follows bytecode break targets")
    eq(#helper_calls,4,"P0.18 stops current item loop but resumes outer container iterator")
    eq(helper_calls[1],equip_ok); eq(helper_calls[2],bad); eq(helper_calls[3],hit); eq(helper_calls[4],after)
    for _,item in ipairs(helper_calls) do truth(item~=same_later,"P0.18 later item in hit container must not be scanned") end
    eq(#abnormals,1,"P0.18 emits one final abnormal")
    local record=abnormals[1]
    eq(count_fields(record),3,"P0.18 exact top-level record field count")
    eq(record.key,83); eq(record.abnormalType,"expired-prop"); eq(record.loc,"expired prop")
    eq(record.param,nil,"P0.18 record has no invented param")

    local u1,u2={name="u1"},{name="u2"}; reset({switch=true,key=84,abnormalDesc="none"})
    product.EquipTypeList={"missing-e"}; product.ContainerTypeList={"only-c"}
    slots["only-c"]=container({u1,u2})
    Product._CheckPropExpiredStatus(product,env,expired_logic)
    eq(table.concat(calls,","),"check,group,slot:missing-e,slot:only-c,items,isempty,expired,expired",
        "P0.18 none-expired full traversal")
    eq(#abnormals,0,"P0.18 no abnormal when nothing expired")

    -- Constructor uses exact context R9 dependency and source R3 identity.
    local context={product={},armed_force_expired_logic=expired_logic,item_base_tool={}}
    local constructed=Constructor.create(context,env)
    eq(constructed,context.product,"P0.18 constructor keeps source R3 identity")
    truth(type(constructed._CheckSafeBoxExpiredStatus)=="function"); truth(type(constructed._CheckKeyChainExpiredStatus)=="function")
    truth(type(constructed._CheckPropExpiredStatus)=="function")
    local constructed_item={name="constructed"}; reset({switch=true,key=85,abnormalDesc="constructed"})
    constructed.EquipTypeList={"constructed-e"}; constructed.ContainerTypeList={}
    slots["constructed-e"]=equip(constructed_item); expired_items[constructed_item]=true
    constructed._CheckPropExpiredStatus()
    eq(helper_calls[1],constructed_item,"P0.18 constructor forwards context R9 helper")

    -- Bridge takeover includes all three roots and never invokes saved payload methods.
    Bridge.restore_original()
    local payload_calls={}
    local target={EquipTypeList={"bridge-e"},ContainerTypeList={}}
    for _,name in ipairs(Bridge.METHODS) do
        target[name]=function(...) payload_calls[#payload_calls+1]={name,table.pack(...)} end
    end
    local bridge_item={name="bridge"}; reset({switch=true,key=86,abnormalDesc="bridge"})
    slots["bridge-e"]=equip(bridge_item); expired_items[bridge_item]=true
    local noop=function() end
    local ctx={globals=env,product={},debug_logger=noop,info_logger=noop,error_logger=noop,
        item_helper={GetSubTypeById=function(v) return v end},item_config_tool={},weapon_assembly_tool={},
        weapon_helper_tool={},item_base_tool={},armed_force_expired_logic=expired_logic,
        ammo_data_manager_module={},ammo_data_manager={}}
    truth(Bridge.install(target,{context=ctx,environment=env}),"P0.16-P0.18 bridge install")
    eq(Bridge.status().source_owned_root_methods,19,"bridge owns P0.0..P0.18")
    local bridge_result=table.pack(target._CheckPropExpiredStatus())
    eq(bridge_result.n,0,"P0.18 bridge no-return ABI")
    eq(#payload_calls,0,"P0.18 bridge does not call original payload method")
    eq(helper_calls[1],bridge_item,"P0.18 bridge uses context R9 dependency")
    Bridge.restore_original()
end

print("product-expiration: ok")
'''
Path("tests/product_expiration.lua").write_text(expiration_test, encoding="utf-8")
print("expiration checkpoint patch applied")

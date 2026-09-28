local root=assert(arg[1])
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
eq(supply_seen["repeat"],1,"P0.14 repeated-list helper")
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

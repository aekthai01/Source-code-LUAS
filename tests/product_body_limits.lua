local root=assert(arg[1])
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
local function contains(list,value) for _,v in ipairs(list) do if v==value then return true end end return false end

-- Exact root exports remain distinct.
eq(Product.PROTOTYPES.CheckPlayerBodyItemsByList,"0.19")
eq(Product.PROTOTYPES.CheckNightVisionLimitByList,"0.20")
eq(Product.PROTOTYPES.CheckThermalImagingLimitByList,"0.21")
eq(Product.PROTOTYPES.CheckPlayerBodyItemsEntryQuality,"0.22")
eq(Product.PROTOTYPES.CheckRentalConsumableID,"0.23")
truth(Product.CheckNightVisionLimitByList~=Product.CheckThermalImagingLimitByList,
    "P0.20/P0.21 remain distinct source functions")

-- P0.19/P0.19.0: nil contract, scan order, one-result raw prop, static ABI,
-- receiver expansion, direct matches, dedupe, table.keys result and two returns.
do
    local logs,slot_calls,is_in_list_calls,assembly_calls,keys_calls={},{},{},{},0
    local main_types={
        direct="equipment", duplicate="equipment", other="other",
        recv="receiver", recv_empty="receiver", recv_nil_raw="receiver",
    }
    local item_helper={GetMainTypeById=function(...)
        local a=table.pack(...); eq(a.n,1,"P0.19 GetMainTypeById static ABI")
        return main_types[a[1]]
    end}
    local assembly={GetItemIDsByPropInfo=function(...)
        local a=table.pack(...); eq(a.n,4,"P0.19 GetItemIDsByPropInfo static ABI")
        eq(a[2],false); eq(a[3],false); eq(a[4],true)
        assembly_calls[#assembly_calls+1]=a[1]
        if a[1]=="raw-first" then return {"expanded","expanded","other-id"} end
        if a[1]=="empty-raw" then return {} end
        error("unexpected raw prop "..tostring(a[1]))
    end}
    local table_helpers={
        isempty=function(value) return value==nil or next(value)==nil end,
        isInList=function(value,list)
            is_in_list_calls[#is_in_list_calls+1]={value,list}
            return contains(list,value)
        end,
        keys=function(map)
            keys_calls=keys_calls+1
            local out={}; for key in pairs(map) do out[#out+1]=key end
            return out
        end,
    }
    local slots={}
    local inventory
    inventory={GetSlot=function(self,slot_type,group)
        eq(self,inventory,"P0.19 InventoryServer receiver"); eq(group,"body-group")
        slot_calls[#slot_calls+1]=slot_type
        return slots[slot_type]
    end}
    local armed
    armed={GetCurSlotGroupId=function(self) eq(self,armed); return "body-group" end}
    local env={
        Server={ArmedForceServer=armed,InventoryServer=inventory},
        EItemType={Receiver="receiver"}, table=table_helpers, ipairs=ipairs,
    }
    local deps={
        error_logger=function(...) logs[#logs+1]=table.pack(...) end,
        item_helper=item_helper, weapon_assembly_tool=assembly,
    }
    local product={EquipTypeList={},ContainerTypeList={}}

    local missing=table.pack(Product.CheckPlayerBodyItemsByList(product,env,deps,nil))
    eq(missing.n,2,"P0.19 nil return arity"); eq(missing[1],false)
    eq(type(missing[2]),"table"); eq(next(missing[2]),nil)
    eq(#logs,1); eq(logs[1].n,1)
    eq(logs[1][1],"CheckEquipLogic.CheckNightVisionLimitByList checkList is nil!!!")
    eq(#slot_calls,0,"P0.19 nil input returns before slot group scan")

    local direct={id="direct"}
    local duplicate={id="direct"}
    local receiver
    receiver={id="recv",GetRawPropInfo=function(self)
        eq(self,receiver,"P0.19 receiver raw-prop SELF")
        return "raw-first","ignored-second","ignored-third"
    end}
    local receiver_empty
    receiver_empty={id="recv_empty",GetRawPropInfo=function(self)
        eq(self,receiver_empty); return "empty-raw","ignored"
    end}
    local receiver_nil_raw
    receiver_nil_raw={id="recv_nil_raw",GetRawPropInfo=function(self)
        eq(self,receiver_nil_raw); return nil,"must-not-forward"
    end}
    product.EquipTypeList={"e-missing","e-empty","e-direct","e-receiver-empty"}
    product.ContainerTypeList={"c-missing","c-nil-items","c-empty","c-items","c-after"}
    slots["e-empty"]={GetEquipItem=function() return nil end}
    slots["e-direct"]={GetEquipItem=function() return direct end}
    slots["e-receiver-empty"]={GetEquipItem=function() return receiver_empty end}
    slots["c-nil-items"]={GetItems=function() return nil end}
    slots["c-empty"]={GetItems=function() return {} end}
    slots["c-items"]={GetItems=function() return {false,receiver,duplicate,receiver_nil_raw} end}
    slots["c-after"]={GetItems=function() return {{id="other"}} end}
    slot_calls={}; assembly_calls={}; is_in_list_calls={}; keys_calls=0
    local found=table.pack(Product.CheckPlayerBodyItemsByList(product,env,deps,{"direct","expanded"}))
    eq(found.n,2,"P0.19 success return arity"); eq(found[1],true)
    eq(keys_calls,1,"P0.19 must use engine table.keys")
    eq(#found[2],2,"P0.19 result keys are unique")
    truth(contains(found[2],"direct")); truth(contains(found[2],"expanded"))
    eq(table.concat(slot_calls,","),
        "e-missing,e-empty,e-direct,e-receiver-empty,c-missing,c-nil-items,c-empty,c-items,c-after",
        "P0.19 exact equipment then container traversal order")
    eq(table.concat(assembly_calls,","),"empty-raw,raw-first",
        "P0.19 raw-prop nil skips expansion and first raw result is used")
    truth(#is_in_list_calls>=4,"P0.19 direct and expanded IDs checked")
    eq(is_in_list_calls[1][2][1],"direct","P0.19 list is second isInList argument")

    local none_product={EquipTypeList={"only"},ContainerTypeList={}}
    slots.only={GetEquipItem=function() return {id="other"} end}
    slot_calls={}; keys_calls=0
    local none=table.pack(Product.CheckPlayerBodyItemsByList(none_product,env,deps,{"absent"}))
    eq(none.n,2); eq(none[1],false); eq(type(none[2]),"table"); eq(next(none[2]),nil)
end

-- P0.20/P0.21 must dynamically re-read source R3 and tail-forward all returns.
do
    local env={ESlotType={
        MainWeaponLeft="left",MainWeaponRight="right",Pistrol="pistol",BreastPlate="breast",
        Helmet="helmet",ChestHanging="chest",Bag="bag",ChestHangingContainer="chest-c",
        Pocket="pocket",BagContainer="bag-c",SafeBoxContainer="safe-c",
    }}
    local context={product={}}
    local product=Constructor.create(context,env)
    local calls={}
    product.CheckPlayerBodyItemsByList=function(...)
        local a=table.pack(...); eq(a.n,1,"P0.20/P0.21 replacement receives one argument")
        calls[#calls+1]=a[1]
        return true,{"x"},"sentinel"
    end
    local night=table.pack(product.CheckNightVisionLimitByList("night-list"))
    eq(night.n,3); eq(night[1],true); eq(night[2][1],"x"); eq(night[3],"sentinel")
    local thermal=table.pack(product.CheckThermalImagingLimitByList("thermal-list"))
    eq(thermal.n,3); eq(thermal[1],true); eq(thermal[2][1],"x"); eq(thermal[3],"sentinel")
    eq(table.concat(calls,","),"night-list,thermal-list","P0.20/P0.21 dynamic R3 lookup")
end

-- P0.22/P0.22.0/P0.22.1/P0.22.2: setdefault semantics, strict max/min,
-- all three categories, receiver bullets, filtering, traversal and final logger.
do
    local slot_calls,main_calls,sub_calls,quality_calls,weapon_calls,default_calls,logs={},{},{},{},{},{},{}
    local main_types={
        h2="equipment",h5="equipment",br4="equipment",br1="equipment",
        b3="bullet",b6="bullet",b7="bullet",not_bullet="equipment",
        recv="receiver",recv_nil="receiver",recv_empty="receiver",
    }
    local sub_types={h2="helmet-type",h5="helmet-type",br4="breast-type",br1="breast-type"}
    local qualities={h2=2,h5=5,br4=4,br1=1,b3=3,b6=6,b7=7,
        recv=90,recv_nil=91,recv_empty=92,not_bullet=99}
    local item_helper={
        GetMainTypeById=function(...)
            local a=table.pack(...); eq(a.n,1,"P0.22 GetMainTypeById static ABI")
            main_calls[#main_calls+1]=a[1]; return main_types[a[1]]
        end,
        GetSubTypeById=function(...)
            local a=table.pack(...); eq(a.n,1,"P0.22 GetSubTypeById static ABI")
            sub_calls[#sub_calls+1]=a[1]; return sub_types[a[1]]
        end,
    }
    local item_config={GetItemQuality=function(...)
        local a=table.pack(...); eq(a.n,1,"P0.22 GetItemQuality static ABI")
        quality_calls[#quality_calls+1]=a[1]; return qualities[a[1]]
    end}
    local weapon={GetWeaponBullets=function(...)
        local a=table.pack(...); eq(a.n,1,"P0.22 GetWeaponBullets static ABI")
        weapon_calls[#weapon_calls+1]=a[1]
        if a[1]=="receiver-raw" then return {{id="b7"},{id="not_bullet"}} end
        if a[1]=="nil-bullets" then return nil end
        if a[1]=="empty-bullets" then return {} end
        error("unexpected weapon raw "..tostring(a[1]))
    end}
    local slots={}
    local inventory
    inventory={GetSlot=function(self,slot_type,group)
        eq(self,inventory,"P0.22 InventoryServer receiver"); eq(group,"quality-group")
        slot_calls[#slot_calls+1]=slot_type; return slots[slot_type]
    end}
    local armed
    armed={GetCurSlotGroupId=function(self) eq(self,armed); return "quality-group" end}
    local env={
        Server={ArmedForceServer=armed,InventoryServer=inventory},
        ESlotType={Helmet="helmet-slot",BreastPlate="breast-slot",BulletLeft="bullet-slot"},
        EItemType={Receiver="receiver",Equipment="equipment",Bullet="bullet"},
        EEquipmentType={Helmet="helmet-type",BreastPlate="breast-type"},
        ipairs=ipairs,
        table={isempty=function(v) return v==nil or next(v)==nil end},
        string=string,
        setdefault=function(value,default)
            default_calls[#default_calls+1]={value=value,default=default}
            if value==nil then return default end
            return value
        end,
    }
    local deps={item_helper=item_helper,item_config_tool=item_config,
        weapon_assembly_tool=weapon,error_logger=function(...) logs[#logs+1]=table.pack(...) end}
    local function equip(item) return {GetEquipItem=function() return item end} end
    local function container(items) return {GetItems=function() return items end} end
    local receiver
    receiver={id="recv",GetRawPropInfo=function(self) eq(self,receiver); return "receiver-raw","ignored" end}
    local receiver_nil
    receiver_nil={id="recv_nil",GetRawPropInfo=function(self) eq(self,receiver_nil); return "nil-bullets","ignored" end}
    local receiver_empty
    receiver_empty={id="recv_empty",GetRawPropInfo=function(self) eq(self,receiver_empty); return "empty-bullets","ignored" end}
    local product={
        EquipTypeList={"e-h2","e-h5","e-br4","e-b3"},
        ContainerTypeList={"c-missing","c-nil","c-empty","c-items","c-after"},
    }
    slots["e-h2"]=equip({id="h2"}); slots["e-h5"]=equip({id="h5"})
    slots["e-br4"]=equip({id="br4"}); slots["e-b3"]=equip({id="b3"})
    slots["c-nil"]=container(nil); slots["c-empty"]=container({})
    slots["c-items"]=container({false,{id="br1"},receiver,receiver_nil,receiver_empty})
    slots["c-after"]=container({{id="b6"}})

    local function reset_observed()
        slot_calls={}; main_calls={}; sub_calls={}; quality_calls={}; weapon_calls={}; default_calls={}; logs={}
    end

    reset_observed()
    local max_result=table.pack(Product.CheckPlayerBodyItemsEntryQuality(product,env,deps,nil))
    eq(max_result.n,1,"P0.22 returns one value")
    local max=max_result[1]
    eq(max["helmet-slot"],5); eq(max["breast-slot"],4); eq(max["bullet-slot"],7)
    eq(#default_calls,1); eq(default_calls[1].value,nil); eq(default_calls[1].default,true)
    eq(table.concat(slot_calls,","),
        "e-h2,e-h5,e-br4,e-b3,c-missing,c-nil,c-empty,c-items,c-after",
        "P0.22 equipment then container traversal order")
    eq(table.concat(weapon_calls,","),"receiver-raw,nil-bullets,empty-bullets",
        "P0.22 receiver bullet list handling")
    truth(not contains(quality_calls,"not_bullet"),"P0.22 receiver non-bullet candidate ignored")
    eq(#logs,1); eq(logs[1].n,1)
    eq(logs[1][1],
        "CheckEquipLogic.CheckPlayerBodyItemsEntryQuality [bLimitMax = true, 头盔品质 = 5, 护甲品质 = 4, 子弹品质 = 7]",
        "P0.22 exact max logger message")

    reset_observed()
    local min_result=table.pack(Product.CheckPlayerBodyItemsEntryQuality(product,env,deps,false))
    eq(min_result.n,1)
    local min=min_result[1]
    eq(min["helmet-slot"],2); eq(min["breast-slot"],1); eq(min["bullet-slot"],3)
    eq(#default_calls,1); eq(default_calls[1].value,false,"setdefault keeps explicit false"); eq(default_calls[1].default,true)
    eq(logs[1][1],
        "CheckEquipLogic.CheckPlayerBodyItemsEntryQuality [bLimitMax = false, 头盔品质 = 2, 护甲品质 = 1, 子弹品质 = 3]",
        "P0.22 exact min logger message")

    -- No matches preserves exactly three sentinel keys.
    reset_observed()
    local empty_product={EquipTypeList={},ContainerTypeList={}}
    local empty_result=Product.CheckPlayerBodyItemsEntryQuality(empty_product,env,deps,false)
    eq(count_fields(empty_result),3,"P0.22 exact initial result key count")
    eq(empty_result["helmet-slot"],-1); eq(empty_result["breast-slot"],-1); eq(empty_result["bullet-slot"],-1)
    eq(logs[1][1],
        "CheckEquipLogic.CheckPlayerBodyItemsEntryQuality [bLimitMax = false, 头盔品质 = -1, 护甲品质 = -1, 子弹品质 = -1]",
        "P0.22 sentinel logger")

    -- Equal quality must not replace the first value: comparator is strict <.
    local lt_calls=0
    local quality_mt={
        __lt=function(a,b) lt_calls=lt_calls+1; return a.rank<b.rank end,
        __le=function() error("P0.22 comparator must not use <=") end,
    }
    local qa=setmetatable({rank=5,name="qa"},quality_mt)
    local qb=setmetatable({rank=5,name="qb"},quality_mt)
    main_types.eq_a="bullet"; main_types.eq_b="bullet"; qualities.eq_a=qa; qualities.eq_b=qb
    local equal_slots={a=equip({id="eq_a"}),b=equip({id="eq_b"})}
    local old_slots=slots; slots=equal_slots
    local old_format=env.string.format
    env.string={format=function() return "equal-quality-log" end}
    reset_observed()
    local equal_result=Product.CheckPlayerBodyItemsEntryQuality(
        {EquipTypeList={"a","b"},ContainerTypeList={}},env,deps,true)
    eq(equal_result["bullet-slot"],qa,"strict comparator keeps first equal quality")
    eq(lt_calls,1,"strict comparator invoked once for equal second value")
    eq(logs[1][1],"equal-quality-log")
    env.string={format=old_format}; slots=old_slots
end

-- P0.23 exact gates, SELF receiver, abnormal shape and no explicit returns.
do
    local check_data,consumable_id,can_apply
    local calls,abnormals={},{}
    local field={}
    function field:GetEquipmentCheckData(kind,zero)
        eq(self,field,"P0.23 Field receiver"); eq(kind,"rental-voucher"); eq(zero,0)
        calls[#calls+1]="check"; return check_data
    end
    function field:AddEquipAbnormal(record)
        eq(self,field,"P0.23 AddEquipAbnormal receiver")
        calls[#calls+1]="add"; abnormals[#abnormals+1]=record
    end
    local armed_force={Field=field,Config={EAbnormalType={RentalVoucherDoNotMeetEntryRequirements="rental-voucher"}}}
    function armed_force:CheckConsumableIDCanBeApply(value)
        eq(self,armed_force,"P0.23 ArmedForce SELF receiver"); eq(value,consumable_id)
        calls[#calls+1]="apply:"..tostring(value); return can_apply
    end
    local armed_server
    armed_server={GetCurRentalPlan_ConsumableID=function(self)
        eq(self,armed_server,"P0.23 ArmedForceServer receiver")
        calls[#calls+1]="id"; return consumable_id
    end}
    local env={Module={ArmedForce=armed_force},Server={ArmedForceServer=armed_server}}
    local function run(data,id,allowed,expected,expect_abnormal)
        check_data,consumable_id,can_apply=data,id,allowed; calls={}; abnormals={}
        local result=table.pack(Product.CheckRentalConsumableID({},env))
        eq(result.n,0,"P0.23 no explicit return")
        eq(table.concat(calls,","),expected,"P0.23 exact call order")
        eq(#abnormals,expect_abnormal and 1 or 0)
        if expect_abnormal then
            local record=abnormals[1]
            eq(count_fields(record),4,"P0.23 exact abnormal top-level fields")
            eq(record.key,230); eq(record.abnormalType,"rental-voucher"); eq(record.loc,"rental denied")
            eq(type(record.param),"table"); eq(next(record.param),nil,"P0.23 param is explicit empty table")
        end
    end
    run(nil,7,false,"check",false)
    run({switch=false},7,false,"check",false)
    run({switch=true,key=230,abnormalDesc="rental denied"},0,false,"check,id",false)
    run({switch=true,key=230,abnormalDesc="rental denied"},-2,false,"check,id",false)
    run({switch=true,key=230,abnormalDesc="rental denied"},9,true,"check,id,apply:9",false)
    run({switch=true,key=230,abnormalDesc="rental denied"},9,false,"check,id,apply:9,add",true)
end

-- Constructor/bridge expose exactly the expanded source boundary; originals are
-- never invoked merely by installing it.
do
    eq(#Bridge.METHODS,24,"bridge root method boundary P0.0..P0.23")
    local names={"CheckPlayerBodyItemsByList","CheckNightVisionLimitByList",
        "CheckThermalImagingLimitByList","CheckPlayerBodyItemsEntryQuality","CheckRentalConsumableID"}
    for _,name in ipairs(names) do truth(contains(Bridge.METHODS,name),name.." bridge export") end
end

print("product-body-limits: ok")

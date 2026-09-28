local root=assert(arg[1])
local S={}
assert(loadfile(root.."/src/spectra/product_context.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module.lua"))(S)
assert(loadfile(root.."/src/spectra/product_constructor.lua"))(S)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end

local logs={debug={},info={},error={}}
local function make_logger(kind)
    return function(...)
        logs[kind][#logs[kind]+1]=table.pack(...)
    end
end
local debug_logger,info_logger,error_logger=make_logger("debug"),make_logger("info"),make_logger("error")
local subtype_calls={}
local item_helper={GetSubTypeById=function(item_id)
    subtype_calls[#subtype_calls+1]=item_id
    return item_id
end}
local required={
    [S.ProductContext.REQUIRE_PATHS[1]]=item_helper,
    [S.ProductContext.REQUIRE_PATHS[2]]={},
    [S.ProductContext.REQUIRE_PATHS[3]]={},
    [S.ProductContext.REQUIRE_PATHS[4]]={},
    [S.ProductContext.REQUIRE_PATHS[5]]={},
    [S.ProductContext.REQUIRE_PATHS[6]]={},
}
local ammo={}
local ammo_module={Get=function() return ammo end}
local slot_names={
    MainWeaponLeft="left",MainWeaponRight="right",Pistrol="pistol",
    BreastPlate="breast",Helmet="helmet",ChestHanging="chest",Bag="bag",
    ChestHangingContainer="chest-container",Pocket="pocket",
    BagContainer="bag-container",SafeBoxContainer="safe-container",
}
local empty_slot={GetEquipItem=function() return nil end}
local changed={calls=0,Invoke=function(self,...) self.calls=self.calls+1; self.args=table.pack(...) end}
local armed_server={
    CheckIsRentalStatus=function() return true end,
    GetCurRentalPlan=function() return {consumable_id=1,type_id=2,preset_id=3,preset_price=777} end,
    GetCurSlotGroupId=function() return "group-source" end,
}
local globals={
    GenLocalLogFunc=function(category)
        eq(category,"armed-force")
        return debug_logger,info_logger,error_logger
    end,
    ELuaLogCategory={LuaMArmedForce="armed-force"},
    require=function(path) return assert(required[path],"unexpected require "..tostring(path)) end,
    import=function(name) eq(name,"AmmoDataManager"); return ammo_module end,
    ESlotType=slot_names,
    ECurrencyClientType={SOLChallengeCoin="challenge",OnlyUnBind="unbound"},
    Module={
        LobbySOLChallenge={CheckInSOLChallengeMode=function() return false end},
        ArmedForce={Config={evtAllEquipmentValueChanged=changed}},
    },
    Server={
        ArmedForceServer=armed_server,
        InventoryServer={GetSlot=function(_,slot_type,group)
            eq(group,"group-source","source slot group")
            truth(slot_type~=nil,"slot type forwarded")
            return empty_slot
        end},
        ShopServer={},
    },
    string=string,
    math=math,
    table={insert=table.insert,concat=table.concat,pack=table.pack,unpack=table.unpack,
        isempty=function(value) return next(value)==nil end},
    tostring=tostring,
    ipairs=ipairs,pairs=pairs,
    debug={getupvalue=function() error("debug.getupvalue must not be used") end},
}

local context=S.ProductContext.create(globals)
local product=S.ProductModule.create(context,globals)
eq(product,context.product,"constructor must use P0 R3 source table identity")
local sibling_context=S.ProductContext.create(globals)
local sibling_product=S.ProductConstructor.create(sibling_context,globals)
eq(sibling_product,sibling_context.product,"child constructor binds to its R3 capture")
eq(sibling_product~=product,true,"fresh source context creates independent product identity")
eq(sibling_product.GetAllEquipmentValue==product.GetAllEquipmentValue,false,"child closures bind their own product identity")
eq(sibling_product.DynamicGuidPriceFinishFetch==product.DynamicGuidPriceFinishFetch,false,"P0.11 child closures bind their own product identity")
local flow_calls=0
local flow_manager={
    CheckMainFlowSOL=function() return false end,
    GetCurrentGameFlow=function()
        flow_calls=flow_calls+1
        return flow_calls==1 and "initial" or "lobby"
    end,
}
globals.Facade={GameFlowManager=flow_manager}
globals.EGameFlowStageType={Lobby="lobby"}
local child_calls=0
product._CheckEquipmentValue=function(...) eq(select("#",...),0,"P0.11 R3 child call has no self"); child_calls=child_calls+1 end
local p011_true=table.pack(product.DynamicGuidPriceFinishFetch(true))
eq(p011_true.n,0,"P0.11 source-only zero-return contract")
eq(child_calls,1,"P0.11 true argument invokes source R3 method")
flow_calls=0
local p011_false=table.pack(product.DynamicGuidPriceFinishFetch(false))
eq(p011_false.n,0,"P0.11 false gate returns no values")
eq(child_calls,1,"P0.11 false argument suppresses child")
local p013_result=table.pack(product.GetMatchBulletNumByWeaponItem(nil,"g"))
eq(p013_result.n,1,"P0.13 constructor one-value return ABI")
eq(p013_result[1],0,"P0.13 nil item source value")
local p12_errors,p12_infos={},{}
local old_error,old_info=context.error_logger,context.info_logger
context.error_logger=function(...) p12_errors[#p12_errors+1]=table.pack(...) end
context.info_logger=function(...) p12_infos[#p12_infos+1]=table.pack(...) end
local old_item=product.CheckRaidBulletEnough
product.CheckRaidBulletEnough=S.ProductConstructor.create(context,globals).CheckRaidBulletEnough
local p12_nil=table.pack(product.CheckRaidBulletEnough(nil))
eq(p12_nil.n,0,"P0.12 nil match mode has zero returns")
eq(#p12_errors,1,"P0.12 R2 error logger used")
eq(p12_errors[1][1],"CheckEquipLogic.CheckRaidBulletEnough matchModeID is nil")
product.CheckRaidBulletEnough=old_item
context.error_logger,context.info_logger=old_error,old_info
product=S.ProductConstructor.create(context,globals)
local names={
    "CheckEquipmentBeforEnterGameProcess","_CheckProcess","_CheckEquipmentValue",
    "GetAllEquipmentValue","_CheckMedicine","_CheckUnCarryMedicine","_CheckContainer",
    "_CheckBullet","_CheckDurabulity","CheckEquipSlotEmpty","CheckEquipSlotValue",
    "DynamicGuidPriceFinishFetch","CheckRaidBulletEnough","GetMatchBulletNumByWeaponItem",
    "_CheckNightFight","_CheckPlayerSuppliesForNightSpeicalType",
    "_CheckSafeBoxExpiredStatus","_CheckKeyChainExpiredStatus","_CheckPropExpiredStatus",
}
for _,name in ipairs(names) do truth(type(product[name])=="function",name.." source export") end

local expected_equip={"left","right","pistol","breast","helmet","chest","bag"}
local expected_container={"chest-container","pocket","bag-container","safe-container"}
for i,value in ipairs(expected_equip) do eq(product.EquipTypeList[i],value,"EquipTypeList order "..i) end
for i,value in ipairs(expected_container) do eq(product.ContainerTypeList[i],value,"ContainerTypeList order "..i) end

local value,currency=product.GetAllEquipmentValue()
eq(value,777,"source-only P0.3 rental value")
eq(currency,"unbound","source-only P0.3 currency")
eq(changed.calls,1,"P0.3 event")
eq(changed.args[1],777); eq(changed.args[2],"unbound")
truth(#logs.info>=3,"P0.3 uses source R1 info logger")
eq(#logs.error,0,"P0.3 no error on valid rental plan")
local previous_info=#logs.info
local previous_error=#logs.error
local old_plan=armed_server.GetCurRentalPlan
armed_server.GetCurRentalPlan=function() return nil end
local empty_value,empty_currency=product.GetAllEquipmentValue()
eq(empty_value,0,"P0.3 nil plan return"); eq(empty_currency,"unbound")
eq(#logs.info,previous_info+2,"P0.3 R1 start and end logs")
eq(#logs.error,previous_error+1,"P0.3 uses source R2 error logger")
armed_server.GetCurRentalPlan=old_plan
local old_rental_status=armed_server.CheckIsRentalStatus
armed_server.CheckIsRentalStatus=function() return false end
local slot_lookups=0
local old_get_slot=globals.Server.InventoryServer.GetSlot
globals.Server.InventoryServer.GetSlot=function(...)
    slot_lookups=slot_lookups+1
    return old_get_slot(...)
end
local slot_value,currency_value=product.GetAllEquipmentValue()
eq(slot_value,0,"P0.3 sums source child slot values")
eq(currency_value,"unbound"); eq(slot_lookups,7,"P0.3 dispatches seven child calls through source R3")
armed_server.CheckIsRentalStatus=old_rental_status
globals.Server.InventoryServer.GetSlot=old_get_slot
local old_get_item=empty_slot.GetEquipItem
empty_slot.GetEquipItem=function() return {id="bullet-item"} end
globals.MathUtil={GetRoundingNum=function(value) return value end}
globals.Module.ArmedForce.Field={GetEquipmentCheckData=function() return {switch=true,checkValue=1} end}
globals.Module.ArmedForce.Config={EAbnormalType={LackBullet="lack-bullet"}}
local match_calls=0
product.GetMatchBulletNumByWeaponItem=function(...)
    local args=table.pack(...)
    eq(args.n,2,"P0.7 child match helper is a plain two-argument call")
    eq(args[1].id,"bullet-item")
    match_calls=match_calls+1
    return 1
end
product._CheckBullet()
eq(match_calls,3,"P0.7 dispatches left/right/pistol child calls through source R3")
truth(#logs.debug>0,"P0.7 uses source R0 debug logger")
eq(subtype_calls[#subtype_calls],"bullet-item","P0.7 uses source R4 ItemHelperTool")
empty_slot.GetEquipItem=old_get_item
local old_field=globals.Module.ArmedForce.Field
local errors_before_negative_bullet=#logs.error
empty_slot.GetEquipItem=function() return {id="negative-bullet"} end
item_helper.GetSubTypeById=function(item_id) return item_id end
globals.Module.ArmedForce.Field={GetEquipmentCheckData=function()
    return {switch=true,checkValue=-1}
end}
product._CheckBullet()
eq(#logs.error,errors_before_negative_bullet+3,"P0.7 source R2 logs each negative weapon slot")
eq(logs.error[#logs.error][1],"CheckEquipLogic._CheckBullet checkValue 小于0！！！","P0.7 R2 error message")
globals.Module.ArmedForce.Field=old_field
empty_slot.GetEquipItem=old_get_item

local empty=table.pack(product.CheckEquipSlotEmpty("helmet"))
eq(empty.n,1,"P0.9 return arity"); eq(empty[1],true,"P0.9 empty")
local info_before_price=#logs.info
eq(product.CheckEquipSlotValue("helmet"),0,"P0.10 empty slot price")
eq(#logs.info,info_before_price+1,"P0.10 uses source R1 info logger")
eq(logs.info[#logs.info][1]:find("equipName = nil, price = 0",1,true)~=nil,true,"P0.10 exact empty-price diagnostic")
product._CheckBullet()
local error_before_durability=#logs.error
globals.EFeatureType={Equipment="equipment"}
globals.Module.ArmedForce.Config.EAbnormalType.InsufficientDurability="durability"
local equipment_feature={IsHelmet=function() return true end,IsBreastPlate=function() return false end}
local equipment_item={GetFeature=function(_,feature_type) eq(feature_type,"equipment"); return equipment_feature end}
globals.Server.InventoryServer.GetSlot=function(_,slot_type,group)
    eq(group,"group-source")
    return {GetEquipItem=function() return slot_type=="helmet" and equipment_item or nil end}
end
globals.Module.ArmedForce.Field={GetEquipmentCheckData=function(_,kind)
    eq(kind,"durability")
    return {switch=true,checkValue=-1}
end}
product._CheckDurabulity()
eq(#logs.error,error_before_durability+1,"P0.8 uses source R2 error logger")
eq(logs.error[#logs.error][1],"CheckEquipLogic._CheckDurabulity checkValue 小于0！！！","P0.8 captured logger message")

local bridge_text=assert(io.open(root.."/src/spectra/product_module_bridge.lua","rb")):read("*a")
eq(bridge_text:find("debug.getupvalue",1,true),nil,"transitional bridge must not introspect payload closures")
print("product-source-only: ok")

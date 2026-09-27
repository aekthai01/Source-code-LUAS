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
local item_helper={GetSubTypeById=function(item_id) return item_id end}
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
local names={
    "CheckEquipmentBeforEnterGameProcess","_CheckProcess","_CheckEquipmentValue",
    "GetAllEquipmentValue","_CheckMedicine","_CheckUnCarryMedicine","_CheckContainer",
    "_CheckBullet","_CheckDurabulity","CheckEquipSlotEmpty","CheckEquipSlotValue",
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
truth(#logs.info>=3,"P0.3 uses source info logger")
eq(#logs.error,0,"P0.3 no error on valid rental plan")

local empty=table.pack(product.CheckEquipSlotEmpty("helmet"))
eq(empty.n,1,"P0.9 return arity"); eq(empty[1],true,"P0.9 empty")
eq(product.CheckEquipSlotValue("helmet"),0,"P0.10 empty slot price")
product._CheckBullet()
product._CheckDurabulity()

local bridge_text=assert(io.open(root.."/src/spectra/product_module_bridge.lua","rb")):read("*a")
eq(bridge_text:find("debug.getupvalue",1,true),nil,"transitional bridge must not introspect payload closures")
print("product-source-only: ok")

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
    eq(Bridge.status().source_owned_root_methods,29,"bridge owns P0.0..P0.28")
    local bridge_result=table.pack(target._CheckPropExpiredStatus())
    eq(bridge_result.n,0,"P0.18 bridge no-return ABI")
    eq(#payload_calls,0,"P0.18 bridge does not call original payload method")
    eq(helper_calls[1],bridge_item,"P0.18 bridge uses context R9 dependency")
    Bridge.restore_original()
end

print("product-expiration: ok")

local root=assert(arg[1])
local S={}
assert(loadfile(root.."/src/spectra/product_module.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module_bridge.lua"))(S)
local Bridge=S.ProductModuleBridge
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function product_fixture()
    local calls={}
    local p={}
    for _,name in ipairs(Bridge.METHODS) do
        p[name]=function() calls[#calls+1]="payload:"..name end
    end
    p.GetMatchBulletNumByWeaponItem=function() return 0 end -- exact P0.13 dependency shape
    return p,calls
end

-- Method installation retains exact payload closures and can restore them.
do
    Bridge.restore_original()
    local product=product_fixture()
    local originals={}; for _,name in ipairs(Bridge.METHODS) do originals[name]=product[name] end
    truth(Bridge.install(product,{dependencies={logger=function() end,error_logger=function() end}}),"install source methods")
    local status=Bridge.status()
    eq(status.source_owned_root_methods,8,"six static roots, unconditional P0.9, and conditional P0.3 installed")
    eq(status.root_methods_total,29,"root method inventory count")
    for _,name in ipairs(Bridge.METHODS) do
        if name=="_CheckBullet" or name=="_CheckDurabulity" then
            eq(product[name],originals[name],"conditional P0.7/P0.8 remain payload-owned without captures")
        else truth(product[name]~=originals[name],name.." replaced") end
    end
    product._CheckProcess=function() end -- explicit teardown must still restore saved payload code.
    Bridge.restore_original()
    for _,name in ipairs(Bridge.METHODS) do eq(product[name],originals[name],name.." restored") end
end

-- The newly overlaid P0.4/P0.5 methods execute through their public module
-- entries and preserve the two payload P0.5 arguments and return record.
do
    Bridge.restore_original()
    local product=product_fixture()
    local added={}
    local field={
        GetMedicineType=function() return {"held"} end,
        GetEquipmentCheckData=function(self,kind,medicine)
            eq(kind,"lack"); eq(medicine,"missing")
            return {switch=true,key=12,abnormalDesc="missing label"}
        end,
        AddEquipAbnormal=function(self,row) added[#added+1]=row end,
    }
    local environment={
        Module={ArmedForce={Field=field,Config={
            EAbnormalType={LackMedicine="lack"},Loc={UnableToResolveTheState="state:%s"},
        }}},
        EDispensingMedicineType={M="missing"},CommonConfig={Loc={Comma=","}},
        table={
            values=function() return {"missing"} end,
            contains=function(list,value) for _,item in ipairs(list) do if item==value then return true end end return false end,
            insert=table.insert,concat=table.concat,
        },
        ipairs=ipairs,math=math,string={format=function(_,text) return text end},
    }
    truth(Bridge.install(product,{environment=environment,
        dependencies={logger=function() end,error_logger=function() end}}),"install product module methods")
    local result=product._CheckUnCarryMedicine({"missing"},{})
    eq(result.key,12,"public P0.5 key result")
    eq(result.unCarryMedicinesTypeList[1],"missing","public P0.5 list result")
    product._CheckMedicine()
    eq(#added,1,"public P0.4 source method adds abnormal")
    eq(added[1].key,12,"public P0.4 forwards P0.5 result")
    Bridge.restore_original()
end

-- A setter failure on the final P0.6 write rolls every earlier write back.
do
    Bridge.restore_original()
    local product=product_fixture()
    local originals={}; for _,name in ipairs(Bridge.METHODS) do originals[name]=product[name] end
    local writes=0
    local ok=Bridge.install(product,{dependencies={logger=function() end,error_logger=function() end},
        set_method=function(target,name,value)
            writes=writes+1
            if writes==7 then error("injected install failure") end
            rawset(target,name,value)
        end})
    eq(ok,false,"partial installation fails")
    for _,name in ipairs(Bridge.METHODS) do eq(product[name],originals[name],name.." transaction rollback") end
    eq(Bridge.status().installed,false,"failed install leaves no ownership")
end

-- P0.7 is overlaid only when its exact captured helper/logger/module values
-- are supplied. Missing captures or a different captured module retain the
-- payload method. A valid capture set installs one coherent source method.
do
    Bridge.restore_original()
    local product=product_fixture()
    local payload_bullet=product._CheckBullet
    local bullet_environment={
        Server={
            ArmedForceServer={GetCurSlotGroupId=function() return "group" end},
            InventoryServer={GetSlot=function(_,slot_type,group)
                eq(group,"group"); return {GetEquipItem=function() return nil end}
            end},
        },
        ESlotType={MainWeaponLeft="left",MainWeaponRight="right",Pistrol="pistol"},
        table={insert=table.insert,concat=table.concat,isempty=function(value) return next(value)==nil end},
        tostring=tostring,
    }
    local p3={logger=function() end,error_logger=function() end}
    truth(Bridge.install(product,{environment=bullet_environment,dependencies=p3}),"install base methods without P0.7 captures")
    eq(product._CheckBullet,payload_bullet,"missing P0.7 captures leave payload method intact")
    eq(Bridge.status().source_owned_root_methods,8,"P0.7 is not counted without captures")
    Bridge.restore_original()

    local product2=product_fixture()
    local payload_bullet2=product2._CheckBullet
    local bullet_dependencies={item_helper={GetSubTypeById=function() end},
        debug_logger=function() end,error_logger=function() end,captured_module={}}
    truth(Bridge.install(product2,{environment=bullet_environment,dependencies=p3,
        bullet_dependencies=bullet_dependencies}),"ordinary overlay installs with an invalid P0.7 capture identity")
    eq(product2._CheckBullet,payload_bullet2,"foreign captured module prevents P0.7 takeover")
    Bridge.restore_original()

    local product3=product_fixture()
    local captured_item_helper={GetSubTypeById=function() end}
    local captured_debug_logger=function() end
    local captured_error_logger=function() end
    local captured_product=product3
    product3._CheckBullet=function()
        if _G==nil then return false end -- establishes the P0.7 `_ENV` capture at index 1
        return captured_item_helper,captured_debug_logger,captured_product,captured_error_logger
    end
    local payload_bullet3=product3._CheckBullet
    local expected_captures={_G,captured_item_helper,captured_debug_logger,product3,captured_error_logger}
    for index=1,5 do
        local _,value=debug.getupvalue(product3._CheckBullet,index)
        eq(value,expected_captures[index],"P0.7 debug upvalue index "..index)
    end
    truth(Bridge.install(product3,{environment=bullet_environment,dependencies=p3}),
        "install overlay after extracting original P0.7 captures by index")
    eq(Bridge.status().source_owned_root_methods,9,"P0.7 source wrapper installed with all captures")
    truth(product3._CheckBullet~=payload_bullet3,"captured P0.7 method replaced")
    product3._CheckBullet()
    Bridge.restore_original()
    eq(product3._CheckBullet,payload_bullet3,"P0.7 original restored")
end

-- If the transactional writer fails after replacing the final conditional
-- P0.7 method, all earlier wrappers and P0.7 are restored together.
do
    Bridge.restore_original()
    local product=product_fixture()
    local originals={}; for _,name in ipairs(Bridge.METHODS) do originals[name]=product[name] end
    local deps={item_helper={GetSubTypeById=function() end},debug_logger=function() end,
        error_logger=function() end,captured_module=product}
    local writes=0
    local ok=Bridge.install(product,{dependencies={logger=function() end,error_logger=function() end},
        bullet_dependencies=deps,set_method=function(target,name,value)
            writes=writes+1
            if writes==8 then error("injected P0.7 install failure") end
            rawset(target,name,value)
        end})
    eq(ok,false,"transaction aborts after the final P0.7 write fails")
    for _,name in ipairs(Bridge.METHODS) do eq(product[name],originals[name],name.." P0.7 rollback") end
    eq(Bridge.status().installed,false,"P0.7 failed transaction leaves no ownership")
end

-- P0.8 has one stripped error-logger capture at upvalue 2. The bridge checks
-- that exact position and leaves the payload method in place if unavailable.
do
    Bridge.restore_original()
    local product=product_fixture()
    local p3={logger=function() end,error_logger=function() end}
    local payload_durability=product._CheckDurabulity
    local empty_environment={
        Server={ArmedForceServer={GetCurSlotGroupId=function() return "group" end},
            InventoryServer={GetSlot=function() return {GetEquipItem=function() return nil end} end}},
        ESlotType={Helmet="helmet",BreastPlate="breastplate"},table={insert=table.insert,
            concat=table.concat},tostring=tostring,
    }
    truth(Bridge.install(product,{dependencies=p3,environment=empty_environment}),"install root overlay without P0.8 capture")
    eq(product._CheckDurabulity,payload_durability,"missing P0.8 logger keeps payload method")
    eq(Bridge.status().source_owned_root_methods,8,"P0.8 not owned without logger capture")
    Bridge.restore_original()

    local product2=product_fixture()
    local captured_logger=function() end
    product2._CheckDurabulity=function()
        if _G==nil then return false end
        return captured_logger
    end
    local payload_durability2=product2._CheckDurabulity
    local _,upvalue1=debug.getupvalue(payload_durability2,1)
    local _,upvalue2=debug.getupvalue(payload_durability2,2)
    eq(upvalue1,_G,"P0.8 U0 is _ENV")
    eq(upvalue2,captured_logger,"P0.8 U1 is the captured error logger")
    truth(Bridge.install(product2,{dependencies=p3,environment=empty_environment}),"install P0.8 after exact logger capture")
    eq(Bridge.status().source_owned_root_methods,9,"P0.8 capture condition adds its wrapper")
    truth(product2._CheckDurabulity~=payload_durability2,"P0.8 source wrapper installed")
    product2._CheckDurabulity()
    Bridge.restore_original()
    eq(product2._CheckDurabulity,payload_durability2,"P0.8 payload closure restored")

    local product3=product_fixture()
    local logger3=function() end
    product3._CheckDurabulity=function()
        if _G==nil then return false end
        return logger3
    end
    local originals3={}; for _,name in ipairs(Bridge.METHODS) do originals3[name]=product3[name] end
    local writes=0
    local ok=Bridge.install(product3,{dependencies=p3,environment=empty_environment,
        set_method=function(target,name,value)
            writes=writes+1
            if writes==8 then error("injected P0.8 install failure") end
            rawset(target,name,value)
        end})
    eq(ok,false,"final conditional P0.8 write failure aborts install")
    for _,name in ipairs(Bridge.METHODS) do eq(product3[name],originals3[name],name.." P0.8 transaction rollback") end
    eq(Bridge.status().installed,false,"P0.8 rollback clears ownership")
end

-- A source exception is propagated once. The preserved payload closure is
-- not retried after the first operation may have had side effects.
do
    Bridge.restore_original()
    local product,payload_calls=product_fixture()
    local original_process=product._CheckProcess
    local first_calls=0
    product._CheckBullet=function() first_calls=first_calls+1; error("after partial effect") end
    truth(Bridge.install(product,{dependencies={logger=function() end,error_logger=function() end}}),"install for source exception")
    local ok=pcall(product._CheckProcess)
    eq(ok,false,"source error remains visible")
    eq(first_calls,1,"first side effect attempted once")
    eq(#payload_calls,0,"payload process not retried")
    truth(Bridge.status().last_error:find("after partial effect",1,true)~=nil,"source error recorded")
    Bridge.restore_original()
    eq(product._CheckProcess,original_process,"source exception path remains restorable")
end

-- PayloadUIBridge receives the module return captured by PayloadLoader. When
-- the original P0.3 logger captures cannot be recovered, P0.0..P0.2 and
-- P0.4..P0.6 are overlaid and P0.3 remains its exact payload closure.
do
    Bridge.restore_original()
    local product=product_fixture()
    local p3_original=product.GetAllEquipmentValue
    local state={product=product}
    S.Runtime={get_state=function() return state end}
    S.NativeSettingsUI={takeover_after_payload_load=function() return true end}
    S.PayloadFeatureBridge={takeover_after_payload_load=function() return true end}
    S.PayloadVisualBridge={takeover_after_payload_load=function() return true end}
    assert(loadfile(root.."/src/spectra/payload_ui_bridge.lua"))(S)
    truth(S.PayloadUIBridge.after_payload_load(),"product overlay called after payload load")
    eq(Bridge.status().source_owned_root_methods,7,"six root methods plus P0.9 installed without P0.3 captures")
    eq(product.GetAllEquipmentValue,p3_original,"P0.3 remains payload-owned without recovered logger captures")
    Bridge.restore_original()
end

-- P0.9 bridge preserves its public slot-type argument and open return count.
do
    Bridge.restore_original()
    local product=product_fixture()
    local original=product.CheckEquipSlotEmpty
    local calls,item={},nil
    local armed={GetCurSlotGroupId=function() calls[#calls+1]="group"; return "slot-group" end}
    local inventory={GetSlot=function(_,slot_type,group)
        calls[#calls+1]="slot:"..slot_type..":"..group
        return {GetEquipItem=function() calls[#calls+1]="item"; return item end}
    end}
    local environment={Server={ArmedForceServer=armed,InventoryServer=inventory}}
    truth(Bridge.install(product,{environment=environment}),"install source overlay with P0.9")
    local empty=table.pack(product.CheckEquipSlotEmpty("slot-x","ignored-extra"))
    eq(empty.n,1,"bridge preserves empty-slot return arity")
    eq(empty[1],true)
    item={id="occupied"}
    local occupied=table.pack(product.CheckEquipSlotEmpty("slot-y"))
    eq(occupied.n,2,"bridge preserves occupied-slot return arity")
    eq(occupied[1],false); eq(occupied[2],item)
    eq(table.concat(calls,","),"group,slot:slot-x:slot-group,item,group,slot:slot-y:slot-group,item",
        "bridge forwards slot type and keeps bytecode call order")
    Bridge.restore_original()
    eq(product.CheckEquipSlotEmpty,original,"P0.9 original closure restored")
end

print("product-module-bridge: ok")

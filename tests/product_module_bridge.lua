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
    return p,calls
end

-- Method installation retains exact payload closures and can restore them.
do
    Bridge.restore_original()
    local product=product_fixture()
    local originals={}; for _,name in ipairs(Bridge.METHODS) do originals[name]=product[name] end
    truth(Bridge.install(product,{dependencies={logger=function() end,error_logger=function() end}}),"install source methods")
    local status=Bridge.status()
    eq(status.source_owned_root_methods,7,"six static roots plus the conditional P0.3 method are installed")
    eq(status.root_methods_total,29,"root method inventory count")
    for _,name in ipairs(Bridge.METHODS) do truth(product[name]~=originals[name],name.." replaced") end
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
    eq(Bridge.status().source_owned_root_methods,6,"six root methods installed without P0.3 captures")
    eq(product.GetAllEquipmentValue,p3_original,"P0.3 remains payload-owned without recovered logger captures")
    Bridge.restore_original()
end

print("product-module-bridge: ok")

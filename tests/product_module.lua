local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/product_module.lua"))(S)
local Product = S.ProductModule
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end

-- P0.0 preserves both branches. The first flow call's complete return list is
-- forwarded to CheckMainFlowSOL; a false result causes a second flow lookup.
do
    local calls, count = {}, 0
    local field
    field = {
        ResetEquipAbnormalDatas=function(self) eq(self,field,"reset receiver"); calls[#calls+1]="reset" end,
    }
    local changed
    changed = {Invoke=function(self) eq(self,changed,"event receiver"); calls[#calls+1]="event" end}
    local module={_CheckProcess=function() calls[#calls+1]="process" end}
    local manager
    manager={
        GetCurrentGameFlow=function(self)
            eq(self,manager,"flow receiver"); count=count+1
            if count==1 then return "flow", "forwarded-tail" end
            return "different-flow"
        end,
        CheckMainFlowSOL=function(self, first, second)
            eq(self,manager,"check receiver"); eq(first,"flow"); eq(second,"forwarded-tail")
            return true
        end,
    }
    local globals={Facade={GameFlowManager=manager},EGameFlowStageType={Lobby="lobby"},
        Module={ArmedForce={Field=field,Config={evtEquipAbnormalChanged=changed}}}}
    Product.CheckEquipmentBeforEnterGameProcess(module,globals)
    eq(count,1,"true main-flow branch only reads current flow once")
    eq(table.concat(calls,","),"reset,process,event","P0.0 mutation order")

    calls,count={},0
    manager.CheckMainFlowSOL=function() return false end
    manager.GetCurrentGameFlow=function() count=count+1; return count==1 and "first" or "lobby" end
    globals.EGameFlowStageType.Lobby="lobby"
    Product.CheckEquipmentBeforEnterGameProcess(module,globals)
    eq(count,2,"false main-flow branch re-reads current flow")
    eq(#calls,0,"lobby branch returns before reset")

    calls,count={},0
    manager.GetCurrentGameFlow=function() count=count+1; return count==1 and "first" or "raid" end
    Product.CheckEquipmentBeforEnterGameProcess(module,globals)
    eq(count,2,"non-lobby branch uses second flow result")
    eq(table.concat(calls,","),"reset,process,event","non-lobby call sequence")
end

-- P0.1 executes each captured module function in bytecode order and then sorts.
do
    local calls={}
    local module={}
    for _,name in ipairs({"_CheckBullet","_CheckDurabulity","_CheckContainer","_CheckMedicine",
        "_CheckEquipmentValue","_CheckNightFight","CheckRentalConsumableID",
        "_CheckSafeBoxExpiredStatus","_CheckKeyChainExpiredStatus","_CheckPropExpiredStatus"}) do
        module[name]=function(...)
            eq(select("#",...),0,name .. " is a plain closure call")
            calls[#calls+1]=name
        end
    end
    local field
    field={SortEquipAbnormal=function(self) eq(self,field,"sort receiver"); calls[#calls+1]="SortEquipAbnormal" end}
    Product._CheckProcess(module,{Module={ArmedForce={Field=field}}})
    eq(table.concat(calls,","),"_CheckBullet,_CheckDurabulity,_CheckContainer,_CheckMedicine,_CheckEquipmentValue,_CheckNightFight,CheckRentalConsumableID,_CheckSafeBoxExpiredStatus,_CheckKeyChainExpiredStatus,_CheckPropExpiredStatus,SortEquipAbnormal","P0.1 exact order")
end

local function equipment_value_case(current, required, maximum, lower, upper)
    local added, lookups = {}, {}
    local field
    field={
        GetEquipmentCheckData=function(self,kind,zero)
            eq(self,field,"check-data receiver"); eq(zero,0,"check-data second argument")
            lookups[#lookups+1]=kind
            return kind=="lower" and lower or (kind=="upper" and upper or nil)
        end,
        AddEquipAbnormal=function(self,data) eq(self,field,"add receiver"); added[#added+1]=data end,
    }
    local module={GetAllEquipmentValue=function() return current end}
    local globals={
        Server={GameModeServer={GetMapNeedValue=function(self) return required,maximum end}},
        Module={ArmedForce={Field=field,Config={EAbnormalType={
            EquipmentAllValueNotEnough="lower",EquipmentAllValueExceeds="upper"}}}},
    }
    Product._CheckEquipmentValue(module,globals)
    return added,lookups
end

-- P0.2 uses strict lower/upper comparisons and skips disabled or absent checks.
do
    local low={key="low-key",abnormalDesc="low-desc",switch=true}
    local high={key="high-key",abnormalDesc="high-desc",switch=true}
    local added=equipment_value_case(99,100,200,low,high)
    eq(#added,1,"below lower threshold adds one abnormal")
    eq(added[1].key,"low-key"); eq(added[1].abnormalType,"lower"); eq(added[1].loc,"low-desc")
    eq(added[1].param.needValue,100); eq(added[1].param.curAllValue,99)

    added=equipment_value_case(100,100,200,low,high)
    eq(#added,0,"equal lower threshold is not below")
    added=equipment_value_case(201,0,200,low,high)
    eq(#added,1,"above upper threshold adds one abnormal")
    eq(added[1].key,"high-key"); eq(added[1].abnormalType,"upper")
    eq(added[1].param.needValue,200); eq(added[1].param.curAllValue,201)
    added=equipment_value_case(200,0,200,low,high)
    eq(#added,0,"equal upper threshold is not exceeded")
    added=equipment_value_case(201,0,0,low,high)
    eq(#added,0,"zero maximum disables upper comparison")
    added=equipment_value_case(1,0,0,low,high)
    eq(#added,0,"zero minimum disables lower comparison")

    low.switch=false; high.switch=false
    added=equipment_value_case(1,100,200,low,high)
    eq(#added,0,"disabled check switches suppress abnormalities")
    added=equipment_value_case(1,100,200,nil,nil)
    eq(#added,0,"missing check records are ignored")

    local add_order={}
    local upper={key="dynamic-upper",abnormalDesc="dynamic",switch=true}
    local globals
    local field_second
    field_second={
        GetEquipmentCheckData=function(self,kind,zero)
            eq(self,field_second,"upper check re-fetches Field")
            eq(kind,"upper-after-lower","upper enum is re-read after lower side effects")
            eq(zero,0)
            return upper
        end,
        AddEquipAbnormal=function(self,row) add_order[#add_order+1]={self,row} end,
    }
    local lower={key="dynamic-lower",abnormalDesc="dynamic",switch=true}
    local field_first
    field_first={
        GetEquipmentCheckData=function(self,kind,zero)
            eq(self,field_first); eq(kind,"lower-before-side-effect"); eq(zero,0)
            return lower
        end,
        AddEquipAbnormal=function(self,row)
            add_order[#add_order+1]={self,row}
            globals.Module.ArmedForce.Field=field_second
            globals.Module.ArmedForce.Config.EAbnormalType.EquipmentAllValueExceeds="upper-after-lower"
        end,
    }
    globals={
        Server={GameModeServer={GetMapNeedValue=function() return 200,100 end}},
        Module={ArmedForce={Field=field_first,Config={EAbnormalType={
            EquipmentAllValueNotEnough="lower-before-side-effect",
            EquipmentAllValueExceeds="upper-before-side-effect"}}}},
    }
    Product._CheckEquipmentValue({GetAllEquipmentValue=function() return 150 end},globals)
    eq(#add_order,2,"both overlapping map boundaries add abnormalities")
    eq(add_order[1][1],field_first,"first add uses first captured Field")
    eq(add_order[1][2].abnormalType,"lower-before-side-effect","first abnormal enum read before first add")
    eq(add_order[2][1],field_second,"second add re-reads Field")
    eq(add_order[2][2].abnormalType,"upper-after-lower","second abnormal enum read after first add")

    local ok=pcall(Product._CheckEquipmentValue,{GetAllEquipmentValue=function() return 1 end},{})
    eq(ok,false,"missing server globals retain bytecode error behavior")
end

local function equipment_runtime(rental_status, rental_plan, challenge)
    local slot_calls, events, logs, errors = {}, {}, {}, {}
    local challenge_module
    challenge_module={CheckInSOLChallengeMode=function(self) eq(self,challenge_module,"challenge receiver"); return challenge end}
    local server
    server={
        CheckIsRentalStatus=function(self) eq(self,server,"rental receiver"); return rental_status end,
        GetCurRentalPlan=function(self) eq(self,server,"rental-plan receiver"); return rental_plan end,
        GetCurSlotGroupId=function(self) eq(self,server,"slot-group receiver"); return "slot-group-7" end,
    }
    local field_config
    field_config={evtAllEquipmentValueChanged={Invoke=function(self,...)
        eq(self,field_config.evtAllEquipmentValueChanged,"value-event receiver")
        events={...}
    end}}
    local globals={
        Module={LobbySOLChallenge=challenge_module,ArmedForce={Config=field_config}},
        Server={ArmedForceServer=server},
        ECurrencyClientType={SOLChallengeCoin="challenge-coin",OnlyUnBind="unbound"},
        ESlotType={Helmet=1,BreastPlate=2,ChestHanging=3,Bag=4,MainWeaponLeft=5,MainWeaponRight=6,Pistrol=7},
        string=string,
    }
    local module={CheckEquipSlotValue=function(slot)
        slot_calls[#slot_calls+1]=slot
        return slot*10
    end}
    local deps={logger=function(value) logs[#logs+1]=value end,
        error_logger=function(value) errors[#errors+1]=value end}
    local total,currency=Product.GetAllEquipmentValue(module,globals,deps)
    return total,currency,slot_calls,events,logs,errors
end

-- P0.3 verifies currency selection, the seven slot inputs, rental-plan
-- fallback, two-value return, and the event invocation arguments.
do
    local total,currency,slots,event,logs=equipment_runtime(false,nil,true)
    eq(total,280,"sum of the seven bytecode slot values")
    eq(currency,"challenge-coin","challenge currency")
    eq(#slots,7,"all seven equipment slots are checked")
    local seen={}; for _,slot in ipairs(slots) do seen[slot]=true end
    for slot=1,7 do truth(seen[slot],"slot id "..slot.." checked") end
    eq(event[1],280,"event total"); eq(event[2],"challenge-coin","event currency")
    eq(#logs,3,"start, total and end diagnostic calls")

    total,currency,slots,event=equipment_runtime(false,nil,false)
    eq(currency,"unbound","ordinary-mode currency")
    eq(event[2],"unbound","ordinary-mode event currency")

    local rental={preset_price=735,consumable_id="c-1",type_id="rental",preset_id="p-1"}
    total,currency,slots,event,logs=equipment_runtime(true,rental,true)
    eq(total,735,"rental preset price")
    eq(#slots,0,"rental path skips slot values")
    eq(event[1],735,"rental event total")
    eq(logs[2]:find("consumable_id = c%-1")~=nil,true,"rental diagnostic fields")

    total,currency,slots,event,logs,errors=equipment_runtime(true,nil,false)
    eq(total,0,"missing rental plan falls back to zero")
    eq(#slots,0,"missing rental plan does not enter slot path")
    eq(#errors,1,"missing rental plan uses captured error logger")
    eq(event[1],0,"missing-plan event value")
    eq(event[2],"unbound","missing-plan currency")
end

-- P0.5's expected vectors come from the bytecode gates at instructions 13..51:
-- inspect each enum in ipairs order, keep only present+enabled config rows
-- absent from the carried-type list, aggregate max(key), and append both lists.
do
    local calls, contains_calls = {}, {}
    local records = {
        A={switch=true,key=4,abnormalDesc="DescA"},
        B={switch=true,key=99,abnormalDesc="DescB"},
        C={switch=false,key=8,abnormalDesc="DescC"},
    }
    local field
    field={GetEquipmentCheckData=function(self,kind,medicine_type)
        eq(self,field,"P0.5 reuses the current Field as method receiver")
        eq(kind,"lack-medicine","P0.5 check category")
        calls[#calls+1]=medicine_type
        return records[medicine_type]
    end}
    local env
    env={
        Module={ArmedForce={Field=field,Config={EAbnormalType={LackMedicine="lack-medicine"}}}},
        ipairs=ipairs, math=math,
        table={contains=function(list,value)
            contains_calls[#contains_calls+1]=value
            for _,entry in ipairs(list) do if entry==value then return true end end
            return false
        end,insert=table.insert},
    }
    local actual=Product._CheckUnCarryMedicine({},env,{"A","B","C","D","A"},{"B"})
    eq(actual.key,4,"max of missing enabled medicine keys")
    eq(table.concat(actual.unCarryMedicinesTypeList,","),"A,A","bytecode does not deduplicate repeated enum values")
    eq(table.concat(actual.unCarryMedicinesTypeStrList,","),"DescA,DescA","description append order and duplicates")
    eq(table.concat(calls,","),"A,B,C,D,A","P0.5 preserves ipairs traversal")
    eq(table.concat(contains_calls,","),"A,B,A","switch and missing-record gates precede table.contains")

    local env2
    local field2
    field2={GetEquipmentCheckData=function(self,kind,medicine_type)
        eq(self,field2,"P0.5 re-reads Field for each enum value")
        eq(kind,"second-type","P0.5 re-reads config type for each enum value")
        eq(medicine_type,"second")
        return nil
    end}
    local field1
    field1={GetEquipmentCheckData=function(self,kind,medicine_type)
        eq(self,field1); eq(kind,"first-type"); eq(medicine_type,"first")
        env2.Module.ArmedForce.Field=field2
        env2.Module.ArmedForce.Config.EAbnormalType.LackMedicine="second-type"
        return {switch=false}
    end}
    env2={
        Module={ArmedForce={Field=field1,Config={EAbnormalType={LackMedicine="first-type"}}}},
        ipairs=ipairs,math=math,
        table={contains=function() error("disabled or missing check must not query carried list") end,
            insert=table.insert},
    }
    Product._CheckUnCarryMedicine({},env2,{"first","second"},{})
end

-- P0.4 explicitly reads Field:GetMedicineType before table.values, dispatches
-- the returned values and carried list to P0.5, then builds the exact abnormal
-- table only when the missing-type list is nonempty.
do
    local calls, added, format_args = {}, {}, nil
    local values={"A","B"}
    local field
    field={
        GetMedicineType=function(self)
            eq(self,field,"medicine query receiver"); calls[#calls+1]="get-medicine-types"
            return {"B"}
        end,
        GetEquipmentCheckData=function(self,kind,medicine_type)
            calls[#calls+1]="check:"..medicine_type
            eq(kind,"lack-enum")
            if medicine_type=="A" then return {switch=true,key=7,abnormalDesc="Alpha"} end
            return {switch=true,key=2,abnormalDesc="Beta"}
        end,
        AddEquipAbnormal=function() error("P0.4 must re-read Field after the helper returns") end,
    }
    local add_field
    add_field={AddEquipAbnormal=function(self,row)
        eq(self,add_field,"abnormal add re-reads current Field"); added[#added+1]=row
    end}
    local env
    env={
        Module={ArmedForce={Field=field,Config={
            EAbnormalType={LackMedicine="lack-enum"},
            Loc={UnableToResolveTheState="state-template"},
        }}},
        EDispensingMedicineType={First="A",Second="B"},
        CommonConfig={Loc={Comma=" / "}},
        ipairs=ipairs, math=math,
        table={
            values=function(enum)
                eq(enum,env.EDispensingMedicineType,"enum table source")
                calls[#calls+1]="table-values"
                return values
            end,
            contains=function(list,value)
                for _,entry in ipairs(list) do if entry==value then return true end end
                return false
            end,
            insert=table.insert,
            concat=table.concat,
        },
        string={format=function(template,joined)
            format_args={template,joined}
            return "formatted:"..joined
        end},
    }
    local module={}
    module._CheckUnCarryMedicine=function(enum_values,carried_types)
        calls[#calls+1]="dispatch:P0.5"
        local result=Product._CheckUnCarryMedicine(module,env,enum_values,carried_types)
        env.Module.ArmedForce.Field=add_field
        return result
    end
    local p5_before_values=module._CheckUnCarryMedicine
    local table_values=env.table.values
    env.table.values=function(enum)
        local result=table_values(enum)
        -- P0.4 fetches the public helper before executing table.values.
        module._CheckUnCarryMedicine=function() error("P0.4 re-fetched P0.5 after table.values") end
        return result
    end
    Product._CheckMedicine(module,env)
    eq(table.concat(calls,","),"get-medicine-types,table-values,dispatch:P0.5,check:A,check:B","P0.4 call order")
    eq(#added,1,"nonempty missing list creates one abnormal")
    eq(added[1].key,7,"P0.4 forwards aggregate max key")
    eq(added[1].abnormalType,"lack-enum","P0.4 abnormal enum")
    eq(added[1].loc,"formatted:Alpha","P0.4 formats joined descriptions")
    eq(table.concat(added[1].param.abnormalTypeList,","),"A","carried medicine is excluded")
    eq(format_args[1],"state-template"); eq(format_args[2],"Alpha")

    added={}
    module._CheckUnCarryMedicine=p5_before_values
    env.Module.ArmedForce.Field=field
    env.Module.ArmedForce.Field.GetMedicineType=function() return {"A","B"} end
    Product._CheckMedicine(module,env)
    eq(#added,0,"empty missing list does not add an abnormal")
end

print("product-module: ok")

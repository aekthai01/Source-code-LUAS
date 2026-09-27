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

local function container_fixture(options)
    options=options or {}
    local calls, abnormalities, medicine_types, format_calls, decimal_inputs, rounded_inputs = {}, {}, {}, {}, {}, {}
    local check_data=options.check_data or {
        storage={switch=true,checkValue=0.40,key=31,abnormalDesc="storage-desc"},
        unnecessary={switch=true,checkValue=74,key=42,abnormalDesc="safe-box-desc"},
    }
    local field
    field={
        GetEquipmentCheckData=function(self,kind,zero)
            eq(self,field,"container check-data receiver"); eq(zero,0,"container check-data key")
            calls[#calls+1]="check:"..kind
            return check_data[kind]
        end,
        AddEquipAbnormal=function(self,row)
            eq(self,field,"container abnormal receiver")
            calls[#calls+1]="add:"..row.abnormalType
            abnormalities[#abnormalities+1]=row
        end,
        AddMedicineType=function(self,medicine_type)
            eq(self,field,"medicine-type receiver")
            calls[#calls+1]="medicine:"..medicine_type
            medicine_types[#medicine_types+1]=medicine_type
        end,
    }
    local function item(main_type, feature)
        return {itemMainType=main_type,GetFeature=function(self,feature_type)
            eq(feature_type,"health-feature","P0.6.0 requests Health feature")
            return feature
        end}
    end
    local slots
    local function slot(name,capacity,remaining,used)
        return {
            GetTotalCapacity=function(self) eq(self,slots[name]); calls[#calls+1]="capacity:"..name; return capacity end,
            GetRemainingSpaceSize=function(self) eq(self,slots[name]); calls[#calls+1]="remaining:"..name; return remaining end,
            GetUsedCapacity=function(self) eq(self,slots[name]); calls[#calls+1]="used:"..name; return used end,
            GetItems=function(self) eq(self,slots[name]); calls[#calls+1]="items:"..name; return self.items end,
        }
    end
    slots={
        ChestHangingContainer=slot("ChestHangingContainer",4,1),
        BagContainer=slot("BagContainer",5,2),
        Pocket=slot("Pocket",3,1),
        SafeBoxContainer=slot("SafeBoxContainer",0,0,options.used_capacity or 75),
    }
    for name,s in pairs(slots) do
        if name~="SafeBoxContainer" or options.safe_items~=false then
            s.items={
                item("medicine",{medicineType="med:"..name}),
                item("other",{medicineType="ignored:"..name}),
                item("medicine",nil),
                item("medicine",{}),
            }
            s.items[#s.items].GetFeature=function() return {medicineType=nil} end
        else
            s.items={}
        end
    end
    local group_id="inventory-group"
    local inventory_server
    inventory_server={GetSlot=function(self,slot_type,group)
        eq(self,inventory_server,"InventoryServer receiver")
        local name=({[1]="ChestHangingContainer",[2]="BagContainer",[3]="Pocket",[4]="SafeBoxContainer"})[slot_type]
        truth(name,"known bytecode slot type")
        calls[#calls+1]="slot:"..name
        if name=="SafeBoxContainer" then
            eq(group,options.challenge and "challenge-group" or "player-group","safe-box group selection")
        else
            eq(group,group_id,"current slot group id")
        end
        return slots[name]
    end}
    local armed_force_server
    armed_force_server={GetCurSlotGroupId=function(self)
        eq(self,armed_force_server,"ArmedForceServer receiver"); calls[#calls+1]="slot-group"; return group_id
    end}
    local challenge_module
    challenge_module={CheckInSOLChallengeMode=function(self)
        eq(self,challenge_module,"challenge receiver"); calls[#calls+1]="challenge"; return options.challenge
    end}
    local slot_groups={Player="player-group"}
    if options.challenge then
        slot_groups.SOLChallenge="challenge-group"
    else
        setmetatable(slot_groups,{__index=function(_,key)
            if key=="SOLChallenge" then error("P0.6 does not read SOLChallenge for non-challenge mode") end
        end})
    end
    local environment={
        Module={
            ArmedForce={Field=field,Config={EAbnormalType={
                StorageSpaceIsTight="storage",HasUnnecessaryItems="unnecessary",
            }}},
            LobbySOLChallenge=challenge_module,
        },
        Server={ArmedForceServer=armed_force_server,InventoryServer=inventory_server},
        ESlotType={ChestHangingContainer=1,BagContainer=2,Pocket=3,SafeBoxContainer=4},
        ESlotGroup=slot_groups,
        EItemType={Medicine="medicine"},EFeatureType={Health="health-feature"},
        pairs=pairs,table=table,
        MathUtil={
            GetTheSecondDecimal=function(value)
                decimal_inputs[#decimal_inputs+1]=value; return value
            end,
            GetRoundingNum=function(value)
                rounded_inputs[#rounded_inputs+1]=value
                if value==40 then return value,"rounding-tail" end
                return value
            end,
        },
        string={format=function(description,...)
            format_calls[#format_calls+1]={description,table.pack(...)}
            return "formatted-storage-location"
        end},
    }
    local function run()
        Product._CheckContainer({},environment)
    end
    return run,calls,abnormalities,medicine_types,format_calls,decimal_inputs,rounded_inputs
end

-- P0.6 vectors exercise bytecode slot order, per-slot epsilon, strict ratio
-- comparisons, two independent abnormal branches, challenge/player safe-box
-- selection, and nested P0.6.0 filtering over pairs-based item collections.
do
    local run,calls,abnormalities,medicine_types,format_calls,decimal_inputs,rounded_inputs=
        container_fixture({challenge=true})
    run()
    eq(calls[1],"check:storage","storage config is read before inventory traversal")
    eq(calls[2],"slot-group","current group is queried after storage config")
    local positions={}
    for i,name in ipairs(calls) do positions[name]=i end
    truth(positions["items:ChestHangingContainer"] < positions["slot:BagContainer"],"left container items are scanned before bag lookup")
    truth(positions["items:BagContainer"] < positions["slot:Pocket"],"bag items are scanned before pocket lookup")
    truth(positions["items:Pocket"] < positions["add:storage"],"storage abnormal follows the three slot scans")
    truth(positions["add:storage"] < positions.challenge,"storage abnormal precedes safe-box mode query")
    truth(positions.challenge < positions["slot:SafeBoxContainer"],"challenge mode selects safe-box group before lookup")
    truth(positions["used:SafeBoxContainer"] < positions["check:unnecessary"],"safe-box capacity precedes config query")
    truth(positions["check:unnecessary"] < positions["add:unnecessary"],"safe-box abnormal follows configured threshold")
    truth(positions["add:unnecessary"] < positions["items:SafeBoxContainer"],"safe-box item scan follows abnormal check")
    eq(#abnormalities,2,"storage and unnecessary-item abnormalities both emitted")
    eq(abnormalities[1].key,31); eq(abnormalities[1].abnormalType,"storage")
    eq(abnormalities[1].loc,"formatted-storage-location"); truth(next(abnormalities[1].param)==nil,"storage param is empty")
    eq(abnormalities[2].key,42); eq(abnormalities[2].abnormalType,"unnecessary")
    eq(abnormalities[2].loc,"safe-box-desc"); truth(next(abnormalities[2].param)==nil,"safe-box param is empty")
    eq(#format_calls,1,"storage location is formatted once")
    eq(format_calls[1][1],"storage-desc"); eq(format_calls[1][2].n,2,"open P0.6 rounding call forwards all returned values")
    eq(format_calls[1][2][1],40); eq(format_calls[1][2][2],"rounding-tail")
    eq(#decimal_inputs,2,"remaining and configured ratios are both normalized")
    local epsilon=1e-6
    eq(decimal_inputs[1],((1+epsilon)+(2+epsilon)+(1+epsilon))/((4+epsilon)+(5+epsilon)+(3+epsilon)),"free-space ratio includes per-slot epsilon")
    eq(decimal_inputs[2],0.40,"configured free-space ratio")
    eq(rounded_inputs[1],40,"storage threshold is scaled by 100 before rounding")
    eq(rounded_inputs[2],74,"safe-box threshold is rounded without scaling")
    eq(#medicine_types,4,"nested callback accepts one valid medicine feature per slot")
    local observed={}; for _,v in ipairs(medicine_types) do observed[v]=true end
    for _,name in ipairs({"ChestHangingContainer","BagContainer","Pocket","SafeBoxContainer"}) do
        truth(observed["med:"..name],"medicine type extracted from "..name)
    end

    local ratio=((1+epsilon)+(2+epsilon)+(1+epsilon))/((4+epsilon)+(5+epsilon)+(3+epsilon))
    run,calls,abnormalities=container_fixture({challenge=false,check_data={
        storage={switch=true,checkValue=ratio,key=1,abnormalDesc="equal"},
        unnecessary={switch=true,checkValue=75,key=2,abnormalDesc="equal"},
    }})
    run()
    eq(#abnormalities,0,"equal rounded thresholds do not trigger strict comparisons")
    truth(calls[1]=="check:storage","normal-mode path reads storage config")

    local run2,calls2,abnormalities2=container_fixture({challenge=false,check_data={storage=nil,unnecessary={switch=false,checkValue=1}}})
    run2()
    eq(#abnormalities2,0,"missing storage record and disabled safe-box switch add no abnormalities")
    truth(calls2[1]=="check:storage","storage config lookup still occurs when data is missing")

    local run_zero,calls_zero,abnormalities_zero,medicine_zero,format_zero,decimals_zero,rounded_zero=container_fixture({
        challenge=false,
        check_data={
            storage={switch=true,checkValue=0,key=3,abnormalDesc="zero"},
            unnecessary={switch=true,checkValue=0,key=4,abnormalDesc="zero"},
        },
    })
    run_zero()
    eq(#decimals_zero,2,"zero storage threshold follows the bytecode nonnegative branch")
    eq(#rounded_zero,1,"zero safe-box threshold is rounded")
    eq(rounded_zero[1],0)
    eq(#abnormalities_zero,1,"zero safe-box threshold still compares used capacity")
    eq(abnormalities_zero[1].abnormalType,"unnecessary")

    local run_negative,calls_negative,abnormalities_negative,medicine_negative,format_negative,decimals_negative,rounded_negative=container_fixture({
        challenge=false,
        check_data={
            storage={switch=true,checkValue=-0.01,key=5,abnormalDesc="negative"},
            unnecessary={switch=true,checkValue=-1,key=6,abnormalDesc="negative"},
        },
    })
    run_negative()
    eq(#abnormalities_negative,0,"negative thresholds leave both bytecode branches")
    eq(#decimals_negative,0,"negative storage check skips decimal helpers")
    eq(#rounded_negative,0,"negative safe-box check skips rounding")
end

local function bullet_fixture(spec)
    spec = spec or {}
    local calls, abnormalities, debug_calls, error_calls = {}, {}, {}, {}
    local item_by_slot = spec.items or {}
    local check_by_subtype = spec.checks or {}
    local count_by_item = spec.counts or {}
    local slot_group = spec.slot_group or "group-9"
    local field
    field = {
        GetEquipmentCheckData = function(self, abnormal_type, subtype)
            eq(self, field, "P0.7 check-data receiver")
            eq(abnormal_type, "lack-bullet", "P0.7 abnormal category")
            calls[#calls + 1] = "check:" .. tostring(subtype)
            return check_by_subtype[subtype]
        end,
        AddEquipAbnormal = function(self, record)
            eq(self, field, "P0.7 abnormal receiver")
            calls[#calls + 1] = "add"
            abnormalities[#abnormalities + 1] = record
        end,
    }
    local inventory = {}
    function inventory:GetSlot(slot_type, group)
        eq(self, inventory, "P0.7 inventory receiver")
        eq(group, slot_group, "P0.7 captured slot group")
        calls[#calls + 1] = "slot:" .. tostring(slot_type)
        local slot = {}
        function slot:GetEquipItem()
            eq(self, slot, "P0.7 slot receiver")
            calls[#calls + 1] = "item:" .. tostring(slot_type)
            return item_by_slot[slot_type]
        end
        return slot
    end
    local server
    server = {GetCurSlotGroupId=function(self)
        eq(self, server, "P0.7 armed force server receiver")
        calls[#calls + 1] = "group"
        return slot_group
    end}
    local environment = {
        Server={ArmedForceServer=server,InventoryServer=inventory},
        ESlotType={MainWeaponLeft="left",MainWeaponRight="right",Pistrol="pistol"},
        Module={ArmedForce={Field=field,Config={EAbnormalType={LackBullet="lack-bullet"}}}},
        MathUtil={GetRoundingNum=function(value)
            calls[#calls + 1] = "round:" .. tostring(value)
            if spec.round then return spec.round(value) end
            return value
        end},
        ItemConfig={MapWeaponItemType2Name=spec.names or {rifle="Rifle ammo",pistol="Pistol ammo"}},
        StringUtil={PluralTextFormat=function(description, args)
            calls[#calls + 1] = "format:" .. tostring(description)
            return description .. " " .. tostring(args.BulletName) .. " x" .. tostring(args.BulletNum)
        end},
        CommonConfig={Loc={Comma=" | "}},
        table={insert=table.insert,concat=table.concat,isempty=function(value) return next(value)==nil end},
        tostring=tostring,math=math,
    }
    local module={GetMatchBulletNumByWeaponItem=function(...)
        local args=table.pack(...)
        eq(args.n,2,"P0.7 match helper is a plain two-argument call")
        local item,group=args[1],args[2]
        eq(group,slot_group,"P0.7 passes the one captured group to match helper")
        calls[#calls + 1] = "match:" .. tostring(item.id)
        return count_by_item[item.id] or 0
    end}
    local dependencies={
        item_helper={GetSubTypeById=function(...)
            local args=table.pack(...)
            eq(args.n,1,"P0.7 subtype helper is static")
            local item_id=args[1]
            calls[#calls + 1] = "subtype:" .. tostring(item_id)
            return spec.subtypes and spec.subtypes[item_id] or item_id
        end},
        debug_logger=function(...)
            debug_calls[#debug_calls + 1] = table.pack(...)
            calls[#calls + 1] = "debug"
        end,
        error_logger=function(...)
            error_calls[#error_calls + 1] = table.pack(...)
            calls[#calls + 1] = "error"
        end,
    }
    return module,environment,dependencies,calls,abnormalities,debug_calls,error_calls
end

-- P0.7/P0.7.0 vectors follow the nested closure's slot/config/match gates and
-- the root's left/right deduplication, location order, and max-key reduction.
do
    local module,env,deps,calls,abnormalities,debug_calls,error_calls=bullet_fixture()
    Product._CheckBullet(module,env,deps)
    eq(calls[1],"group","slot group is captured once before slot traversal")
    eq(calls[2],"slot:left"); eq(calls[4],"slot:right"); eq(calls[6],"slot:pistol")
    eq(#abnormalities,0,"empty slots produce no abnormal")

    module,env,deps,calls,abnormalities=bullet_fixture({items={left={id="rifle"}},checks={}})
    Product._CheckBullet(module,env,deps)
    eq(#abnormalities,0,"missing check data skips this weapon")
    truth(not table.concat(calls,","):find("round:",1,true),"missing check data does not round")

    module,env,deps,calls,abnormalities=bullet_fixture({items={left={id="rifle"}},checks={rifle={switch=false,checkValue=5}}})
    Product._CheckBullet(module,env,deps)
    eq(#abnormalities,0,"disabled check data skips this weapon")
    truth(not table.concat(calls,","):find("match:",1,true),"disabled check does not query matched bullets")

    module,env,deps,calls,abnormalities,debug_calls,error_calls=bullet_fixture({
        items={left={id="rifle"}},checks={rifle={switch=true,checkValue=-1,key=2,abnormalDesc="negative"}},
    })
    Product._CheckBullet(module,env,deps)
    eq(#abnormalities,0,"negative rounded requirement does not add abnormal")
    eq(#error_calls,1,"negative requirement calls the captured error logger")
    eq(error_calls[1][1],"CheckEquipLogic._CheckBullet checkValue 小于0！！！")
    eq(error_calls[1][2],"rifle")
    eq(#debug_calls,0,"negative requirement skips debug and match calls")

    module,env,deps,calls,abnormalities,debug_calls=bullet_fixture({
        items={left={id="rifle"}},
        checks={rifle={switch=true,checkValue=9.6,key=11,abnormalDesc="short"}},
        counts={rifle=10},round=function(value) eq(value,9.6); return 10 end,
    })
    Product._CheckBullet(module,env,deps)
    eq(#abnormalities,0,"matched count equal to rounded requirement passes")
    eq(#debug_calls,1,"enabled nonnegative check logs before the matched count call")
    eq(debug_calls[1].n,4,"debug logger receives four bytecode arguments")
    eq(debug_calls[1][1],"[Debug] Get Value = "); eq(debug_calls[1][2],10)
    eq(debug_calls[1][3],"checkValue = "); eq(debug_calls[1][4],9.6)

    module,env,deps,calls,abnormalities=bullet_fixture({
        items={left={id="left-rifle"},right={id="right-rifle"}},
        subtypes={ ["left-rifle"]="rifle",["right-rifle"]="rifle" },
        checks={rifle={switch=true,checkValue=10,key=32,abnormalDesc="short"}},
        counts={["left-rifle"]=6,["right-rifle"]=4},
    })
    Product._CheckBullet(module,env,deps)
    eq(#abnormalities,1,"two deficient weapons emit one abnormal")
    local abnormal=abnormalities[1]
    eq(abnormal.key,32,"failed slot key initializes the shared maximum")
    eq(abnormal.abnormalType,"lack-bullet")
    eq(table.concat(abnormal.param.abnormalTypeList,","),"left,right","both same-subtype weapon slots are included")
    eq(abnormal.loc,"short Rifle ammo x10","same-subtype pair uses only the left slot's description")

    module,env,deps,calls,abnormalities=bullet_fixture({
        items={left={id="left-rifle"},right={id="right-rifle"},pistol={id="sidearm"}},
        subtypes={ ["left-rifle"]="rifle",["right-rifle"]="rifle2",sidearm="pistol" },
        checks={
            rifle={switch=true,checkValue=10,key=5,abnormalDesc="left short"},
            rifle2={switch=true,checkValue=8,key=19,abnormalDesc="right short"},
            pistol={switch=true,checkValue=6,key=41,abnormalDesc="pistol short"},
        },
        counts={["left-rifle"]=1,["right-rifle"]=2,sidearm=0},
        names={rifle="Rifle A",rifle2="Rifle B",pistol="Pistol"},
    })
    Product._CheckBullet(module,env,deps)
    eq(#abnormalities,1,"distinct rifles and pistol are combined in one abnormal")
    abnormal=abnormalities[1]
    eq(abnormal.key,41,"key is maximum over all deficient slots")
    eq(table.concat(abnormal.param.abnormalTypeList,","),"left,right,pistol","slot types keep left/right/pistol order")
    eq(abnormal.loc,"left short Rifle A x10 | right short Rifle B x8 | pistol short Pistol x6",
        "distinct descriptions preserve root append order")
end

local function durability_fixture(spec)
    spec=spec or {}
    local calls,abnormalities,decimal_inputs,rounded_inputs,errors={}, {}, {}, {}, {}
    local items=spec.items or {}
    local checks=spec.checks or {}
    local slot_group=spec.slot_group or "durability-group"
    local field
    field={
        GetEquipmentCheckData=function(self,kind,slot_type)
            eq(self,field,"P0.8 check-data receiver")
            eq(kind,"insufficient-durability","P0.8 abnormal category")
            calls[#calls+1]="check:"..tostring(slot_type)
            return checks[slot_type]
        end,
        AddEquipAbnormal=function(self,row)
            eq(self,field,"P0.8 abnormal receiver")
            calls[#calls+1]="add"
            abnormalities[#abnormalities+1]=row
        end,
    }
    local inventory
    inventory={GetSlot=function(self,slot_type,group)
        eq(self,inventory,"P0.8 inventory receiver")
        eq(group,slot_group,"P0.8 captured group")
        calls[#calls+1]="slot:"..tostring(slot_type)
        local slot={GetEquipItem=function()
            calls[#calls+1]="item:"..tostring(slot_type)
            return items[slot_type]
        end}
        return slot
    end}
    local armed_server
    armed_server={GetCurSlotGroupId=function(self)
        eq(self,armed_server,"P0.8 armed-force server receiver")
        calls[#calls+1]="group"
        return slot_group
    end}
    local env={
        Server={ArmedForceServer=armed_server,InventoryServer=inventory},
        ESlotType={Helmet="helmet",BreastPlate="breastplate"},
        EFeatureType={Equipment="equipment"},
        Module={ArmedForce={Field=field,Config={EAbnormalType={InsufficientDurability="insufficient-durability"}}},
            Inventory={Config={SlotNameMapping={helmet="Head",breastplate="Chest"}}}},
        MathUtil={
            GetTheSecondDecimal=function(value,...)
                local tail=table.pack(...)
                calls[#calls+1]="decimal:"..tostring(value)
                decimal_inputs[#decimal_inputs+1]={value=value,tail=tail}
                if spec.decimal then return spec.decimal(value,#decimal_inputs,table.unpack(tail,1,tail.n)) end
                return value -- fixture identity; engine helper behavior is not inlined or assumed
            end,
            GetRoundingNum=function(value)
                calls[#calls+1]="round:"..tostring(value)
                rounded_inputs[#rounded_inputs+1]=value
                if spec.round then return spec.round(value) end
                return value -- fixture identity; source forwards the engine helper result
            end,
        },
        string={format=function(description,...)
            local args=table.pack(...)
            calls[#calls+1]="format:"..tostring(description)
            if spec.format then return spec.format(description,args) end
            return string.format(description,table.unpack(args,1,args.n))
        end},
        CommonConfig={Loc={Comma=" | "}},
        table={insert=table.insert,concat=table.concat},
        math=math,tostring=tostring,
    }
    for slot_type,item in pairs(items) do
        item.GetFeature=function(self,feature_type)
            eq(self,item,"P0.8 item feature receiver")
            eq(feature_type,"equipment","P0.8 requests Equipment feature")
            calls[#calls+1]="feature:"..tostring(slot_type)
            if item.missing_feature then return nil end
            local feature={}
            feature.IsHelmet=function()
                calls[#calls+1]="is-helmet:"..tostring(slot_type)
                return item.is_helmet
            end
            feature.IsBreastPlate=function()
                calls[#calls+1]="is-breastplate:"..tostring(slot_type)
                return item.is_breastplate
            end
            feature.GetDurabilityPercent=function()
                calls[#calls+1]="durability:"..tostring(slot_type)
                return item.durability,item.durability_tail
            end
            return feature
        end
    end
    local module={}
    local dependencies={error_logger=function(...)
        errors[#errors+1]=table.pack(...)
        calls[#calls+1]="error"
    end}
    return module,env,dependencies,calls,abnormalities,decimal_inputs,rounded_inputs,errors
end

-- P0.8/P0.8.0 follow the bytecode armor-feature gates, nonnegative/switch
-- checks, two-decimal inclusive threshold, per-slot formatting, and max-key
-- aggregation. `GetDurabilityPercent` multiple returns are forwarded to the
-- captured decimal helper, as in the open-result CALL instruction.
do
    local module,env,deps,calls,abnormalities=durability_fixture()
    eq(select("#",Product._CheckDurabulity(module,env,deps)),0,"P0.8 has no explicit return")
    eq(calls[1],"group"); eq(calls[2],"slot:helmet"); eq(calls[4],"slot:breastplate")
    eq(#abnormalities,0,"empty armor slots add nothing")

    module,env,deps,calls,abnormalities=durability_fixture({
        items={helmet={id="hat",missing_feature=true}},
    })
    Product._CheckDurabulity(module,env,deps)
    eq(#abnormalities,0,"item without Equipment feature passes")
    truth(not table.concat(calls,","):find("check:",1,true),"missing feature skips config lookup")

    module,env,deps,calls,abnormalities=durability_fixture({
        items={helmet={id="hat",is_helmet=false,is_breastplate=false}},
        checks={helmet={switch=true,checkValue=0.4,key=4,abnormalDesc="bad %s %d"}},
    })
    Product._CheckDurabulity(module,env,deps)
    eq(table.concat(calls,","):find("is-helmet:helmet,is-breastplate:helmet,slot:breastplate",1,true)~=nil,
        true,"non-armor feature checks IsHelmet then IsBreastPlate and skips config")
    eq(#abnormalities,0,"non-helmet/non-breastplate item passes")

    module,env,deps,calls,abnormalities=durability_fixture({
        items={helmet={id="hat",is_helmet=true}},checks={},
    })
    Product._CheckDurabulity(module,env,deps)
    eq(#abnormalities,0,"missing durability config passes")

    module,env,deps,calls,abnormalities,_,_,errors=durability_fixture({
        items={helmet={id="hat",is_helmet=true}},
        checks={helmet={switch=false,checkValue=0.4,key=4,abnormalDesc="bad %s %d"}},
    })
    Product._CheckDurabulity(module,env,deps)
    eq(#abnormalities,0,"disabled durability config passes")
    eq(#errors,0,"disabled config does not call captured error logger")
    truth(not table.concat(calls,","):find("durability:",1,true),"disabled config skips durability reads")

    module,env,deps,calls,abnormalities,_,_,errors=durability_fixture({
        items={helmet={id="hat",is_helmet=true}},
        checks={helmet={switch=true,checkValue=-0.1,key=4,abnormalDesc="bad %s %d"}},
    })
    Product._CheckDurabulity(module,env,deps)
    eq(#abnormalities,0,"negative durability threshold passes after logging")
    eq(#errors,1,"negative threshold uses the captured error logger")
    eq(errors[1][1],"CheckEquipLogic._CheckDurabulity checkValue 小于0！！！")
    eq(errors[1][2],"helmet")
    truth(not table.concat(calls,","):find("decimal:",1,true),"negative branch skips decimal helpers")

    module,env,deps,calls,abnormalities,decimal_inputs,rounded_inputs=durability_fixture({
        items={helmet={id="hat",is_helmet=true,durability=0.42,durability_tail="tail"}},
        checks={helmet={switch=true,checkValue=0.419,key=17,abnormalDesc="%s durability <= %d"}},
        decimal=function(value,index)
            if index==1 then eq(value,0.42); return 0.42 end
            eq(index,2); eq(value,0.419); return 0.42
        end,
        round=function(value) eq(value,41.9,"bytecode passes checkValue*100 to rounding helper"); return 42,"round-tail" end,
        format=function(description,args)
            eq(description,"%s durability <= %d")
            eq(args.n,3,"all rounding-helper returns are passed to string.format")
            eq(args[1],"Head"); eq(args[2],42); eq(args[3],"round-tail")
            return "Head durability <= 42"
        end,
    })
    Product._CheckDurabulity(module,env,deps)
    eq(#decimal_inputs,2,"current and configured durability are normalized separately")
    eq(decimal_inputs[1].value,0.42); eq(decimal_inputs[1].tail.n,1)
    eq(decimal_inputs[1].tail[1],"tail","all open GetDurabilityPercent returns reach the decimal helper")
    eq(decimal_inputs[2].value,0.419,"threshold normalization follows current durability normalization")
    eq(#rounded_inputs,1); eq(rounded_inputs[1],41.9,"format threshold is multiplied by 100 before rounding")
    eq(#abnormalities,1,"rounded-equal durability threshold fails inclusively")
    local abnormal=abnormalities[1]
    eq(abnormal.key,17); eq(abnormal.abnormalType,"insufficient-durability")
    eq(abnormal.loc,"Head durability <= 42")
    eq(table.concat(abnormal.param.abnormalTypeList,","),"helmet")

    module,env,deps,calls,abnormalities=durability_fixture({
        items={
            helmet={id="hat",is_helmet=true,durability=0.2},
            breastplate={id="vest",is_breastplate=true,durability=0.4},
        },
        checks={
            helmet={switch=true,checkValue=0.6,key=7,abnormalDesc="%s low %d"},
            breastplate={switch=true,checkValue=0.5,key=33,abnormalDesc="%s low %d"},
        },
    })
    Product._CheckDurabulity(module,env,deps)
    eq(#abnormalities,1,"two failing armor rows produce one abnormal")
    abnormal=abnormalities[1]
    eq(abnormal.key,33,"shared key is maximum over failing armor rows")
    eq(table.concat(abnormal.param.abnormalTypeList,","),"helmet,breastplate","armor enum order preserved")
    eq(abnormal.loc,"Head low 60 | Chest low 50","all failing locations retain helmet/breastplate order")

    module,env,deps,calls,abnormalities=durability_fixture({
        items={breastplate={id="vest",is_breastplate=true,durability=0.51}},
        checks={breastplate={switch=true,checkValue=0.5,key=33,abnormalDesc="%s low %d"}},
    })
    Product._CheckDurabulity(module,env,deps)
    eq(#abnormalities,0,"durability strictly above rounded threshold passes")
end

-- P0.7/P0.8 execute SELF AddEquipAbnormal before the later abnormal-type
-- lookup. Preserve the selected function if that lookup mutates the Field.
do
    local function verify_saved_add(method_name,fixture,field_name,check_kind)
        local module,env,deps,calls,abnormalities=fixture()
        local field=env.Module.ArmedForce.Field
        local selected_calls,replacement_calls=0,0
        field.AddEquipAbnormal=function(self,row)
            eq(self,field,"captured AddEquipAbnormal receiver")
            selected_calls=selected_calls+1
            abnormalities[#abnormalities+1]=row
        end
        local replacement=function() replacement_calls=replacement_calls+1 end
        local reads=0
        env.Module.ArmedForce.Config.EAbnormalType=setmetatable({}, {__index=function(_,key)
            eq(key,field_name,"bytecode abnormal type lookup")
            reads=reads+1
            if reads==2 then field.AddEquipAbnormal=replacement end
            return reads==1 and check_kind or "captured-type"
        end})
        Product[method_name](module,env,deps)
        eq(reads,2,"one check-row lookup and one abnormal-construction lookup")
        eq(selected_calls,1,"P0.7/P0.8 call the function captured by SELF")
        eq(replacement_calls,0,"later config access cannot replace the saved method")
        eq(abnormalities[1].abnormalType,"captured-type")
        truth(abnormalities[1].param.abnormalTypeList[1]~=nil,"failure slot is retained")
    end

    verify_saved_add("_CheckBullet",function()
        return bullet_fixture({items={left={id="rifle"}},
            checks={rifle={switch=true,checkValue=2,key=7,abnormalDesc="short"}},
            counts={rifle=0}})
    end,"LackBullet","lack-bullet")

    verify_saved_add("_CheckDurabulity",function()
        return durability_fixture({items={helmet={is_helmet=true,durability=0.1}},
            checks={helmet={switch=true,checkValue=0.5,key=9,abnormalDesc="%s low %d"}},
            round=function() return 50 end})
    end,"InsufficientDurability","insufficient-durability")
end

print("product-module: ok")

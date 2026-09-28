local root=assert(arg[1])
local S={}
assert(loadfile(root.."/src/spectra/product_context.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module_bridge.lua"))(S)
local Bridge=S.ProductModuleBridge
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end

local function context_fixture(environment)
    local noop=function() end
    return {
        globals=environment,
        product={},
        debug_logger=noop,info_logger=noop,error_logger=noop,
        item_helper={GetSubTypeById=function(v) return v end},
        item_config_tool={},weapon_assembly_tool={},weapon_helper_tool={},item_base_tool={},
        armed_force_expired_logic={},ammo_data_manager_module={},ammo_data_manager={},
    }
end

local function product_fixture(payload_calls)
    local p={}
    for _,name in ipairs(Bridge.METHODS) do
        p[name]=function(...)
            payload_calls[#payload_calls+1]={name,table.pack(...)}
            return "payload:"..name
        end
    end
    -- Downstream root method is still payload-owned at this checkpoint, but
    -- P0.7 no longer captures the payload table itself. It resolves this field
    -- dynamically on whichever product table owns the source wrapper.
    p.GetMatchBulletNumByWeaponItem=function() return 0 end
    return p
end

local calls={}
local item=nil
local environment={
    Server={
        ArmedForceServer={GetCurSlotGroupId=function() return "group" end},
        InventoryServer={GetSlot=function(_,slot_type,group)
            calls[#calls+1]="slot:"..tostring(slot_type)..":"..tostring(group)
            return {GetEquipItem=function() return item end}
        end},
    },
}

-- All P0.0..P0.15 public methods install from one source context. No payload
-- upvalue extraction is involved.
do
    Bridge.restore_original()
    local payload_calls={}
    local product=product_fixture(payload_calls)
    local originals={}; for _,name in ipairs(Bridge.METHODS) do originals[name]=product[name] end
    local context=context_fixture(environment)
    local ok,report=Bridge.install(product,{context=context,environment=environment})
    truth(ok,"source-context install")
    eq(report.source_only_dependency,true,"source-only dependency report")
    eq(report.payload_upvalue_introspection,false,"payload upvalue introspection disabled")
    local status=Bridge.status()
    eq(status.source_owned_root_methods,16,"P0.0..P0.15 public methods source-owned")
    eq(status.source_only_dependency,true,"status source-only dependency")
    for _,name in ipairs(Bridge.METHODS) do truth(product[name]~=originals[name],name.." replaced") end

    local result=table.pack(product.CheckEquipSlotEmpty("helmet"))
    eq(result.n,1,"P0.9 return arity"); eq(result[1],true,"P0.9 source result")
    eq(#payload_calls,0,"source P0.9 must not call saved payload method")

    local manager={}
    manager.CheckMainFlowSOL=function() return true end
    manager.GetCurrentGameFlow=function() return "flow" end
    environment.Facade={GameFlowManager=manager}
    environment.EGameFlowStageType={Lobby="lobby"}
    local child_calls=0
    product._CheckEquipmentValue=function(...) eq(select("#",...),0,"P0.11 R3 child has no self"); child_calls=child_calls+1 end
    local fetch=table.pack(product.DynamicGuidPriceFinishFetch(true))
    eq(fetch.n,0,"P0.11 bridge return arity")
    eq(child_calls,1,"P0.11 bridge source R3 child call")
    eq(#payload_calls,0,"source P0.11 must not call saved payload method")

    Bridge.restore_original()

    local source_calls={}
    local raid_product={}
    for _,name in ipairs(Bridge.METHODS) do
        raid_product[name]=function() payload_calls[#payload_calls+1]=name end
    end
    raid_product.GetMatchBulletNumByWeaponItem=function(...)
        local args=table.pack(...); eq(args.n,2,"P0.12 match helper ABI")
        source_calls[#source_calls+1]="match"
        return 4
    end
    local info_rows={}
    local raid_context=context_fixture(environment); raid_context.product=raid_product
    local p13_assembly_calls,p13_ammo_calls=0,0
    raid_context.weapon_assembly_tool={GetWeaponBulletNumAndCapacity=function(...)
        local args=table.pack(...)
        eq(args.n,3,"P0.13 bridge forwards raw property open tuple")
        eq(args[1],"raw-a"); eq(args[2],nil); eq(args[3],"raw-c")
        p13_assembly_calls=p13_assembly_calls+1
        return 100,777
    end}
    raid_context.ammo_data_manager={IsMatchWeapon=function() p13_ammo_calls=p13_ammo_calls+1; return false end}
    raid_context.error_logger=function(...) source_calls[#source_calls+1]="error" end
    raid_context.info_logger=function(...) info_rows[#info_rows+1]=table.pack(...) end
    local raid_field={GetRaidBulletCheckNum=function() return 3 end}
    environment.Server={
        ArmedForceServer={GetCurSlotGroupId=function() return "raid-g" end},
        InventoryServer={GetSlot=function(_,slot_type,group)
            eq(group,"raid-g"); source_calls[#source_calls+1]="slot:"..tostring(slot_type)
            return {GetEquipItem=function()
                return {id=1234001,IsWeapon=function() return true end,
                    GetRawPropInfo=function() return "raw-a",nil,"raw-c" end}
            end}
        end},
    }
    environment.ESlotType={MainWeaponLeft="left",MainWeaponRight="right",Pistrol="pistol"}
    environment.Module={ArmedForce={Field=raid_field}}
    environment.weaponPrefixID="wp"
    environment.ipairs=ipairs
    environment.tostring=tostring
    environment.tonumber=tonumber
    environment.string={sub=string.sub,format=string.format}
    local raid_ok=Bridge.install(raid_product,{context=raid_context,environment=environment})
    truth(raid_ok,"P0.12 bridge source install")
    local raid_result=table.pack(raid_product.CheckRaidBulletEnough("raid-mode"))
    eq(raid_result.n,2,"P0.12 bridge return arity")
    eq(raid_result[1],true,"P0.12 bridge sufficient ammo result")
    eq(next(raid_result[2]),nil,"P0.12 bridge no abnormal for strict greater")
    eq(#info_rows,4,"P0.12 info log per weapon plus summary")
    eq(p13_assembly_calls,3,"P0.13 WeaponAssemblyTool runs once per weapon slot")
    eq(p13_ammo_calls,0,"P0.13 ammo manager skips non-bullets on empty slots")
    eq(table.concat(source_calls,","),"slot:left,slot:right,slot:pistol",
        "P0.12 bridge slot order with source P0.13 late helper")
    eq(#payload_calls,0,"P0.12 bridge never calls original methods")

    Bridge.restore_original()
    local p13_source_calls={}
    local p13_product={}
    for _,name in ipairs(Bridge.METHODS) do p13_product[name]=function() payload_calls[#payload_calls+1]=name end end
    local p13_asm_calls=0
    local p13_context=context_fixture(environment); p13_context.product=p13_product
    p13_context.weapon_assembly_tool={GetWeaponBulletNumAndCapacity=function(...)
        local args=table.pack(...)
        eq(args.n,3,"P0.13 bridge raw-property open tuple")
        eq(args[1],"raw-a"); eq(args[2],nil); eq(args[3],"raw-c")
        p13_asm_calls=p13_asm_calls+1
        return 6,999
    end}
    p13_context.ammo_data_manager={IsMatchWeapon=function(self,weapon_id,bullet_id)
        eq(weapon_id,"weapon-13-id"); p13_source_calls[#p13_source_calls+1]="match:"..bullet_id
        return bullet_id=="box-bullet"
    end}
    local p13_slot_types={"ChestHangingContainer","BagContainer","Pocket","SafeBoxContainer"}
    environment.ESlotType={ChestHangingContainer=p13_slot_types[1],BagContainer=p13_slot_types[2],Pocket=p13_slot_types[3],SafeBoxContainer=p13_slot_types[4]}
    environment.Server.InventoryServer.GetSlot=function(_,slot_type,group)
        eq(group,"p13-group"); p13_source_calls[#p13_source_calls+1]="slot:"..slot_type
        return {GetItems=function() return {{id="box-bullet",num=3,IsBullet=function() return true end}} end}
    end
    local p13_ok=Bridge.install(p13_product,{context=p13_context,environment=environment})
    truth(p13_ok,"P0.13 source bridge install")
    local weapon_item={id="weapon-13-id",IsWeapon=function() return true end,
        GetRawPropInfo=function() return "raw-a",nil,"raw-c" end}
    local p13_result=table.pack(p13_product.GetMatchBulletNumByWeaponItem(weapon_item,"p13-group"))
    eq(p13_result.n,1,"P0.13 bridge return arity")
    eq(p13_result[1],18,"P0.13 bridge base and four ammo-stack counts")
    eq(p13_asm_calls,1)
    eq(table.concat(p13_source_calls,","),"slot:ChestHangingContainer,match:box-bullet,slot:BagContainer,match:box-bullet,slot:Pocket,match:box-bullet,slot:SafeBoxContainer,match:box-bullet")
    eq(#payload_calls,0,"P0.13 bridge must not call original payload methods")
    Bridge.restore_original()

    Bridge.restore_original()
    for _,name in ipairs(Bridge.METHODS) do eq(product[name],originals[name],name.." restored") end
end

-- Invalid source context is rejected before any target write.
do
    Bridge.restore_original()
    local payload_calls={}
    local product=product_fixture(payload_calls)
    local originals={}; for _,name in ipairs(Bridge.METHODS) do originals[name]=product[name] end
    local bad=context_fixture(environment); bad.error_logger=nil
    local ok=Bridge.install(product,{context=bad,environment=environment})
    eq(ok,false,"invalid context rejected")
    for _,name in ipairs(Bridge.METHODS) do eq(product[name],originals[name],name.." unchanged") end
end

-- A halfway install error restores every method already written.
do
    Bridge.restore_original()
    local payload_calls={}
    local product=product_fixture(payload_calls)
    local originals={}; for _,name in ipairs(Bridge.METHODS) do originals[name]=product[name] end
    local writes=0
    local ok=Bridge.install(product,{context=context_fixture(environment),environment=environment,
        set_method=function(target,name,value)
            writes=writes+1
            if writes==6 then error("halfway") end
            rawset(target,name,value)
        end})
    eq(ok,false,"halfway install failure")
    for _,name in ipairs(Bridge.METHODS) do eq(product[name],originals[name],name.." rollback") end
    eq(Bridge.status().installed,false,"rollback clears install state")
end

-- A source exception remains visible and does not retry the payload closure.
do
    Bridge.restore_original()
    local payload_calls={}
    local product=product_fixture(payload_calls)
    local side_effects=0
    local failing_environment={
        Server={
            ArmedForceServer={GetCurSlotGroupId=function() return "g" end},
            InventoryServer={GetSlot=function()
                side_effects=side_effects+1
                error("source slot failure")
            end},
        },
    }
    truth(Bridge.install(product,{context=context_fixture(failing_environment),environment=failing_environment}),"install for failure path")
    local ok=pcall(product.CheckEquipSlotEmpty,"helmet")
    eq(ok,false,"source exception propagated")
    eq(side_effects,1,"source side effect attempted once")
    eq(#payload_calls,0,"payload method not retried")
    truth(Bridge.status().last_error:find("source slot failure",1,true)~=nil,"source error recorded")
    Bridge.restore_original()
end

local bridge_text=assert(io.open(root.."/src/spectra/product_module_bridge.lua","rb")):read("*a")
eq(bridge_text:find("debug.getupvalue",1,true),nil,"bridge must not contain payload closure introspection")
print("product-module-bridge: ok")

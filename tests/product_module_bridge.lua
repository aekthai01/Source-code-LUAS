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

-- All P0.0..P0.10 public methods install from one source context. No payload
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
    eq(status.source_owned_root_methods,11,"P0.0..P0.10 public methods source-owned")
    eq(status.source_only_dependency,true,"status source-only dependency")
    for _,name in ipairs(Bridge.METHODS) do truth(product[name]~=originals[name],name.." replaced") end

    local result=table.pack(product.CheckEquipSlotEmpty("helmet"))
    eq(result.n,1,"P0.9 return arity"); eq(result[1],true,"P0.9 source result")
    eq(#payload_calls,0,"source P0.9 must not call saved payload method")

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

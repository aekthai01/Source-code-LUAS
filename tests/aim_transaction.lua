local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_mutation.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_bones.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_chain.lua"))(S)
assert(loadfile(root .. "/src/spectra/feature_control.lua"))(S)
S.Runtime = { delay=function(_, fn) return fn and true or false end }
S.AimRefresh = { init_current_weapon=function() return true end, refresh_methods=function() return true end }
S.AimRuntime = { set_native_aim_assist=function() return true end, set_fire_assisted_aim_debug=function() return true end }
assert(loadfile(root .. "/src/spectra/payload_feature_bridge.lua"))(S)

local Mutation, AimMutation, AimBones, Bridge = S.MutationRuntime, S.AimMutation, S.AimBones, S.PayloadFeatureBridge
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local fallback_calls = 0
local payload_feature = function(feature, enabled)
    fallback_calls = fallback_calls + 1
    return "payload:" .. tostring(feature) .. ":" .. tostring(enabled)
end
local payload_aim = function() return "payload-aim" end

local function reset()
    Bridge.restore_original()
    fallback_calls = 0
    _G.set_dongdong_feature_config = payload_feature
    _G.set_dongdong_aim_part = payload_aim
    _G.custom_dongdong_toggle_state = {aim=false,anti_shake=false,no_recoil=false,converge=false}
    _G.custom_dongdong_feature_snapshots = nil
    _G.custom_dongdong_bone_array_snapshots = nil
    _G.custom_dongdong_bone_name_pool = nil
    _G.custom_aim_speed=50; _G.custom_aim_range=90; _G.custom_aim_distance=150; _G.custom_aim_lock_time=1
end

local function expose(target, row)
    local wanted = Mutation.normalize_identifier(target)
    local table_value = { Default = row }
    Mutation.get_data_table = function(name)
        local normalized = Mutation.normalize_identifier(name)
        if normalized:find(wanted, 1, true) then return table_value end
        return nil
    end
    return table_value
end

local real_get_data_table = Mutation.get_data_table
local real_snapshot_set = Mutation.snapshot_set
local real_restore_feature = Mutation.restore_feature_snapshot
local real_restore_bones = Mutation.restore_bone_array_snapshots
local real_array_set_verified = Mutation.array_set_verified
local real_restore_binding = Mutation.restore_binding
local real_replacement = AimMutation.replacement
local real_patch_bones = AimBones.patch_row

-- P65 decline is not a transaction failure.
do
    reset(); local row={bTakeEffect=false}; expose("WeaponAimAssistorTable", row)
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install decline")
    eq(_G.set_dongdong_feature_config("aim",true), true, "decline source result")
    eq(row.bTakeEffect,false,"ordinary fire decline unchanged")
    eq(fallback_calls,0,"decline must not fallback")
end

-- Successful source write snapshots and restores on disable.
do
    reset(); local row={ConeHeightBase=0}; expose("WeaponAimAssistorTableForGamepad", row)
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install success")
    eq(_G.set_dongdong_feature_config("aim",true), true, "patch source result")
    eq(row.ConeHeightBase,3333,"source profile patch")
    eq(_G.set_dongdong_feature_config("aim",false), true, "disable source result")
    eq(row.ConeHeightBase,0,"disable restores source write")
    eq(fallback_calls,0,"successful patch must not fallback")
end

-- A write that records/mutates but reports failure is rolled back before payload fallback.
do
    reset(); local row={ConeHeightBase=0}; expose("WeaponAimAssistorTableForGamepad", row)
    Mutation.snapshot_set=function(...)
        real_snapshot_set(...)
        return false
    end
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install write failure")
    eq(_G.set_dongdong_feature_config("aim",true), "payload:aim:true", "write failure fallback")
    eq(row.ConeHeightBase,0,"failed write rolled back")
    truth(type(_G.custom_dongdong_feature_snapshots)=="table" and _G.custom_dongdong_feature_snapshots.aim==nil,
        "failed write leaves no aim snapshot")
    eq(fallback_calls,1,"write failure payload fallback once")
    Mutation.snapshot_set=real_snapshot_set
end

-- The original restorer reports success after any one record restores. A
-- remaining modified field must still block delegation despite that result.
do
    reset(); local row={EnableDistanceMin=9,EnableDistanceMax=9}; expose("WeaponAssistedAimingTable", row)
    local writes=0
    Mutation.snapshot_set=function(...)
        writes=writes+1
        local ok=real_snapshot_set(...)
        if writes==2 then return false end
        return ok
    end
    Mutation.restore_feature_snapshot=function(state, feature)
        if feature=="aim" and type(state.custom_dongdong_feature_snapshots)=="table"
            and type(state.custom_dongdong_feature_snapshots.aim)=="table" then
            local snapshot=state.custom_dongdong_feature_snapshots.aim
            snapshot.records[1].object[snapshot.records[1].key]=snapshot.records[1].value
            state.custom_dongdong_feature_snapshots.aim=nil
            return true
        end
        return real_restore_feature(state, feature)
    end
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install partial-restore fixture")
    eq(_G.set_dongdong_feature_config("aim",true), false, "partial restore blocks fallback")
    eq(fallback_calls,0,"no payload call with a modified field")
    truth(type(_G.custom_dongdong_feature_snapshots.aim)=="table", "retain partially restored records")
    Mutation.snapshot_set=real_snapshot_set
    Mutation.restore_feature_snapshot=real_restore_feature
end

local function begin_bone_rollback(row)
    expose("WeaponAimAssistorTableForGamepad", row)
    Mutation.snapshot_set=function(state, feature, owner, key, value)
        real_snapshot_set(state, feature, owner, key, value)
        if feature=="aim" and key=="ConeHeightBase" then return false end
        return true
    end
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install bone rollback fixture")
end

local function assert_bone_rollback_blocked(row, label)
    eq(_G.set_dongdong_feature_config("aim",true), false, label .. " result")
    eq(fallback_calls,0,label .. " must block payload fallback")
    local snapshots=_G.custom_dongdong_bone_array_snapshots
    truth(type(snapshots)=="table" and #snapshots.records==2,label .. " retains both bone records")
    truth(type(_G.custom_dongdong_bone_name_pool)=="table",label .. " retains bone-name pool")
    truth(Bridge.status().last_error:find("bone rollback incomplete",1,true)~=nil,
        label .. " reports incomplete rollback")
end

-- Two real snapshots are produced (the row array and _Dat array). The first
-- restores while the second remains changed; the original restorer still
-- reports aggregate success because at least one record restored.
do
    reset()
    local row={ConeFilterBones={"Neck","Head"}, _Dat={ConeFilterBones={"Spine2"}}, ConeHeightBase=0}
    begin_bone_rollback(row)
    local direct=row.ConeFilterBones
    Mutation.array_set_verified=function(state,array,index0,exemplar,desired)
        if array==direct and index0==0 and desired=="neck" then return false end
        return real_array_set_verified(state,array,index0,exemplar,desired)
    end
    assert_bone_rollback_blocked(row,"second bone record failure")
    eq(row._Dat.ConeFilterBones[1],"Spine2","first bone record restored")
    truth(row.ConeFilterBones[1]~="Neck","second bone record remains changed for recovery")
    Mutation.array_set_verified=real_array_set_verified
    Mutation.snapshot_set=real_snapshot_set
end

-- Array values can restore while a replaced owner binding cannot. The bridge
-- must verify object identity of every captured binding before fallback.
do
    reset()
    local row={ConeFilterBones={"Neck"}, _Dat={ConeFilterBones={"Spine2"}}, ConeHeightBase=0}
    begin_bone_rollback(row)
    local direct=row.ConeFilterBones
    Mutation.snapshot_set=function(state,feature,owner,key,value)
        real_snapshot_set(state,feature,owner,key,value)
        if feature=="aim" and key=="ConeHeightBase" then
            row.ConeFilterBones={"detached"}
            return false
        end
        return true
    end
    Mutation.restore_binding=function(binding,array)
        if binding.owner==row and binding.key=="ConeFilterBones" then return false end
        return real_restore_binding(binding,array)
    end
    assert_bone_rollback_blocked(row,"bone binding failure")
    eq(direct[1],"Neck","original direct array values restored")
    truth(row.ConeFilterBones~=direct,"failed direct binding remains detectable")
    Mutation.restore_binding=real_restore_binding
    Mutation.snapshot_set=real_snapshot_set
end

-- A correct binding does not make an array safe if one captured index failed
-- to restore. This fixture leaves index zero wrong and lets index one restore.
do
    reset()
    local row={ConeFilterBones={"Neck","Head"}, _Dat={ConeFilterBones={"Spine2"}}, ConeHeightBase=0}
    begin_bone_rollback(row)
    local direct=row.ConeFilterBones
    Mutation.array_set_verified=function(state,array,index0,exemplar,desired)
        if array==direct and index0==0 and desired=="neck" then return false end
        return real_array_set_verified(state,array,index0,exemplar,desired)
    end
    assert_bone_rollback_blocked(row,"bone index failure")
    eq(row.ConeFilterBones,direct,"binding remains attached to captured array")
    truth(row.ConeFilterBones[1]~="Neck","failed index remains detectable")
    eq(row.ConeFilterBones[2],"Head","other index restored")
    Mutation.array_set_verified=real_array_set_verified
    Mutation.snapshot_set=real_snapshot_set
end

-- When every captured array and binding verifies, a safe payload fallback is
-- allowed and the bone snapshot/name pool may be cleared.
do
    reset()
    local row={ConeFilterBones={"Neck"}, _Dat={ConeFilterBones={"Spine2"}}, ConeHeightBase=0}
    begin_bone_rollback(row)
    eq(_G.set_dongdong_feature_config("aim",true),"payload:aim:true","complete rollback fallback")
    eq(fallback_calls,1,"complete rollback delegates once")
    eq(row.ConeFilterBones[1],"Neck","complete rollback restores row array")
    eq(row._Dat.ConeFilterBones[1],"Spine2","complete rollback restores _Dat array")
    eq(_G.custom_dongdong_bone_array_snapshots,nil,"complete rollback clears bone snapshot")
    eq(_G.custom_dongdong_bone_name_pool,nil,"complete rollback clears name pool")
    Mutation.snapshot_set=real_snapshot_set
end

-- Snapshot exception is contained at the transaction boundary and delegates cleanly.
-- If rollback itself fails with recorded writes, payload fallback is unsafe.
do
    reset(); local row={ConeHeightBase=0}; expose("WeaponAimAssistorTableForGamepad", row)
    Mutation.snapshot_set=function(...)
        real_snapshot_set(...)
        return false
    end
    Mutation.restore_feature_snapshot=function(state, feature)
        if feature=="aim" then return false end
        return real_restore_feature(state, feature)
    end
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install failed-restore fixture")
    eq(_G.set_dongdong_feature_config("aim",true), false, "unsafe fallback blocked")
    eq(fallback_calls,0,"no payload call with un-restored source writes")
    truth(type(_G.custom_dongdong_feature_snapshots.aim)=="table", "retain failed snapshot for recovery")
    Mutation.snapshot_set=real_snapshot_set
    Mutation.restore_feature_snapshot=real_restore_feature
end

-- Snapshot exception is contained at the transaction boundary and delegates cleanly.
do
    reset(); local row={ConeHeightBase=0}; expose("WeaponAimAssistorTableForGamepad", row)
    Mutation.snapshot_set=function() error("snapshot failure") end
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install snapshot failure")
    eq(_G.set_dongdong_feature_config("aim",true), "payload:aim:true", "snapshot failure fallback")
    eq(row.ConeHeightBase,0,"snapshot exception does not mutate")
    eq(fallback_calls,1,"snapshot exception payload fallback once")
    Mutation.snapshot_set=real_snapshot_set
end

-- Recursive child exception is promoted after P67's protected row callback.
do
    reset(); local row={ShootingConfig={bTakeEffect=false}}; expose("WeaponAimAssistorTableForGamepad", row)
    AimMutation.replacement=function(state,deps,owner,table_name,field,...)
        if field=="bTakeEffect" then error("recursive child failure") end
        return real_replacement(state,deps,owner,table_name,field,...)
    end
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install recursive failure")
    eq(_G.set_dongdong_feature_config("aim",true), "payload:aim:true", "recursive failure fallback")
    eq(row.ShootingConfig.bTakeEffect,false,"recursive failure leaves child unchanged")
    eq(fallback_calls,1,"recursive failure payload fallback once")
    AimMutation.replacement=real_replacement
end

-- Bone updater exception is transaction failure, not a half-owned row.
do
    reset(); local row={}; expose("WeaponAimAssistorTableForGamepad", row)
    AimBones.patch_row=function() error("bone failure") end
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install bone failure")
    eq(_G.set_dongdong_feature_config("aim",true), "payload:aim:true", "bone failure fallback")
    eq(fallback_calls,1,"bone failure payload fallback once")
    eq(_G.custom_dongdong_bone_array_snapshots,nil,"bone failure clears snapshot state")
    AimBones.patch_row=real_patch_bones
end

-- Partial multi-field mutation is fully restored before fallback.
do
    reset(); local row={EnableDistanceMin=9,EnableDistanceMax=9}; expose("WeaponAssistedAimingTable", row)
    local writes=0
    Mutation.snapshot_set=function(...)
        writes=writes+1
        local ok=real_snapshot_set(...)
        if writes==2 then return false end
        return ok
    end
    truth(Bridge.takeover_after_payload_load({force_aim_takeover=true}), "install partial failure")
    eq(_G.set_dongdong_feature_config("aim",true), "payload:aim:true", "partial failure fallback")
    truth(writes>=2,"partial mutation reached second write")
    eq(row.EnableDistanceMin,9,"partial min restored")
    eq(row.EnableDistanceMax,9,"partial max restored")
    truth(type(_G.custom_dongdong_feature_snapshots)=="table" and _G.custom_dongdong_feature_snapshots.aim==nil,
        "partial failure leaves no aim snapshot")
    eq(fallback_calls,1,"partial failure payload fallback once")
    Mutation.snapshot_set=real_snapshot_set
end

Bridge.restore_original()
Mutation.get_data_table=real_get_data_table
Mutation.snapshot_set=real_snapshot_set
AimMutation.replacement=real_replacement
AimBones.patch_row=real_patch_bones
print("aim-transaction: ok")

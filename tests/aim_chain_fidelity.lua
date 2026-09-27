local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_mutation.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_bones.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_chain.lua"))(S)
local Mutation, Chain, Bones, ABI = S.MutationRuntime, S.AimChain, S.AimBones, S.AimABI
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function near(a,b,m) if type(a)~="number" or math.abs(a-b)>1e-9 then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local state={custom_dongdong_toggle_state={aim=true,anti_shake=false},custom_aim_speed=50,custom_aim_range=90,
    custom_aim_distance=150,custom_aim_lock_time=1,custom_aim_target_part="chest"}
local function deps(extra)
    local d={normalize_identifier=Mutation.normalize_identifier,read_field=ABI.get,
        patch_bones=function(row) return Bones.patch_row(state,row) end,
        snapshot_set=function(feature,owner,key,value) return Mutation.snapshot_set(state,feature,owner,key,value) end}
    if extra then for k,v in pairs(extra) do d[k]=v end end
    return d
end

-- P67 row-name fallback IDs feed P65 profile literals.
local expected={Default=3333,NewRow=45900,NewRow_0=44444,NewRow_1=44444,NewRow_2=44444,NewRow_3=44444}
for row_name,value in pairs(expected) do
    local row={ConeHeightBase=0}
    local owner={[row_name]=row}
    Chain.apply_aim_row(state,deps({patch_bones=function() return false end}),owner,row_name,row,"WeaponAimAssistorTableForGamepad")
    near(row.ConeHeightBase,value,"row fallback "..row_name)
    Mutation.restore_feature_snapshot(state,"aim")
    eq(row.ConeHeightBase,0,"row fallback restore "..row_name)
end

-- P2 semantics are used for AimAssistorId. A dependency that hides the field
-- must force the Default fallback instead of accepting the raw table value.
do
    local row={AimAssistorId=999,ConeHeightBase=0}
    local reads=0
    local d=deps({patch_bones=function() return false end,read_field=function(owner,key)
        reads=reads+1
        if key=="AimAssistorId" then return nil end
        return ABI.get(owner,key)
    end})
    Chain.apply_aim_row(state,d,{Default=row},"Default",row,"WeaponAimAssistorTableForGamepad")
    near(row.ConeHeightBase,3333,"P2 read controls row ID")
    if reads<1 then error("P2 read dependency not used") end
    Mutation.restore_feature_snapshot(state,"aim")
end

-- _Dat bone handling occurs before the recursive field walker and restores cleanly.
do
    local row={_Dat={ConeFilterBones={"Head","Neck"}},ShootingConfig={bTakeEffect=false}}
    Chain.apply_aim_row(state,deps(),{Default=row},"Default",row,"WeaponAimAssistorTableForGamepad")
    eq(row._Dat.ConeFilterBones[1],"Spine2","_Dat bone patch")
    eq(row.ShootingConfig.bTakeEffect,true,"recursive field patch")
    Mutation.restore_feature_snapshot(state,"aim")
    Mutation.restore_bone_array_snapshots(state)
    eq(row._Dat.ConeFilterBones[1],"Head","_Dat bone restore")
    eq(row.ShootingConfig.bTakeEffect,false,"field restore")
end

-- Cycles are deduped by raw table identity; a sibling config is still visited.
do
    local row={ShootingConfig={bTakeEffect=false}}
    row.Self=row
    Chain.apply_aim_row(state,deps({patch_bones=function() return false end}),{Default=row},"Default",row,"WeaponAimAssistorTableForGamepad")
    eq(row.ShootingConfig.bTakeEffect,true,"cycle-safe sibling patch")
    eq(#state.custom_dongdong_feature_snapshots.aim.records,1,"cycle does not duplicate snapshot")
    Mutation.restore_feature_snapshot(state,"aim")
end

-- Recursion stops past depth 13.
do
    local row={}
    local cursor=row
    for i=1,14 do cursor.Node={}; cursor=cursor.Node end
    cursor.ShootingConfig={bTakeEffect=false}
    Chain.apply_aim_row(state,deps({patch_bones=function() return false end}),{Default=row},"Default",row,"WeaponAimAssistorTableForGamepad")
    eq(cursor.ShootingConfig.bTakeEffect,false,"depth 14 is not traversed")
end

-- Bone fields are owned by P63 and excluded from P66 recursion.
do
    local row={ConeFilterBones={ShootingConfig={bTakeEffect=false}}}
    Chain.apply_aim_row(state,deps({patch_bones=function() return false end}),{Default=row},"Default",row,"WeaponAimAssistorTableForGamepad")
    eq(row.ConeFilterBones.ShootingConfig.bTakeEffect,false,"bone subtree skipped")
end

print("aim-chain-fidelity: ok")

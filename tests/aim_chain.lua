local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_mutation.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_bones.lua"))(S)
local mutation, aim, bones = S.MutationRuntime, S.AimMutation, S.AimBones
local row = {ConeFilterBones={"Head","Neck"}, ShootingConfig={PitchFactorAds=0}}
local table_value = {Default=row}
local lookups = 0
local manager = {GetTable=function(_, name)
    lookups=lookups+1
    if name:find("AimAssistorTableForGamepad",1,true) then return table_value end
end}
local previous_facade, previous_toggles = _G.Facade, _G.custom_dongdong_toggle_state
_G.Facade={TableManager=manager}
_G.custom_dongdong_toggle_state={aim=true,anti_shake=false}
_G.custom_aim_target_part="chest"
local bone_calls = 0
local deps = {
    normalize_identifier=mutation.normalize_identifier,
    read_field=mutation.safe_get,
    patch_bones=function(r) bone_calls=bone_calls+1; return bones.patch_row(_G,r) end,
}
local applied=mutation.apply_feature(_G,"aim",{
    aim=function(owner,key,r,name) aim.apply_aim_row(_G,deps,owner,key,r,name) end,
})
assert(applied == true and lookups == #mutation.FEATURE_TABLES.aim)
assert(bone_calls == 1, "raw alias deduplication before P67")
assert(row.ConeFilterBones[1] == "Spine2")
assert(row.ShootingConfig.PitchFactorAds == 1.3, "Default row ID 1 propagated to P65: " .. tostring(row.ShootingConfig.PitchFactorAds))
assert(mutation.restore_feature_snapshot(_G,"aim"))
assert(mutation.restore_bone_array_snapshots(_G))
assert(row.ConeFilterBones[1] == "Head" and row.ShootingConfig.PitchFactorAds == 0)
_G.Facade, _G.custom_dongdong_toggle_state = previous_facade, previous_toggles
_G.custom_aim_target_part=nil
print("aim-chain: ok")

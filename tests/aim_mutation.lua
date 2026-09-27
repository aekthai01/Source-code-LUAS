local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_mutation.lua"))(S)
local M = S.AimMutation
local function eq(a, b, why)
    if a ~= b then error((why or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local state = {custom_dongdong_toggle_state = {anti_shake = true},
    custom_aim_speed = 100, custom_aim_range = 180, custom_aim_distance = 300, custom_aim_lock_time = 50}
local deps = {
    normalize_identifier = function(v) return string.lower(tostring(v)):gsub("[^%w]", "") end,
    read_field = function(row, key) return row[key] end,
}
local function replace(mode, name, field, original, row, row_id)
    state.custom_dongdong_toggle_state.anti_shake = mode == "ads"
    state.custom_dongdong_toggle_state.aim = mode == "fire"
    return M.replacement(state, deps, row or {}, name, field, original, row_id)
end
local name = "WeaponBase/WeaponAimAssistorTable"
local gamepad = "WeaponBase/WeaponAimAssistorTableForGamepad"
local v, patch = replace("ads", name, "bTakeEffect", false)
eq(v, true, "ADS normal enable"); eq(patch, true)
v, patch = replace("ads", gamepad, "bTakeEffect", false)
eq(v, nil, "Gamepad excluded from ordinary ADS path"); eq(patch, false)
v, patch = replace("ads", name, "InRangeB", 9000)
eq(v, 66666, "ADS distance scaling"); eq(patch, true)
v, patch = replace("ads", name, "InRangeB", "9000")
eq(v, nil, "numeric guard"); eq(patch, false)
v, patch = replace("ads", name, "PitchRateHip", 2)
eq(v, nil, "hip rate in ADS"); eq(patch, false)
v, patch = replace("fire", "WeaponBase/WeaponBulletTable", "Radius", 3)
eq(v, 5, "fire bullet threshold"); eq(patch, true)
v, patch = replace("fire", "WeaponBase/WeaponBulletTable", "Radius", 4)
eq(v, nil, "fire bullet threshold above cutoff"); eq(patch, false)
v, patch = replace("fire", "WeaponBase/WeaponAssistedAimingGroupTable", "SingleIdPVE", nil, {SingleId = 1002})
eq(v, 1002, "group linked ID"); eq(patch, true)
v, patch = replace("fire", "WeaponBase/WeaponAssistedAimingGroupTable", "SingleIdPVE", nil, {SingleId = 0})
eq(v, nil, "group invalid ID"); eq(patch, false)
v, patch = replace("fire", "WeaponBase/WeaponAssistedAimingTable", "EnableDistanceMax", 0)
eq(v, 90000, "assisted range"); eq(patch, true)
eq(M.PROFILE_VALUES[1001].coneheightbase, 45900, "bytecode profile 1001")
eq(M.PROFILE_VALUES[1004].shootingconfigrangescaleoutrangeb, 3, "bytecode profile 1004")
-- Independent literal fixtures transcribed from parent R52 profile construction;
-- do not derive expected values from the replacement implementation.
local profile_literals = {
    [1]={coneheightbase=3333,shootingconfigrangescaleinrangeb=33333},
    [1001]={coneheightbase=45900,shootingconfigrangescaleinrangeb=22222},
    [1002]={coneheightbase=44444,crosshairfollowingconfigrangescaleinrangeb=9999},
    [1003]={coneheightbase=44444,crosshairfollowingconfigeffectivefovrangey=1444},
    [11001]={coneheightbase=44444,shootingconfigrangescaleinrangeb=22222},
    [1004]={coneheightbase=44444,shootingconfigrangescaleinrangeb=7000},
}
for id, fields in pairs(profile_literals) do
    for field, literal in pairs(fields) do eq(M.PROFILE_VALUES[id][field],literal,"R52 "..id.." "..field) end
end
for _, setting in ipairs({
    {"custom_aim_speed",1,1},{"custom_aim_speed",50,50},{"custom_aim_speed",100,100},
    {"custom_aim_range",1,1},{"custom_aim_range",90,90},{"custom_aim_range",360,360},
    {"custom_aim_distance",1,1},{"custom_aim_distance",150,150},{"custom_aim_distance",500,500},
    {"custom_aim_lock_time",1,1},{"custom_aim_lock_time",100,100},
}) do
    local saved=state[setting[1]]; state[setting[1]]=tostring(setting[2])
    local cfg=M.settings(state)
    local field=({custom_aim_speed="speed",custom_aim_range="fov",
        custom_aim_distance="distance",custom_aim_lock_time="lock"})[setting[1]]
    eq(cfg[field],setting[3],"string-convertible setting "..setting[1])
    state[setting[1]]=saved
end
state.custom_aim_speed="invalid"; eq(M.settings(state).speed,50,"invalid speed default")
state.custom_aim_speed=nil; eq(M.settings(state).speed,50,"nil speed default")
state.custom_aim_speed=100
eq(M.scale_clamp(nil, 2, 0.001, 1), 0.001, "profile scale fallback")
v, patch = replace("fire", "ShootingConfig", "PitchFactorAds", 0, {}, 1)
eq(v, 2.6, "profile factor by ID"); eq(patch, true)
v, patch = replace("fire", "ShootingConfig", "PitchFactorAds", 0, {}, 99999)
eq(v, nil, "unknown profile ID"); eq(patch, false)
v, patch = replace("fire", "ActiveTrackingConfig", "bTakeEffect", true)
eq(v, false, "tracking disabled"); eq(patch, true)
v, patch = replace("fire", "ShootingConfig", "bTakeEffect", false)
eq(v, true, "shooting enabled"); eq(patch, true)
local branch_literals = {
    {"ads",name,"ConeAngleBase",0,180,true},
    {"ads",name,"ConeHeightBase",0,30000,true},
    {"ads",name,"LockonTime",0,0.001,true},
    {"fire","WeaponBase/WeaponAssistedAimingTable","EnableDistanceMin",7,0,true},
    {"fire","WeaponBase/WeaponAssistedAimingTable","PreventMissNumber",1,12,true},
    {"fire","ActiveTrackingConfig","bTakeEffect",true,false,true},
    {"fire","ZoomingInConfig","bTakeEffect",true,false,true},
    {"fire","CrosshairFollowingConfig","bTakeEffect",false,true,true},
    {"fire","CrosshairDampingConfig","bTakeEffect",false,true,true},
    {"fire",name,"bTakeEffect",false,nil,false},
}
for _, fixture in ipairs(branch_literals) do
    local actual, should_patch=replace(fixture[1],fixture[2],fixture[3],fixture[4])
    eq(actual,fixture[5],"P65 fixture "..fixture[2].."."..fixture[3])
    eq(should_patch,fixture[6],"P65 patch flag "..fixture[3])
end
v, patch = replace("none", name, "bTakeEffect", false)
eq(v, nil, "inactive mode"); eq(patch, false)
state.custom_dongdong_toggle_state.aim = true
local nested = {bTakeEffect = false, ConeFilterBones = {bTakeEffect = false}}
local row = {ShootingConfig = nested}
local seen = {}
M.walk_and_patch(state, deps, row, "ShootingConfig", nested, "WeaponBase/WeaponMainAttributeTable", 0, seen, 1)
eq(nested.bTakeEffect, true, "nested shooting field patched")
eq(nested.ConeFilterBones.bTakeEffect, false, "bone-array subtree excluded")
M.walk_and_patch(state, deps, row, "ShootingConfig", nested, "WeaponBase/WeaponMainAttributeTable", 0, seen, 1)
eq(#state.custom_dongdong_feature_snapshots.aim.records, 1, "one original snapshot")
eq(S.MutationRuntime.restore_feature_snapshot(state, "aim"), true, "restore succeeds")
eq(nested.bTakeEffect, false, "original value restored")
local called_bones = 0
eq(pcall(M.apply_aim_table, state, {
    normalize_identifier=deps.normalize_identifier, read_field=deps.read_field
}, {Default={}}, gamepad), false, "unreconstructed bone dependency blocks caller")
deps.patch_bones = function(_) called_bones = called_bones + 1 end
local table_value = {Default={ShootingConfig={PitchFactorAds=0}}}
eq(M.apply_aim_table(state, deps, table_value, gamepad), true, "aim row visited")
eq(called_bones, 1, "bone updater required once")
eq(table_value.Default.ShootingConfig.PitchFactorAds, 2.6, "row-name profile ID propagated")
eq(S.MutationRuntime.restore_feature_snapshot(state, "aim"), true, "profile row restore")
eq(table_value.Default.ShootingConfig.PitchFactorAds, 0, "profile row original restored")
print("aim-mutation: ok")

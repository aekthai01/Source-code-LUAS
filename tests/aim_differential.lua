local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root .. "/src/spectra/p029_runtime_helpers.lua"))(S)
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_mutation.lua"))(S)
local M, ABI, Mutation = S.AimMutation, S.AimABI, S.MutationRuntime
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function near(a,b,m)
    if type(a)~="number" or math.abs(a-b)>1e-9 then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end
end
local state={custom_aim_speed=50,custom_aim_range=90,custom_aim_distance=150,custom_aim_lock_time=1,
    custom_dongdong_toggle_state={aim=false,anti_shake=false}}
local deps={normalize_identifier=Mutation.normalize_identifier,read_field=ABI.get}
local function replace(mode,name,field,original,row,row_id)
    state.custom_dongdong_toggle_state.aim = mode=="fire"
    state.custom_dongdong_toggle_state.anti_shake = mode=="ads"
    return M.replacement(state,deps,row or {},name,field,original,row_id)
end
local fixtures={
    -- Expected values are transcribed from P0.29.65 branch literals/formulas,
    -- not computed through the source implementation under test.
    {"none","WeaponAimAssistorTable","bTakeEffect",false,nil,nil,false,"inactive"},
    {"ads","WeaponAimAssistorTable","bTakeEffect",false,nil,true,true,"ads enable"},
    {"ads","WeaponAimAssistorTableForGamepad","bTakeEffect",false,nil,nil,false,"gamepad distinct"},
    {"ads","WeaponAimAssistorTable","InRangeB",9000,nil,33333,true,"ads inrange 9000"},
    {"ads","WeaponAimAssistorTable","InRangeB",5500,nil,22222,true,"ads inrange 5500"},
    {"ads","WeaponAimAssistorTable","InRangeB",2800,nil,9999,true,"ads inrange 2800"},
    {"ads","WeaponAimAssistorTable.ShootingConfig","InRangeB",2200,nil,7000,true,"ads shooting 2200"},
    {"ads","WeaponAimAssistorTable","InRangeB",2199,nil,3,true,"ads low inrange"},
    {"ads","WeaponAimAssistorTable","InRangeB","9000",nil,nil,false,"ads numeric guard"},
    {"fire","WeaponBulletTable","Radius",3,nil,5,true,"bullet radius"},
    {"fire","WeaponBulletTable","Radius",4,nil,nil,false,"bullet radius decline"},
    {"fire","WeaponAssistedAimingGroupTable","SingleIdPVE",0,{SingleId=1002},1002,true,"group PVE link"},
    {"fire","WeaponAssistedAimingTable","EnableDistanceMin",7,nil,0,true,"assisted min"},
    {"fire","WeaponAssistedAimingTable","EnableDistanceMax",7,nil,45000,true,"assisted max"},
    {"fire","WeaponAssistedAimingTable","AssistedBoxMinRadius",0,nil,198.9,true,"assisted min radius"},
    {"fire","WeaponAssistedAimingTable","AssistedBoxMaxRadius",0,nil,306,true,"assisted max radius"},
    {"fire","WeaponAssistedAimingTable","AssistedBoxVerticalScale",0,nil,1.35,true,"assisted vertical"},
    {"fire","WeaponAssistedAimingTable","PreventMissAddBulletRadiusDelta",0,nil,382.5,true,"prevent miss radius"},
    {"fire","WeaponAimAssistorTable","bTakeEffect",false,nil,nil,false,"ordinary aim no direct fire field"},
    {"fire","ShootingConfig","bTakeEffect",false,nil,true,true,"shooting enabled"},
    {"fire","CrosshairFollowingConfig","bTakeEffect",false,nil,true,true,"following enabled"},
    {"fire","CrosshairDampingConfig","bTakeEffect",false,nil,true,true,"damping enabled"},
    {"fire","ActiveTrackingConfig","bTakeEffect",true,nil,false,true,"tracking disabled"},
    {"fire","ZoomingInConfig","bTakeEffect",true,nil,false,true,"zoom disabled"},
}
for _,f in ipairs(fixtures) do
    local value,patch=replace(f[1],f[2],f[3],f[4],f[5])
    if type(f[6])=="number" and type(value)=="number" then near(value,f[6],f[8]) else eq(value,f[6],f[8]) end
    eq(patch,f[7],f[8].." patch")
end

local profile_height={Default=3333,NewRow=45900,NewRow_0=44444,NewRow_1=44444,NewRow_2=44444,NewRow_3=44444}
local profile_id={Default=1,NewRow=1001,NewRow_0=1002,NewRow_1=1003,NewRow_2=11001,NewRow_3=1004}
for row_name,expected in pairs(profile_height) do
    local value,patch=replace("fire","WeaponAimAssistorTableForGamepad."..row_name,"ConeHeightBase",0,{},profile_id[row_name])
    near(value,expected,"profile height "..row_name); eq(patch,true,"profile patch "..row_name)
end

local boundaries={
    {"custom_aim_speed","speed",1,1},{"custom_aim_speed","speed",50,50},{"custom_aim_speed","speed",100,100},
    {"custom_aim_range","fov",1,1},{"custom_aim_range","fov",90,90},{"custom_aim_range","fov",360,360},
    {"custom_aim_distance","distance",1,1},{"custom_aim_distance","distance",150,150},{"custom_aim_distance","distance",500,500},
    {"custom_aim_lock_time","lock",1,1},{"custom_aim_lock_time","lock",100,100},
}
for _,b in ipairs(boundaries) do
    local old=state[b[1]]; state[b[1]]=b[3]; eq(M.settings(state)[b[2]],b[4],b[1].." boundary"); state[b[1]]=old
    state[b[1]]=tostring(b[3]); eq(M.settings(state)[b[2]],b[4],b[1].." string"); state[b[1]]=old
end
state.custom_aim_speed=nil; eq(M.settings(state).speed,50,"nil speed fallback")
state.custom_aim_speed="invalid"; eq(M.settings(state).speed,50,"invalid speed fallback")
state.custom_aim_speed=50
print("aim-differential: ok")

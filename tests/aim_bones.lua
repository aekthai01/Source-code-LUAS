local root = assert(arg[1])
local S = {}
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
assert(loadfile(root .. "/src/spectra/aim_bones.lua"))(S)
local M = S.AimBones
local function eq(a,b,label) if a ~= b then error((label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local state = {custom_aim_target_part="leg"}
eq(M.remap(state,"Head"),"RightLeg","leg head")
eq(M.remap(state,"Neck"),"LeftLeg","leg neck")
state.custom_aim_target_part="free"
eq(M.remap(state,"Neck"),"Neck","free neck")
state.custom_aim_target_part="chest"
eq(M.remap(state,"Head"),"Spine2","chest head")
state.custom_aim_target_part="leg"
local row = {ConeFilterBones={"Head","Neck"}, ConeFilterBonesOfAI={{ConeFilterBones={"Head"}}}}
eq(M.patch_row(state,row),true,"bone row patched")
eq(row.ConeFilterBones[1],"RightLeg","direct head patched")
eq(row.ConeFilterBones[2],"LeftLeg","direct neck patched")
eq(row.ConeFilterBonesOfAI[1].ConeFilterBones[1],"RightLeg","AI head patched")
eq(state.custom_dongdong_aim_bone_verified_count,3,"verified count")
eq(state.custom_dongdong_aim_ai_bone_group_count,1,"AI group count")
eq(S.MutationRuntime.restore_bone_array_snapshots(state),true,"bone restore")
eq(row.ConeFilterBones[1],"Head","direct head restored")
eq(row.ConeFilterBonesOfAI[1].ConeFilterBones[1],"Head","AI head restored")
local refresh_state = {custom_aim_target_part="chest", custom_dongdong_toggle_state={aim=true}}
local refresh_row = {ConeFilterBones={"Head"}}
_G.TableManager = {GetTable=function(_,name)
    if name == "WeaponAimAssistorTable" then return {Default=refresh_row} end
end}
eq(M.refresh_bone_table(refresh_state),true,"table refresh")
eq(refresh_row.ConeFilterBones[1],"Spine2","table refresh applies selected part")
refresh_state.custom_dongdong_toggle_state.aim=false
eq(M.refresh_bone_table(refresh_state),false,"inactive refresh")
eq(refresh_row.ConeFilterBones[1],"Spine2","inactive refresh does not mutate")
_G.TableManager=nil
print("aim-bones: ok")

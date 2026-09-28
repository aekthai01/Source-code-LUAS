local root = assert(arg[1], "root path required")
local S = {}
assert(loadfile(root .. "/src/spectra/aim_abi.lua"))(S)
assert(loadfile(root .. "/src/spectra/p029_runtime_helpers.lua"))(S)
assert(loadfile(root .. "/src/spectra/mutation_runtime.lua"))(S)
local M = assert(S.MutationRuntime)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end

-- Exact path inventory recovered from the parent constants feeding P0.29.68.
eq(#M.FEATURE_TABLES.no_recoil,4,"no recoil table count")
eq(#M.FEATURE_TABLES.converge,7,"converge table count")
eq(#M.FEATURE_TABLES.aim,20,"aim table count")
eq(M.FEATURE_TABLES.aim[14],"weaponBase/weaponassistedaiminggrouptable","aim path 14")
eq(#M.CONVERGE_FIELDS,114,"converge field count")

local recoil_root = {
  Default = {
    SingleOrBurstShootRecoil = {
      HorizontalRandomRecoil = {MinValue=3, MaxValue=7, RandomValues={{MinValue=2,MaxValue=4}}},
      HorizontalScale = 2,
      VerticalRandomRecoil = {MinValue=5, MaxValue=9},
      VerticalScale = 3,
      HorizontalRecoils = { 8, {MinValue=4,MaxValue=6,Horizontal=5,Vertical=7,Percent=9,Probability=1,AmplitudeMin=2,AmplitudeMax=3} },
      VerticalRecoils = { 11 },
    },
    SideAimingRecoilFactor = {Horizontal=1.5, Vertical=2.5},
    HorizontalRecoils = { 12 },
    VerticalRecoils = { 13 },
  }
}
local spread_root = {
  Default = {
    Spread = {X=5, Y=6, Enabled=true, nested={Foo=7, Flag=true}},
    bLimitSpreadRecoverSpeed = true,
    Unrelated = 44,
    Config = {Bloom={Value=9, Enabled=true}},
  }
}

local aliases = {}
for _,name in ipairs(M.FEATURE_TABLES.no_recoil) do aliases[name]=recoil_root end
for _,name in ipairs(M.FEATURE_TABLES.converge) do aliases[name]=spread_root end
local manager = {}
function manager:GetTable(name) return aliases[name] end
_G.Facade = {TableManager=manager}
local state = {}

truth(M.apply_feature(state,"no_recoil"),"apply no_recoil")
eq(recoil_root.Default.SingleOrBurstShootRecoil.HorizontalScale,0.0,"horizontal scale")
eq(recoil_root.Default.SingleOrBurstShootRecoil.HorizontalRandomRecoil.MinValue,0.0,"random min")
eq(recoil_root.Default.SingleOrBurstShootRecoil.HorizontalRecoils[1],0.0,"numeric collection")
eq(recoil_root.Default.SideAimingRecoilFactor.Vertical,0.0,"side factor")
local nr_snapshot = state.custom_dongdong_feature_snapshots.no_recoil
truth(type(nr_snapshot)=="table" and #nr_snapshot.records>0,"no recoil snapshot")
local nr_records = #nr_snapshot.records
-- All aliases resolve to one canonical table object; P0.29.68 dedupes by identity.
truth(nr_records < 40,"alias dedupe prevents repeated snapshot growth")
truth(M.restore_feature_snapshot(state,"no_recoil"),"restore no_recoil")
eq(recoil_root.Default.SingleOrBurstShootRecoil.HorizontalScale,2,"restore horizontal scale")
eq(recoil_root.Default.SingleOrBurstShootRecoil.HorizontalRandomRecoil.MinValue,3,"restore random min")
eq(recoil_root.Default.SingleOrBurstShootRecoil.HorizontalRecoils[1],8,"restore numeric collection")
eq(recoil_root.Default.SideAimingRecoilFactor.Vertical,2.5,"restore side factor")

truth(M.apply_feature(state,"converge"),"apply converge")
eq(spread_root.Default.Spread.X,0.0,"forced child x")
eq(spread_root.Default.Spread.Y,0.0,"forced child y")
eq(spread_root.Default.Spread.Enabled,false,"forced child boolean")
eq(spread_root.Default.Spread.nested.Foo,0.0,"force propagates through nested table")
eq(spread_root.Default.Spread.nested.Flag,false,"force nested boolean")
eq(spread_root.Default.bLimitSpreadRecoverSpeed,false,"spread-like scalar")
eq(spread_root.Default.Config.Bloom.Value,0.0,"bloom starts forced recursion")
eq(spread_root.Default.Unrelated,44,"unrelated scalar remains")
truth(M.restore_feature_snapshot(state,"converge"),"restore converge")
eq(spread_root.Default.Spread.X,5,"restore spread x")
eq(spread_root.Default.Spread.nested.Foo,7,"restore nested foo")
eq(spread_root.Default.bLimitSpreadRecoverSpeed,true,"restore spread bool")

-- P0.29.22 generic recursive zero helper.
local zero_state={}
local zero_tree={A=3,B=true,Nested={C=4,D=false}}
M.zero_recursive(zero_state,"anti_shake",zero_tree,0,{})
eq(zero_tree.A,0.0,"recursive number")
eq(zero_tree.B,false,"recursive boolean")
eq(zero_tree.Nested.C,0.0,"recursive nested number")
truth(M.restore_feature_snapshot(zero_state,"anti_shake"),"recursive restore")
eq(zero_tree.A,3,"recursive number restore")
eq(zero_tree.B,true,"recursive boolean restore")
eq(zero_tree.Nested.C,4,"recursive nested restore")

-- P15 records the original before the protected assignment (instructions
-- 32..45). A rejected write leaves a restorable record; callers must roll it
-- back before delegating to the payload on a source migration failure.
local rejected=setmetatable({Value=11},{__newindex=function(owner,key,value)
    if value == 42 then error("write rejected") end
    rawset(owner,key,value)
end})
local failure_state={}
eq(M.snapshot_set(failure_state,"aim",rejected,"Blocked",42),false,"failed write result")
eq(#failure_state.custom_dongdong_feature_snapshots.aim.records,1,"snapshot precedes failed write")
truth(M.restore_feature_snapshot(failure_state,"aim"),"restore attempts recorded write")
eq(failure_state.custom_dongdong_feature_snapshots.aim,nil,"failed-write snapshot cleared")

-- P0.29.54/P0.29.60 bone array snapshot and restore path.
local holder = { Bones = {"Head","Spine2"} }
local bone_state = {}
local record = M.snapshot_bone_array(bone_state, holder.Bones, {owner=holder,key="Bones"})
truth(record,"bone snapshot")
holder.Bones[1]="LeftLeg"; holder.Bones[2]="RightLeg"
truth(M.restore_bone_array_snapshots(bone_state),"bone restore")
eq(holder.Bones[1],"Head","bone 1 restored")
eq(holder.Bones[2],"Spine2","bone 2 restored")
eq(bone_state.custom_dongdong_aim_bone_restore_count,1,"bone restore count")
eq(M.canonical_bone_name("Some.Head"),"head","canonical fallback")

print("mutation-runtime: ok")

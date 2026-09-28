local root=assert(arg[1],"root path required")
local S={}
assert(loadfile(root.."/src/spectra/feature_control.lua"))(S)
local F=assert(S.FeatureControl)
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end
local function packed(fn,...) return table.pack(fn(...)) end
local function assert_one(fn,expected,label,...)
  local r=packed(fn,...); eq(r.n,1,(label or "return").." arity"); eq(r[1],expected,label)
end
local function deps_with_log(log)
  return {
    restore_bone_array_snapshots=function() log[#log+1]="restore bones"; return "discarded" end,
    restore_feature_snapshot=function(feature) log[#log+1]="restore "..tostring(feature); return "discarded" end,
    apply_feature=function(feature) log[#log+1]="apply "..tostring(feature); return "discarded" end,
    set_native_aim_assist=function(active) log[#log+1]="native "..tostring(active); return "discarded" end,
    set_fire_assisted_aim_debug=function(active) log[#log+1]="debug "..tostring(active); return "discarded" end,
  }
end
local function sequence(log,expected,label)
  eq(#log,#expected,(label or "sequence").." length")
  for i,v in ipairs(expected) do eq(log[i],v,(label or "sequence").."["..i.."]") end
end

-- State initialization: missing, non-table (including userdata), and existing identity.
do
  local log={}; local state={}; local fn=F.make_feature_config(state,deps_with_log(log))
  assert_one(fn,false,"missing state unsupported","anything_else",false)
  truth(type(state.custom_dongdong_toggle_state)=="table","missing state creates table")
  eq(state.custom_dongdong_toggle_state.anything_else,false,"missing state normalized write")
end
do
  local log={}; local state={custom_dongdong_toggle_state="bad"}; local fn=F.make_feature_config(state,deps_with_log(log))
  assert_one(fn,false,"string state unsupported","anything_else",true)
  truth(type(state.custom_dongdong_toggle_state)=="table","string state replaced")
  eq(state.custom_dongdong_toggle_state.anything_else,true,"string replacement write")
end
do
  local log={}; local state={custom_dongdong_toggle_state=io.stdout}; local fn=F.make_feature_config(state,deps_with_log(log))
  assert_one(fn,false,"userdata state unsupported","anything_else",false)
  truth(type(state.custom_dongdong_toggle_state)=="table","userdata state replaced")
end
do
  local log={}; local toggles={sentinel=true}; local state={custom_dongdong_toggle_state=toggles}; local fn=F.make_feature_config(state,deps_with_log(log))
  assert_one(fn,false,"existing state unsupported","anything_else",false)
  eq(state.custom_dongdong_toggle_state,toggles,"existing toggle identity")
end

-- Aim exact literal-true semantics, mutual exclusion, helper order and return arity.
do
  local log={}; local state={custom_dongdong_toggle_state={aim=false,anti_shake=true}}
  local fn=F.make_feature_config(state,deps_with_log(log))
  assert_one(fn,true,"aim true","aim",true)
  eq(state.custom_dongdong_toggle_state.aim,true,"aim enabled")
  eq(state.custom_dongdong_toggle_state.anti_shake,false,"aim mutual exclusion")
  sequence(log,{"restore bones","restore anti_shake","restore aim","apply aim","native true","debug true"},"aim active order")
end
do
  for _,value in ipairs({false,1,"true"}) do
    local log={}; local state={custom_dongdong_toggle_state={aim=true,anti_shake=false}}
    local fn=F.make_feature_config(state,deps_with_log(log))
    assert_one(fn,true,"aim nontrue","aim",value)
    eq(state.custom_dongdong_toggle_state.aim,false,"aim nontrue disables")
    sequence(log,{"restore bones","restore anti_shake","restore aim","native false","debug false"},"aim inactive order")
  end
  local log={}; local state={custom_dongdong_toggle_state={aim=true,anti_shake=false}}
  local fn=F.make_feature_config(state,deps_with_log(log))
  assert_one(fn,true,"aim nil","aim",nil)
  eq(state.custom_dongdong_toggle_state.aim,false,"aim nil disables")
  sequence(log,{"restore bones","restore anti_shake","restore aim","native false","debug false"},"aim nil order")
end

-- anti_shake exact semantics and mutual exclusion.
do
  local log={}; local state={custom_dongdong_toggle_state={aim=true,anti_shake=false}}
  local fn=F.make_feature_config(state,deps_with_log(log))
  assert_one(fn,true,"anti true","anti_shake",true)
  eq(state.custom_dongdong_toggle_state.aim,false,"anti clears aim")
  eq(state.custom_dongdong_toggle_state.anti_shake,true,"anti enabled")
  sequence(log,{"restore bones","restore anti_shake","restore aim","apply aim","native true","debug false"},"anti active order")
  log={}
  local state2={custom_dongdong_toggle_state={aim=false,anti_shake=true}}
  local fn2=F.make_feature_config(state2,deps_with_log(log))
  assert_one(fn2,true,"anti false","anti_shake",false)
  eq(state2.custom_dongdong_toggle_state.anti_shake,false,"anti disabled")
  sequence(log,{"restore bones","restore anti_shake","restore aim","native false","debug false"},"anti inactive order")
end

-- Unsupported feature remains wholly source-owned: normalized write, one false,
-- and absolutely no restore/apply/native/debug calls.
do
  for _,case in ipairs({{true,true},{false,false},{1,false},{"true",false}}) do
    local log={}; local state={custom_dongdong_toggle_state={}}
    local fn=F.make_feature_config(state,deps_with_log(log))
    assert_one(fn,false,"unsupported","anything_else",case[1])
    eq(state.custom_dongdong_toggle_state.anything_else,case[2],"unsupported normalization")
    eq(#log,0,"unsupported dependency silence")
  end
end

-- no_recoil / converge exact restore/apply matrix and one-value ABI.
for _,feature in ipairs({"no_recoil","converge"}) do
  local log={}; local state={custom_dongdong_toggle_state={}}
  local fn=F.make_feature_config(state,deps_with_log(log))
  assert_one(fn,true,feature.." true",feature,true)
  eq(state.custom_dongdong_toggle_state[feature],true,feature.." true toggle")
  sequence(log,{"restore "..feature,"apply "..feature},feature.." true order")
  log={}
  local state2={custom_dongdong_toggle_state={}}
  local fn2=F.make_feature_config(state2,deps_with_log(log))
  assert_one(fn2,true,feature.." false",feature,false)
  eq(state2.custom_dongdong_toggle_state[feature],false,feature.." false toggle")
  sequence(log,{"restore "..feature},feature.." false order")
end

-- Fixed capture identity for U2..U6 and the captured state table.
do
  local log={}
  local state_a={custom_dongdong_toggle_state={aim=false,anti_shake=false}}
  local state_b={custom_dongdong_toggle_state={aim=false,anti_shake=false}}
  local deps=deps_with_log(log)
  local fn=F.make_feature_config(state_a,deps)
  for _,name in ipairs({"restore_bone_array_snapshots","restore_feature_snapshot","apply_feature","set_native_aim_assist","set_fire_assisted_aim_debug"}) do
    deps[name]=function() error("mutated dependency observed: "..name) end
  end
  local state_ref=state_a
  state_ref=state_b
  assert_one(fn,true,"capture identity","aim",true)
  eq(state_a.custom_dongdong_toggle_state.aim,true,"captured state A written")
  eq(state_b.custom_dongdong_toggle_state.aim,false,"replacement state B untouched")
  sequence(log,{"restore bones","restore anti_shake","restore aim","apply aim","native true","debug true"},"captured helper identities")
end

print("p029-feature-control: ok")

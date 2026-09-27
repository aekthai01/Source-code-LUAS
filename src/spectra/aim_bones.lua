local S = ...
assert(type(S) == "table" and type(S.MutationRuntime) == "table")
local Mutation = S.MutationRuntime
local M = {}
S.AimBones = M
-- Names are reconstructed descriptions; IDs and the four maps come from R67.
M.PROTOTYPES = { remap = "0.29.45", patch_array = "0.29.61",
    patch_ai_groups = "0.29.62", patch_row = "0.29.63",
    refresh_bone_table = "0.29.64" }
local MAPS = {
    head = {head="Head",neck="Head",spine2="Head",hips="Head",leftleg="Head",rightleg="Head"},
    chest = {head="Spine2",neck="Spine2",spine2="Spine2",hips="Spine2",leftleg="Spine2",rightleg="Spine2"},
    leg = {head="RightLeg",neck="LeftLeg",spine2="RightLeg",hips="LeftLeg",leftleg="LeftLeg",rightleg="RightLeg"},
    free = {head="Head",neck="Neck",spine2="Spine2",hips="Hips",leftleg="LeftLeg",rightleg="RightLeg"},
}

function M.remap(state, value)
    local mode = tostring(state.custom_aim_target_part or "head")
    if mode == "miss" then mode = "free" end
    local mapping = MAPS[mode] or MAPS.head
    local bone = Mutation.canonical_bone_name(value)
    if bone == nil then return nil end
    return mapping[bone]
end

function M.patch_array(state, array, binding)
    local record = Mutation.snapshot_bone_array(state, array, binding)
    if type(record) ~= "table" then return false end
    local patched, count = false, 0
    for index0 = 0, record.count - 1 do
        local original = record.values[index0 + 1]
        local desired = M.remap(state, original)
        if desired ~= nil and Mutation.array_set_verified(state, array, index0, original, desired) then
            patched, count = true, count + 1
        end
    end
    if patched then
        Mutation.restore_record_bindings(record)
        state.custom_dongdong_aim_bone_verified_count =
            (tonumber(state.custom_dongdong_aim_bone_verified_count) or 0) + count
    end
    return patched
end

local function is_array(v) return type(v) == "table" or type(v) == "userdata" end

function M.patch_ai_groups(state, array, binding)
    if not is_array(array) then return false end
    local count = Mutation.array_len(array)
    if count <= 0 then return false end
    local patched, patched_groups = false, 0
    for index0 = 0, count - 1 do
        local item = Mutation.array_get(array, index0)
        if is_array(item) then
            local dat = Mutation.get_extended_field(item, "_Dat")
            local bones = Mutation.get_extended_field(item, "ConeFilterBones")
            local group_changed = false
            for _, entry in ipairs({{item, bones}, {dat, Mutation.get_extended_field(dat, "ConeFilterBones")}}) do
                local owner, subarray = entry[1], entry[2]
                if is_array(subarray) then
                    local subbinding = {owner=owner, key="ConeFilterBones",
                        parent_array=array, parent_index=index0, parent_value=item,
                        parent_owner=binding and binding.owner,
                        parent_key=binding and binding.key}
                    if M.patch_array(state, subarray, subbinding) then group_changed = true end
                end
            end
            if group_changed then
                Mutation.array_set_raw(array, index0, item)
                if binding and binding.owner ~= nil and binding.key ~= nil then
                    pcall(function() binding.owner[binding.key] = array end)
                end
                patched, patched_groups = true, patched_groups + 1
            end
        end
    end
    if patched_groups > 0 then
        state.custom_dongdong_aim_ai_bone_group_count =
            (tonumber(state.custom_dongdong_aim_ai_bone_group_count) or 0) + patched_groups
    end
    return patched
end

function M.patch_row(state, row)
    if not is_array(row) then return false end
    local patched = false
    local function candidate(owner, field, fn)
        local array = Mutation.get_extended_field(owner, field)
        if is_array(array) and fn(state, array, {owner=owner, key=field}) then patched = true end
    end
    local dat = Mutation.get_extended_field(row, "_Dat")
    if dat ~= nil then
        candidate(dat, "ConeFilterBones", M.patch_array)
        candidate(dat, "ConeFilterBonesOfAI", M.patch_ai_groups)
    end
    candidate(row, "ConeFilterBones", M.patch_array)
    candidate(row, "ConeFilterBonesOfAI", M.patch_ai_groups)
    if patched then
        state.custom_dongdong_aim_bone_patch_count =
            (tonumber(state.custom_dongdong_aim_bone_patch_count) or 0) + 1
    end
    return patched
end

function M.refresh_bone_table(state)
    local toggles = state.custom_dongdong_toggle_state or {}
    if toggles.aim ~= true and toggles.anti_shake ~= true then return false end
    Mutation.restore_bone_array_snapshots(state)
    local table_value = Mutation.table_extend(Mutation.get_data_table("WeaponAimAssistorTable"))
    if type(table_value) ~= "table" then return false end
    local patched = false
    Mutation.iterate_table(table_value, function(_, _, row)
        if M.patch_row(state, Mutation.table_extend(row)) then patched = true end
    end)
    return patched
end

return M

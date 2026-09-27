local S = ...
assert(type(S) == "table", "spectra module table required")
local Mutation = assert(S.MutationRuntime, "MutationRuntime required")
local AimMutation = assert(S.AimMutation, "AimMutation required")
local AimBones = assert(S.AimBones, "AimBones required")
local AimABI = assert(S.AimABI, "AimABI required")
local M = {}
S.AimChain = M

-- P0.29.66 / P0.29.67 aim source path. Names are reconstructed descriptions.
-- P2 reads are deliberately kept distinct from Mutation.safe_get: the payload
-- helper coerces false to nil through TESTSET semantics.
M.PROTOTYPES = { walk_and_patch = "0.29.66", apply_aim_row = "0.29.67.0" }
M.ROW_IDS = { Default=1, NewRow=1001, NewRow_0=1002,
    NewRow_1=1003, NewRow_2=11001, NewRow_3=1004 }

local function dependency(deps, name, fallback)
    local value = deps and deps[name] or fallback
    assert(type(value) == "function", "missing reconstructed dependency: " .. name)
    return value
end

function M.walk_and_patch(state, deps, owner, field, value, table_name, depth, seen, row_id)
    depth = tonumber(depth) or 0
    if depth > 13 then return end
    local normalize = dependency(deps, "normalize_identifier", Mutation.normalize_identifier)
    local read_field = dependency(deps, "read_field", AimABI.get)
    local snapshot_set = dependency(deps, "snapshot_set", function(feature, target, key, replacement)
        return Mutation.snapshot_set(state, feature, target, key, replacement)
    end)
    local key = normalize(field)
    if key == "conefilterbones" or key == "conefilterbonesofai" then return end

    local replacement, should_patch = AimMutation.replacement(
        state, {normalize_identifier=normalize, read_field=read_field},
        owner, table_name, field, value, row_id)
    if should_patch then
        snapshot_set("aim", owner, field, replacement)
        return
    end

    value = Mutation.table_extend(value)
    local kind = type(value)
    if kind ~= "table" and kind ~= "userdata" then return end
    seen = seen or {}
    if seen[value] then return end
    seen[value] = true
    local path = table_name .. "." .. tostring(field)

    if kind == "table" then
        Mutation.iterate_table(value, function(child_owner, child_field, child_value)
            M.walk_and_patch(state, deps, child_owner, child_field, child_value,
                path, depth + 1, seen, row_id)
        end)
        return
    end

    for _, child_field in ipairs(Mutation.CONVERGE_FIELDS) do
        local child_value = read_field(value, child_field)
        if child_value ~= nil then
            M.walk_and_patch(state, deps, value, child_field, child_value,
                table_name .. "." .. child_field, depth + 1, seen, row_id)
        end
    end
end

function M.apply_aim_row(state, deps, owner, key, row, table_name)
    local read_field = dependency(deps, "read_field", AimABI.get)
    local patch_bones = dependency(deps, "patch_bones", function(value)
        return AimBones.patch_row(state, value)
    end)
    local raw_id = read_field(row, "AimAssistorId")
    local row_id = tonumber(raw_id)
    if row_id == nil and raw_id ~= nil then
        row_id = tonumber(read_field(raw_id, "value") or read_field(raw_id, "Value"))
    end
    if row_id == nil then row_id = M.ROW_IDS[tostring(key)] end

    patch_bones(row)
    M.walk_and_patch(state, deps, owner, key, row,
        table_name .. "." .. tostring(key), 0, {}, row_id)
end

function M.handlers(state, deps)
    return {
        aim = function(owner, key, row, table_name)
            return M.apply_aim_row(state, deps, owner, key, row, table_name)
        end,
    }
end

return M

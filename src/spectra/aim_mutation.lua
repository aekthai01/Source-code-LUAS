local S = ...
assert(type(S) == "table", "spectra module table required")
local M = {}
S.AimMutation = M

-- Descriptive names reconstructed from P0.29.30..39 and P0.29.65, not debug symbols.
-- This module is deliberately not installed in the runtime bridge yet.
M.PROTOTYPES = { clamp = "0.29.30", speed = "0.29.31", fov = "0.29.32",
    fov_scale = "0.29.33", distance = "0.29.34", lock_time = "0.29.35",
    mode = "0.29.36", speed_scale = "0.29.37", inverse_speed = "0.29.38",
    lock_delay = "0.29.39", replacement = "0.29.65" }

function M.clamp(value, minimum, maximum, fallback)
    return math.min(maximum, math.max(minimum, tonumber(value) or fallback))
end

function M.settings(state)
    local speed = M.clamp(state.custom_aim_speed, 1, 100, 50)
    local fov = M.clamp(state.custom_aim_range, 1, 360, 90)
    local distance = M.clamp(state.custom_aim_distance, 1, 500, 150)
    local lock = M.clamp(state.custom_aim_lock_time, 1, 100, 1)
    local mode
    local toggles = state.custom_dongdong_toggle_state
    if type(toggles) == "table" then
        if toggles.aim == true then mode = "fire"
        elseif toggles.anti_shake == true then mode = "ads" end
    end
    return { speed = speed, fov = fov, distance = distance, lock = lock,
        fov_scale = fov <= 90 and fov / 90 or 1 + (fov - 90) / 270 * 5,
        mode = mode, speed_scale = speed / 50,
        inverse_speed = M.clamp(0.05 * (50 / speed), 0.001, 1, 0),
        lock_delay = M.clamp((0.001 + (100 - speed) / 99 * 0.999) * lock * 0.01, 0.001, 0.35, 0) }
end

local function has(s, part) return s:find(part, 1, true) ~= nil end
local function member(key, names)
    for i = 1, #names do if key == names[i] then return true end end
    return false
end

-- deps: normalize_identifier=P0.29.10, read_field=P0.29.19,
-- scale_clamp=P0.29.42. The R52 profile matrix and P0.29.40/41 are below.
-- The remaining dependencies must retain their original contracts when an
-- active row walker is wired to this function.
function M.replacement(state, deps, row, table_name, field, original, path)
    assert(type(state) == "table" and type(deps) == "table", "state/dependencies required")
    local normalize = assert(deps.normalize_identifier)
    local name, key = normalize(table_name), normalize(field)
    local cfg = M.settings(state)
    if cfg.mode == nil then return nil, false end
    local speed, fov, dist = cfg.speed, cfg.fov, cfg.distance
    local speed_scale, fov_scale = cfg.speed_scale, cfg.fov_scale
    local dist_scale, dist_100, dist_300 = dist / 150, dist * 100, dist * 300
    local composite = M.clamp(dist * 1.2 + fov * 1.4 * math.sqrt(fov_scale), 30, 2000, 30)
    local gamepad = has(name, "weaponaimassistortableforgamepad")
    local normal = has(name, "weaponaimassistortable") and not gamepad
    -- P0.29.65:38..50 excludes the Gamepad substring from the normal flag.
    -- The ADS branch at 150..153 requires that normal flag; Gamepad is not
    -- interchangeable with the ordinary aim-assistor table.
    local assist = normal
    local assisted = has(name, "weaponassistedaimingtable") or has(name, "weaponassistedaiminggrouptable")
    local group = has(name, "weaponassistedaiminggrouptable")
    local bullet = has(name, "weaponbullettable")
    local shooting = has(name, "shootingconfig")
    local following = has(name, "crosshairfollowingconfig")
    local damping = has(name, "crosshairdampingconfig")
    local tracking = has(name, "activetrackingconfig")
    local zoom = has(name, "zoominginconfig")

    if cfg.mode == "ads" then
        if not assist then return nil, false end
        if key == "btakeeffect" then return true, true end
        if key == "x" and has(name, "effectivefovrange") then return fov, true end
        if member(key, {"coneanglebase", "outer2innerrangeforraychecker"}) then return fov, true end
        if key == "rangescale" then return fov / 90, true end
        if key == "coneheightbase" then return dist_100, true end
        if key == "lockontime" then return cfg.lock_delay, true end
        if member(key, {"pitchrateads", "yawrateads"}) then return speed, true end
        if member(key, {"pitchratehip", "yawratehip"}) then return nil, false end
        if key == "inrangeb" then
            if type(original) ~= "number" then return nil, false end
            local base
            if original >= 9000 then base = 33333
            elseif original >= 5500 then base = 22222
            elseif original >= 2800 then base = 9999
            elseif original >= 2200 then base = shooting and 7000 or 7777
            else base = 3 end
            return base * dist_scale, true
        end
        if member(key, {"outrangea", "outrangeb"}) then return 3, true end
        if key == "playerinputawaytargetangle" then return 1555, true end
        if member(key, {"playerinputawaytargetvalue", "playerinputrecordtime"}) then return 0, true end
        if key == "conefilteractorsmaxnum" then
            return M.clamp(math.floor(8 * fov_scale + 0.5), 16, 64, 16), true
        end
        return nil, false
    end

    if bullet then
        if key == "radius" and type(original) == "number" and original <= 3 then return 5, true end
        return nil, false
    end
    if group then
        local links = { singleidpve = "SingleId", autoidpve = "AutoId", burstidpve = "BurstId",
            aimingsingleidpve = "AimingSingleId", aimingautoidpve = "AimingAutoId",
            aimingburstidpve = "AimingBurstId" }
        local target = links[key]
        if target then
            local value = tonumber(assert(deps.read_field)(row, target))
            if value and value > 0 then return value, true end
        end
        return nil, false
    end
    if assisted then
        if member(key, {"enabledistancemin", "enabledistanceminforrotatesticky", "enabledistanceminformagneticsticky"}) then return 0, true end
        if member(key, {"enabledistancemax", "enabledistancemaxforrotatesticky", "enabledistancemaxformagneticsticky"}) then return dist_300, true end
        if member(key, {"assistedboxminradius", "assistedboxminradiusforrotatesticky", "assistedboxminradiusformagneticsticky"}) then return composite * 0.65, true end
        if member(key, {"assistedboxmaxradius", "assistedboxmaxradiusforrotatesticky", "assistedboxmaxradiusformagneticsticky"}) then return composite, true end
        if member(key, {"assistedboxverticalscale", "assistedboxverticalscaleforrotatesticky", "assistedboxverticalscaleformagneticsticky"}) then
            return math.min(2, 1.35 + math.max(0, fov_scale - 1) * 0.13), true
        end
        if member(key, {"horizontalrecoilspeed", "verticalrecoilspeed", "horizontalrecoilspeedforzoomin", "verticalrecoilspeedforzoomin"}) then return speed, true end
        if member(key, {"pausetimeafterfire", "recoilreduceactivationtime", "magneticcdseconds", "magneticenablefocusseconds"}) then return 0, true end
        if key == "recoilspeedtouchparam" then return speed_scale * 1.5, true end
        if key == "stickyparam" then return speed_scale * 3, true end
        if key == "bpreventmissenable" then return true, true end
        if key == "preventmissaddbulletradiusdelta" then return math.min(1500, math.max(composite * 1.25, dist_100 * 0.02)), true end
        if key == "preventmissnumber" then return 12, true end
        if key == "preventmisstime" then return 0.25, true end
        return nil, false
    end
    if assist then return nil, false end
    if key == "btakeeffect" then
        if tracking or zoom then return false, true end
        if shooting or following or damping then return true, true end
        return nil, false
    end

    local value, qualified = M.profile_lookup(normalize, path, table_name, key)
    if value ~= nil then
        local scale_clamp = assert(deps.scale_clamp)
        if qualified == "lockontime" then return scale_clamp(value, cfg.lock, 0.001, 1), true end
        local factor = shooting and has(qualified, "factor") or following and has(qualified, "factor")
        local interval = shooting and member(key, {"deltatime", "cdtime"}) or following and key == "intervaltime"
        if factor then
            local v = speed_scale
            if has(qualified, "pitchfactor") then
                if shooting then v = v * 1.3
                elseif following then v = v * (has(qualified, "factorlockon") and 1.7 or 1.4) end
            elseif following and has(qualified, "factorlockon") then v = v * 1.15 end
            return scale_clamp(value, v, 0, 3), true
        end
        if interval then
            local v = scale_clamp(value, 1 / speed_scale, 0.001, 0.25)
            if shooting and key == "deltatime" then v = math.max(v, 0.015)
            elseif shooting and key == "cdtime" then v = math.max(v, 0.008)
            elseif following and key == "intervaltime" then v = math.max(v, 0.012) end
            return v, true
        end
        if qualified == "coneanglepower" then
            local n = tonumber(value) or 1
            return M.clamp(fov_scale >= 1 and n / math.sqrt(fov_scale) or n / math.max(fov_scale, 0.05), 0.5, 8, 1), true
        end
        if qualified == "coneanglebase" or has(qualified, "effectivefovrange") or has(qualified, "outer2innerrangeforraychecker") then
            return scale_clamp(value, fov_scale, 0.001, 99999), true
        end
        if member(qualified, {"coneheightbase", "coneheightpower"}) then return scale_clamp(value, dist_scale, 0.001, 999999), true end
        if has(qualified, "rangescale") then
            local v = scale_clamp(value, dist_scale, 0.001, 999999)
            if key == "inrangeb" then v = math.max(v, dist_300) end
            if member(key, {"outrangea", "outrangeb"}) then
                v = math.max(v, (shooting or following) and 6 or 3)
            end
            return v, true
        end
    end
    if key == "playerinputawaytargetangle" then return 1555, true end
    if member(key, {"playerinputawaytargetvalue", "playerinputrecordtime"}) then return 0, true end
    if key == "conefilteractorsmaxnum" then return M.clamp(math.floor(8 * fov_scale + 0.5), 16, 64, 16), true end
    return nil, false
end

-- Exact R52 profile literals from verified payload P0.29 instructions 388..934.
M.PROFILE_VALUES = {
    [1] = {
        ["coneanglebase"] = 15.0,
        ["coneanglepower"] = 3.0,
        ["coneheightbase"] = 3333.0,
        ["coneheightpower"] = 3.0,
        ["crosshairdampingconfigeffectivefovrangex"] = 11.0,
        ["crosshairdampingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairdampingconfigrangescaleinrangeb"] = 33333.0,
        ["crosshairdampingconfigrangescaleoutrangeb"] = 3.0,
        ["crosshairfollowingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairfollowingconfigintervaltime"] = 0.5,
        ["crosshairfollowingconfigpitchfactorads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorhip"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonads"] = 2.0,
        ["crosshairfollowingconfigpitchfactorlockonhip"] = 2.0,
        ["crosshairfollowingconfigrangescaleinrangeb"] = 33333.0,
        ["crosshairfollowingconfigrangescaleoutrangea"] = 3.0,
        ["crosshairfollowingconfigyawfactorads"] = 1.0,
        ["crosshairfollowingconfigyawfactorhip"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonads"] = 2.0,
        ["crosshairfollowingconfigyawfactorlockonhip"] = 2.0,
        ["lockontime"] = 0.0010000000474974513,
        ["shootingconfigcdtime"] = 0.0010000000474974513,
        ["shootingconfigdeltatime"] = 0.10000000149011612,
        ["shootingconfigeffectivefovrangex"] = 10.0,
        ["shootingconfigeffectivefovrangey"] = 1555.0,
        ["shootingconfigpitchfactorads"] = 1.0,
        ["shootingconfigpitchfactorhip"] = 1.0,
        ["shootingconfigrangescaleinrangeb"] = 33333.0,
        ["shootingconfigrangescaleoutrangea"] = 3.0,
        ["shootingconfigrangescaleoutrangeb"] = 1.0,
        ["shootingconfigyawfactorads"] = 1.0,
        ["shootingconfigyawfactorhip"] = 1.0,
    },
    [1001] = {
        ["coneanglebase"] = 15.0,
        ["coneanglepower"] = 3.0,
        ["coneheightbase"] = 45900.0,
        ["coneheightpower"] = 3.0,
        ["crosshairdampingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckerinrangeb"] = 3.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckeroutrangeb"] = 3.0,
        ["crosshairdampingconfigrangescaleinrangeb"] = 33333.0,
        ["crosshairdampingconfigrangescaleoutrangeb"] = 3.0,
        ["crosshairfollowingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairfollowingconfigintervaltime"] = 2.0,
        ["crosshairfollowingconfigpitchfactorads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorhip"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonhip"] = 1.0,
        ["crosshairfollowingconfigrangescaleinrangeb"] = 11111.0,
        ["crosshairfollowingconfigrangescaleoutrangeb"] = 3.0,
        ["crosshairfollowingconfigyawfactorads"] = 1.0,
        ["crosshairfollowingconfigyawfactorhip"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonads"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonhip"] = 1.0,
        ["lockontime"] = 0.0010000000474974513,
        ["shootingconfigcdtime"] = 0.0010000000474974513,
        ["shootingconfigdeltatime"] = 0.05000000074505806,
        ["shootingconfigeffectivefovrangex"] = 11.0,
        ["shootingconfigeffectivefovrangey"] = 1555.0,
        ["shootingconfigpitchfactorads"] = 1.0,
        ["shootingconfigpitchfactorhip"] = 1.0,
        ["shootingconfigrangescaleinrangeb"] = 22222.0,
        ["shootingconfigrangescaleoutrangeb"] = 3.0,
        ["shootingconfigyawfactorads"] = 1.0,
        ["shootingconfigyawfactorhip"] = 1.0,
    },
    [1002] = {
        ["coneanglebase"] = 15.0,
        ["coneanglepower"] = 3.0,
        ["coneheightbase"] = 44444.0,
        ["coneheightpower"] = 3.0,
        ["crosshairdampingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckerinrangeb"] = 3.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckeroutrangeb"] = 3.0,
        ["crosshairdampingconfigrangescaleinrangeb"] = 33333.0,
        ["crosshairdampingconfigrangescaleoutrangeb"] = 3.0,
        ["crosshairfollowingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairfollowingconfigintervaltime"] = 2.0,
        ["crosshairfollowingconfigpitchfactorads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorhip"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonhip"] = 1.0,
        ["crosshairfollowingconfigrangescaleinrangeb"] = 9999.0,
        ["crosshairfollowingconfigrangescaleoutrangeb"] = 3.0,
        ["crosshairfollowingconfigyawfactorads"] = 1.0,
        ["crosshairfollowingconfigyawfactorhip"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonads"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonhip"] = 1.0,
        ["lockontime"] = 0.0010000000474974513,
        ["shootingconfigcdtime"] = 0.0010000000474974513,
        ["shootingconfigdeltatime"] = 0.05000000074505806,
        ["shootingconfigeffectivefovrangey"] = 1555.0,
        ["shootingconfigpitchfactorads"] = 1.0,
        ["shootingconfigpitchfactorhip"] = 1.0,
        ["shootingconfigrangescaleoutrangeb"] = 1.0,
        ["shootingconfigyawfactorads"] = 1.0,
        ["shootingconfigyawfactorhip"] = 1.0,
    },
    [1003] = {
        ["coneanglebase"] = 15.0,
        ["coneanglepower"] = 3.0,
        ["coneheightbase"] = 44444.0,
        ["coneheightpower"] = 3.0,
        ["crosshairdampingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckerinrangeb"] = 3.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckeroutrangeb"] = 3.0,
        ["crosshairdampingconfigrangescaleinrangeb"] = 33333.0,
        ["crosshairdampingconfigrangescaleoutrangeb"] = 3.0,
        ["crosshairfollowingconfigeffectivefovrangey"] = 1444.0,
        ["crosshairfollowingconfigintervaltime"] = 2.0,
        ["crosshairfollowingconfigpitchfactorads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorhip"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonhip"] = 1.0,
        ["crosshairfollowingconfigrangescaleinrangeb"] = 9999.0,
        ["crosshairfollowingconfigrangescaleoutrangeb"] = 6.0,
        ["crosshairfollowingconfigyawfactorads"] = 1.0,
        ["crosshairfollowingconfigyawfactorhip"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonads"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonhip"] = 1.0,
        ["lockontime"] = 0.0010000000474974513,
        ["shootingconfigcdtime"] = 0.0010000000474974513,
        ["shootingconfigdeltatime"] = 0.05000000074505806,
        ["shootingconfigeffectivefovrangex"] = 11.0,
        ["shootingconfigeffectivefovrangey"] = 1555.0,
        ["shootingconfigpitchfactorads"] = 1.0,
        ["shootingconfigpitchfactorhip"] = 1.0,
        ["shootingconfigrangescaleinrangeb"] = 33333.0,
        ["shootingconfigrangescaleoutrangeb"] = 3.0,
        ["shootingconfigyawfactorads"] = 1.0,
        ["shootingconfigyawfactorhip"] = 1.0,
    },
    [11001] = {
        ["coneanglebase"] = 15.0,
        ["coneanglepower"] = 3.0,
        ["coneheightbase"] = 44444.0,
        ["coneheightpower"] = 3.0,
        ["crosshairdampingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckerinrangeb"] = 3.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckeroutrangeb"] = 3.0,
        ["crosshairdampingconfigrangescaleinrangeb"] = 33333.0,
        ["crosshairdampingconfigrangescaleoutrangeb"] = 3.0,
        ["crosshairfollowingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairfollowingconfigintervaltime"] = 2.0,
        ["crosshairfollowingconfigpitchfactorads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorhip"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonads"] = 1.0,
        ["crosshairfollowingconfigpitchfactorlockonhip"] = 1.0,
        ["crosshairfollowingconfigrangescaleinrangeb"] = 11111.0,
        ["crosshairfollowingconfigrangescaleoutrangeb"] = 6.0,
        ["crosshairfollowingconfigyawfactorads"] = 1.0,
        ["crosshairfollowingconfigyawfactorhip"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonads"] = 1.0,
        ["crosshairfollowingconfigyawfactorlockonhip"] = 1.0,
        ["lockontime"] = 0.009999999776482582,
        ["shootingconfigcdtime"] = 0.0010000000474974513,
        ["shootingconfigdeltatime"] = 0.05000000074505806,
        ["shootingconfigeffectivefovrangex"] = 11.0,
        ["shootingconfigeffectivefovrangey"] = 1555.0,
        ["shootingconfigpitchfactorads"] = 1.0,
        ["shootingconfigpitchfactorhip"] = 1.0,
        ["shootingconfigrangescaleinrangeb"] = 22222.0,
        ["shootingconfigrangescaleoutrangeb"] = 3.0,
        ["shootingconfigyawfactorads"] = 1.0,
        ["shootingconfigyawfactorhip"] = 1.0,
    },
    [1004] = {
        ["coneanglebase"] = 15.0,
        ["coneanglepower"] = 3.0,
        ["coneheightbase"] = 44444.0,
        ["coneheightpower"] = 3.0,
        ["crosshairdampingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckerinrangeb"] = 3.0,
        ["crosshairdampingconfigouter2innerrangeforraycheckeroutrangeb"] = 3.0,
        ["crosshairdampingconfigrangescaleinrangeb"] = 7777.0,
        ["crosshairdampingconfigrangescaleoutrangeb"] = 3.0,
        ["crosshairfollowingconfigeffectivefovrangey"] = 1555.0,
        ["crosshairfollowingconfigrangescaleinrangeb"] = 7777.0,
        ["crosshairfollowingconfigrangescaleoutrangeb"] = 3.0,
        ["lockontime"] = 0.0010000000474974513,
        ["shootingconfigcdtime"] = 0.0010000000474974513,
        ["shootingconfigeffectivefovrangex"] = 11.0,
        ["shootingconfigeffectivefovrangey"] = 1555.0,
        ["shootingconfigrangescaleinrangeb"] = 7000.0,
        ["shootingconfigrangescaleoutrangeb"] = 3.0,
    },
}

function M.qualify_profile_key(normalize, table_name, field)
    local name, key = normalize(table_name), normalize(field)
    for _, part in ipairs({"shootingconfig", "crosshairfollowingconfig", "crosshairdampingconfig", "zoominginconfig", "activetrackingconfig"}) do
        local start = name:find(part, 1, true)
        if start then
            local qualified = name:sub(start)
            if key ~= "" and qualified:sub(-#key) ~= key then qualified = qualified .. key end
            return qualified
        end
    end
    return key
end

function M.profile_lookup(normalize, row_id, table_name, field)
    local profile = M.PROFILE_VALUES[tonumber(row_id)]
    if type(profile) ~= "table" then return nil, nil end
    local qualified = M.qualify_profile_key(normalize, table_name, field)
    return profile[qualified], qualified
end

return M

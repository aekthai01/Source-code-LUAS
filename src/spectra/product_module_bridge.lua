local S = ...
assert(type(S) == "table", "spectra module table required")
local Source = assert(S.ProductModule, "ProductModule required")
local M = {}
S.ProductModuleBridge = M

M.METHODS = {
    "CheckEquipmentBeforEnterGameProcess",
    "_CheckProcess",
    "_CheckEquipmentValue",
    "GetAllEquipmentValue",
    "_CheckMedicine",
    "_CheckUnCarryMedicine",
    "_CheckContainer",
    "_CheckBullet",
    "_CheckDurabulity",
    "CheckEquipSlotEmpty",
    "CheckEquipSlotValue",
}
M.ROOT_METHOD_COUNT = 29

local product
local originals = {}
local installed = {}
local last_error

local function get_logger_dependencies(fn, overrides)
    overrides = type(overrides) == "table" and overrides or {}
    local logger, error_logger = overrides.logger, overrides.error_logger
    if type(logger) == "function" and type(error_logger) == "function" then
        return { logger = logger, error_logger = error_logger }
    end
    local debug_lib = rawget(_G, "debug")
    if type(debug_lib) ~= "table" or type(debug_lib.getupvalue) ~= "function" then return nil end
    local ok1, _, captured_logger = pcall(debug_lib.getupvalue, fn, 1) -- P0.3 U0
    local ok3, _, captured_error_logger = pcall(debug_lib.getupvalue, fn, 3) -- P0.3 U2
    if ok1 and ok3 and type(captured_logger) == "function"
        and type(captured_error_logger) == "function" then
        return { logger = captured_logger, error_logger = captured_error_logger }
    end
    return nil
end

local function get_bullet_dependencies(fn, target, overrides)
    overrides = type(overrides) == "table" and overrides or {}
    local item_helper, debug_logger, captured_module, error_logger =
        overrides.item_helper, overrides.debug_logger, overrides.captured_module, overrides.error_logger
    if item_helper == nil or debug_logger == nil or captured_module == nil or error_logger == nil then
        local debug_lib = rawget(_G, "debug")
        if type(debug_lib) ~= "table" or type(debug_lib.getupvalue) ~= "function" then return nil end
        local values = {}
        for index = 2, 5 do
            local ok, _, value = pcall(debug_lib.getupvalue, fn, index)
            if not ok then return nil end
            values[index] = value
        end
        item_helper = item_helper or values[2]
        debug_logger = debug_logger or values[3]
        captured_module = captured_module or values[4]
        error_logger = error_logger or values[5]
    end

    -- P0.7 captures these values rather than looking them up in a global
    -- namespace. Require the captured module identity to match the product
    -- table whose method will be replaced; otherwise delayed/dynamic calls
    -- could cross payload and source ownership.
    if type(item_helper) ~= "table" or type(item_helper.GetSubTypeById) ~= "function"
        or type(debug_logger) ~= "function" or captured_module ~= target
        or type(target.GetMatchBulletNumByWeaponItem) ~= "function"
        or type(error_logger) ~= "function" then
        return nil
    end
    return {
        item_helper = item_helper,
        debug_logger = debug_logger,
        captured_module = captured_module,
        error_logger = error_logger,
    }
end

local function get_slot_value_dependencies(fn, overrides)
    overrides = type(overrides) == "table" and overrides or {}
    local price_logger = overrides.price_logger
    if price_logger == nil then
        local debug_lib = rawget(_G, "debug")
        if type(debug_lib) ~= "table" or type(debug_lib.getupvalue) ~= "function" then return nil end
        local ok, _, value = pcall(debug_lib.getupvalue, fn, 2) -- P0.10 U1
        if not ok then return nil end
        price_logger = value
    end
    if type(price_logger) ~= "function" then return nil end
    return { price_logger = price_logger }
end

local function get_durability_dependencies(fn, overrides)
    overrides = type(overrides) == "table" and overrides or {}
    local error_logger = overrides.error_logger
    if error_logger == nil then
        local debug_lib = rawget(_G, "debug")
        if type(debug_lib) ~= "table" or type(debug_lib.getupvalue) ~= "function" then return nil end
        local ok, _, value = pcall(debug_lib.getupvalue, fn, 2) -- P0.8 U1, captured error logger
        if not ok then return nil end
        error_logger = value
    end
    if type(error_logger) ~= "function" then return nil end
    return { error_logger = error_logger }
end

local function wrap(name, target, dependencies, environment)
    return function(...)
        local arguments = table.pack(...)
        local result
        if name == "_CheckUnCarryMedicine" then
            -- Payload P0.5 is a public two-argument helper. Preserve those
            -- arguments and adapt only the reconstructed environment context.
            result = table.pack(pcall(target, product, environment, arguments[1], arguments[2]))
        elseif name == "CheckEquipSlotEmpty" then
            -- P0.9's exact public input is the slot type. Preserve all caller
            -- arguments after inserting the source module/environment context.
            result = table.pack(pcall(target, product, environment,
                table.unpack(arguments, 1, arguments.n)))
        elseif name == "CheckEquipSlotValue" then
            -- P0.10 has one fixed public argument and one captured logger.
            result = table.pack(pcall(target, product, environment, arguments[1], dependencies))
        else
            result = table.pack(pcall(target, product, environment, dependencies))
        end
        if not result[1] then
            last_error = tostring(result[2])
            -- These routines can reset data, add abnormalities, or emit an
            -- event before an exception. Retrying the payload closure could
            -- duplicate those effects, so preserve its error behavior without
            -- automatic retry. The original method remains restorable.
            error(result[2], 0)
        end
        last_error = nil
        return table.unpack(result, 2, result.n)
    end
end

local function default_set_method(target, name, value)
    rawset(target, name, value)
end

function M.install(target, options)
    if next(installed) ~= nil then return true end
    if type(target) ~= "table" then return false, "payload product table missing" end
    options = type(options) == "table" and options or {}
    local environment = options.environment or _G
    for _, name in ipairs(M.METHODS) do
        if type(rawget(target, name)) ~= "function" then
            return false, "payload method missing: " .. name
        end
    end

    local source_targets = {
        CheckEquipmentBeforEnterGameProcess = Source.CheckEquipmentBeforEnterGameProcess,
        _CheckProcess = Source._CheckProcess,
        _CheckEquipmentValue = Source._CheckEquipmentValue,
        _CheckMedicine = Source._CheckMedicine,
        _CheckUnCarryMedicine = Source._CheckUnCarryMedicine,
        _CheckContainer = Source._CheckContainer,
        CheckEquipSlotEmpty = Source.CheckEquipSlotEmpty,
    }
    local p3_dependencies = get_logger_dependencies(rawget(target, "GetAllEquipmentValue"), options.dependencies)
    if p3_dependencies then source_targets.GetAllEquipmentValue = Source.GetAllEquipmentValue end
    local bullet_dependencies = get_bullet_dependencies(
        rawget(target, "_CheckBullet"), target, options.bullet_dependencies)
    if bullet_dependencies then source_targets._CheckBullet = Source._CheckBullet end
    local durability_dependencies = get_durability_dependencies(
        rawget(target, "_CheckDurabulity"), options.durability_dependencies)
    if durability_dependencies then source_targets._CheckDurabulity = Source._CheckDurabulity end
    local slot_value_dependencies = get_slot_value_dependencies(
        rawget(target, "CheckEquipSlotValue"), options.price_dependencies)
    if slot_value_dependencies then source_targets.CheckEquipSlotValue = Source.CheckEquipSlotValue end

    local set_method = options.set_method or default_set_method
    local pending_originals, pending_wrappers = {}, {}
    for _, name in ipairs(M.METHODS) do
        local source_target = source_targets[name]
        if source_target then
            pending_originals[name] = rawget(target, name)
            local dependencies = name == "GetAllEquipmentValue" and p3_dependencies
                or (name == "_CheckBullet" and bullet_dependencies
                or (name == "_CheckDurabulity" and durability_dependencies
                or (name == "CheckEquipSlotValue" and slot_value_dependencies or nil)))
            pending_wrappers[name] = wrap(name, source_target, dependencies, environment)
        end
    end

    for _, name in ipairs(M.METHODS) do
        local replacement = pending_wrappers[name]
        if replacement then
            local ok, err = pcall(set_method, target, name, replacement)
            if ok and rawget(target, name) ~= replacement then
                ok, err = false, "payload method replacement did not stick: " .. name
            end
            if not ok then
                for restore_name, original in pairs(pending_originals) do
                    rawset(target, restore_name, original)
                end
                originals, installed = {}, {}
                last_error = tostring(err)
                return false, last_error
            end
        end
    end
    originals, installed = pending_originals, pending_wrappers
    product = target
    last_error = nil
    return true, {
        methods = M.owned_methods(),
        p3_logger_captures = p3_dependencies ~= nil,
        p7_captures = bullet_dependencies ~= nil,
        p8_error_logger_capture = durability_dependencies ~= nil,
        p10_price_logger_capture = slot_value_dependencies ~= nil,
    }
end

function M.after_payload_load(target, options)
    return M.install(target, options)
end

function M.restore_original()
    if type(product) == "table" then
        for name, original in pairs(originals) do
            rawset(product, name, original)
        end
    end
    product, originals, installed = nil, {}, {}
    last_error = nil
    return true
end

function M.owned_methods()
    local result = {}
    for _, name in ipairs(M.METHODS) do result[name] = installed[name] ~= nil end
    return result
end

function M.status()
    local ownership = M.owned_methods()
    local count = 0
    for _, name in ipairs(M.METHODS) do if ownership[name] then count = count + 1 end end
    return {
        installed = count > 0,
        source_owned_root_methods = count,
        root_methods_total = M.ROOT_METHOD_COUNT,
        methods = ownership,
        last_error = last_error,
    }
end

return M

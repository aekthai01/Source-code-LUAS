local S = ...
assert(type(S) == "table", "spectra module table required")
local Source = assert(S.ProductModule, "ProductModule required")
local Context = assert(S.ProductContext, "ProductContext required")
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
    "DynamicGuidPriceFinishFetch",
    "CheckRaidBulletEnough",
    "GetMatchBulletNumByWeaponItem",
}
M.ROOT_METHOD_COUNT = 29

local product
local originals = {}
local installed = {}
local last_error
local active_context

local function dependency_sets(context)
    return {
        GetAllEquipmentValue = {
            logger = context.info_logger,
            error_logger = context.error_logger,
        },
        _CheckBullet = {
            item_helper = context.item_helper,
            debug_logger = context.debug_logger,
            error_logger = context.error_logger,
        },
        _CheckDurabulity = {
            error_logger = context.error_logger,
        },
        CheckEquipSlotValue = {
            price_logger = context.info_logger,
        },
        CheckRaidBulletEnough = {
            error_logger = context.error_logger,
            info_logger = context.info_logger,
            globals = context.globals,
            product = context.product,
        },
        GetMatchBulletNumByWeaponItem = {
            ammo_data_manager = context.ammo_data_manager,
            weapon_assembly_tool = context.weapon_assembly_tool,
        },
    }
end

local function wrap(name, target, dependencies, environment)
    return function(...)
        local arguments = table.pack(...)
        local result
        if name == "_CheckUnCarryMedicine" then
            result = table.pack(pcall(target, product, environment, arguments[1], arguments[2]))
        elseif name == "CheckEquipSlotEmpty" then
            result = table.pack(pcall(target, product, environment,
                table.unpack(arguments, 1, arguments.n)))
        elseif name == "CheckEquipSlotValue" then
            result = table.pack(pcall(target, product, environment, arguments[1], dependencies))
        elseif name == "DynamicGuidPriceFinishFetch" then
            result = table.pack(pcall(target, product, environment, arguments[1]))
        elseif name == "CheckRaidBulletEnough" then
            result = table.pack(pcall(target, product, dependencies.globals or environment,
                dependencies, arguments[1]))
        elseif name == "GetMatchBulletNumByWeaponItem" then
            result = table.pack(pcall(target, product, dependencies.globals or environment,
                dependencies.ammo_data_manager, dependencies.weapon_assembly_tool,
                arguments[1], arguments[2]))
        else
            result = table.pack(pcall(target, product, environment, dependencies))
        end
        if not result[1] then
            last_error = tostring(result[2])
            -- Do not retry the saved payload method after a source exception:
            -- these methods can already have emitted logs/events or mutated
            -- abnormal state before throwing.
            error(result[2], 0)
        end
        last_error = nil
        return table.unpack(result, 2, result.n)
    end
end

local function default_set_method(target, name, value)
    rawset(target, name, value)
end

local function resolve_context(options, environment)
    if type(options.context) == "table" then
        local ok, why = Context.validate(options.context)
        if not ok then return nil, why end
        return options.context
    end
    local ok, value = pcall(Context.create, environment)
    if not ok then return nil, tostring(value) end
    local valid, why = Context.validate(value)
    if not valid then return nil, why end
    return value
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

    -- Transitional installation still overlays the payload-created product
    -- table, but every captured P0 root dependency now comes from source
    -- ProductContext. No payload closure introspection is used here.
    local context, context_error = resolve_context(options, environment)
    if not context then
        last_error = context_error
        return false, context_error
    end
    local dependencies = dependency_sets(context)
    local source_targets = {
        CheckEquipmentBeforEnterGameProcess = Source.CheckEquipmentBeforEnterGameProcess,
        _CheckProcess = Source._CheckProcess,
        _CheckEquipmentValue = Source._CheckEquipmentValue,
        GetAllEquipmentValue = Source.GetAllEquipmentValue,
        _CheckMedicine = Source._CheckMedicine,
        _CheckUnCarryMedicine = Source._CheckUnCarryMedicine,
        _CheckContainer = Source._CheckContainer,
        _CheckBullet = Source._CheckBullet,
        _CheckDurabulity = Source._CheckDurabulity,
        CheckEquipSlotEmpty = Source.CheckEquipSlotEmpty,
        CheckEquipSlotValue = Source.CheckEquipSlotValue,
        DynamicGuidPriceFinishFetch = Source.DynamicGuidPriceFinishFetch,
        CheckRaidBulletEnough = Source.CheckRaidBulletEnough,
        GetMatchBulletNumByWeaponItem = Source.GetMatchBulletNumByWeaponItem,
    }

    local set_method = options.set_method or default_set_method
    local pending_originals, pending_wrappers = {}, {}
    for _, name in ipairs(M.METHODS) do
        pending_originals[name] = rawget(target, name)
        pending_wrappers[name] = wrap(name, source_targets[name], dependencies[name], environment)
    end

    for _, name in ipairs(M.METHODS) do
        local replacement = pending_wrappers[name]
        local ok, err = pcall(set_method, target, name, replacement)
        if ok and rawget(target, name) ~= replacement then
            ok, err = false, "payload method replacement did not stick: " .. name
        end
        if not ok then
            for restore_name, original in pairs(pending_originals) do
                rawset(target, restore_name, original)
            end
            originals, installed, active_context = {}, {}, nil
            last_error = tostring(err)
            return false, last_error
        end
    end

    originals, installed = pending_originals, pending_wrappers
    product = target
    active_context = context
    last_error = nil
    return true, {
        methods = M.owned_methods(),
        source_context = true,
        source_only_dependency = true,
        payload_upvalue_introspection = false,
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
    product, originals, installed, active_context = nil, {}, {}, nil
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
        source_context = active_context ~= nil,
        source_only_dependency = active_context ~= nil,
        payload_upvalue_introspection = false,
        last_error = last_error,
    }
end

return M

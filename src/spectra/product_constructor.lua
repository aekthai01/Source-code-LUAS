local S = ...
assert(type(S) == "table", "spectra module table required")
local Product = assert(S.ProductModule, "ProductModule required")
local M = {}
S.ProductConstructor = M

function M.new_product_table()
    return {}
end

local function bind(product, globals, source, dependencies, mode)
    if mode == "night_zero_arg_item_base" then
        return function()
            return source(product, globals, dependencies.item_base_tool)
        end
    end
    if mode == "night_one_arg_item_base" then
        return function(a)
            return source(product, globals, dependencies.item_base_tool, a)
        end
    end
    if mode == "weapon_count" then
        return function(weapon_item, slot_group_id)
            return source(product, globals, dependencies.ammo_data_manager,
                dependencies.weapon_assembly_tool, weapon_item, slot_group_id)
        end
    end
    if mode == "static_one_arg_deps" then
        return function(a)
            return source(product, globals, dependencies, a)
        end
    end
    if mode == "one_arg_deps" then
        return function(a)
            return source(product, globals, a, dependencies)
        end
    end
    if mode == "one_arg" then
        return function(a)
            return source(product, globals, a)
        end
    end
    if mode == "two_args" then
        return function(a, b)
            return source(product, globals, a, b)
        end
    end
    if mode == "slot" then
        return function(slot_type)
            return source(product, globals, slot_type)
        end
    end
    if mode == "slot_deps" then
        return function(slot_type)
            return source(product, globals, slot_type, dependencies)
        end
    end
    return function()
        return source(product, globals, dependencies)
    end
end

-- Source-only constructor for the reconstructed P0.0..P0.15 boundary. The
-- context's R3 table is used directly so every root capture of the product
-- table observes the same source identity. Later root groups extend this same
-- table rather than swapping in a payload-created object.
function M.create(context, globals)
    assert(type(context) == "table", "ProductContext required")
    globals = globals or context.globals or _G
    local product = assert(context.product, "source product table required")
    assert(type(product) == "table", "source product table must be a table")

    local p3 = { logger = context.info_logger, error_logger = context.error_logger }
    local p7 = {
        item_helper = context.item_helper,
        debug_logger = context.debug_logger,
        error_logger = context.error_logger,
    }
    local p8 = { error_logger = context.error_logger }
    local p10 = { price_logger = context.info_logger }

    product.CheckEquipmentBeforEnterGameProcess = bind(product, globals,
        Product.CheckEquipmentBeforEnterGameProcess)
    product._CheckProcess = bind(product, globals, Product._CheckProcess)
    product._CheckEquipmentValue = bind(product, globals, Product._CheckEquipmentValue)
    product.GetAllEquipmentValue = bind(product, globals, Product.GetAllEquipmentValue, p3)
    product._CheckMedicine = bind(product, globals, Product._CheckMedicine)
    product._CheckUnCarryMedicine = bind(product, globals, Product._CheckUnCarryMedicine, nil, "two_args")
    product._CheckContainer = bind(product, globals, Product._CheckContainer)
    product._CheckBullet = bind(product, globals, Product._CheckBullet, p7)
    product._CheckDurabulity = bind(product, globals, Product._CheckDurabulity, p8)
    product.CheckEquipSlotEmpty = bind(product, globals, Product.CheckEquipSlotEmpty, nil, "slot")
    product.CheckEquipSlotValue = bind(product, globals, Product.CheckEquipSlotValue, p10, "slot_deps")
    product.DynamicGuidPriceFinishFetch = bind(product, globals,
        Product.DynamicGuidPriceFinishFetch, nil, "one_arg")
    local p12 = {
        error_logger = context.error_logger,
        info_logger = context.info_logger,
        globals = globals,
    }
    product.CheckRaidBulletEnough = bind(product, globals,
        Product.CheckRaidBulletEnough, p12, "static_one_arg_deps")
    local p13 = {
        ammo_data_manager = context.ammo_data_manager,
        weapon_assembly_tool = context.weapon_assembly_tool,
    }
    product.GetMatchBulletNumByWeaponItem = bind(product, globals,
        Product.GetMatchBulletNumByWeaponItem, p13, "weapon_count")
    local p14_p15 = { item_base_tool = context.item_base_tool }
    product._CheckNightFight = bind(product, globals,
        Product._CheckNightFight, p14_p15, "night_zero_arg_item_base")
    product._CheckPlayerSuppliesForNightSpeicalType = bind(product, globals,
        Product._CheckPlayerSuppliesForNightSpeicalType, p14_p15, "night_one_arg_item_base")

    local slot = assert(globals.ESlotType, "ESlotType required")
    product.EquipTypeList = {
        slot.MainWeaponLeft,
        slot.MainWeaponRight,
        slot.Pistrol,
        slot.BreastPlate,
        slot.Helmet,
        slot.ChestHanging,
        slot.Bag,
    }
    product.ContainerTypeList = {
        slot.ChestHangingContainer,
        slot.Pocket,
        slot.BagContainer,
        slot.SafeBoxContainer,
    }
    return product
end

-- Keep the requested public constructor shape on the source module itself.
Product.create = M.create

return M

local S = ...
assert(type(S) == "table", "spectra module table required")
local Product = assert(S.ProductModule, "ProductModule required")
local M = {}
S.ProductConstructor = M

function M.new_product_table()
    return {}
end

local function bind(product, globals, source, dependencies, mode)
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

-- Source-only constructor for the reconstructed P0.0..P0.10 boundary. The
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

local S = ...
assert(type(S) == "table", "spectra module table required")
local M = {}
S.ProductContext = M

-- Source reconstruction of P0 root registers R0..R11. Descriptive field names
-- come from child use sites and ROOT_CAPTURE_MAP, not stripped debug symbols.
M.REQUIRE_PATHS = {
    "DFM.StandaloneLua.BusinessTool.ItemHelperTool",
    "DFM.StandaloneLua.BusinessTool.StructTool.ItemConfigTool",
    "DFM.StandaloneLua.BusinessTool.StructTool.WeaponAssemblyTool",
    "DFM.StandaloneLua.BusinessTool.WeaponHelperTool",
    "DFM.StandaloneLua.BusinessTool.StructTool.ItemBaseTool",
    "DFM.Business.Module.ArmedForceModule.Logic.ArmedForce.ArmedForceExpiredLogic",
}

local function need_function(value, name)
    assert(type(value) == "function", name .. " function required")
    return value
end

function M.create(globals)
    globals = globals or _G
    assert(type(globals) == "table", "runtime globals table required")

    -- P0 instructions 3..6: one category call, three open results into R0/R1/R2.
    local gen_log = need_function(globals.GenLocalLogFunc, "GenLocalLogFunc")
    local category_table = assert(globals.ELuaLogCategory, "ELuaLogCategory required")
    local category = category_table.LuaMArmedForce
    local debug_logger, info_logger, error_logger = gen_log(category)

    -- P0 R3 is a new table before any exported method closure is created.
    local product = {}

    -- P0 instructions 8..25: six plain require calls in this exact order.
    local require_fn = need_function(globals.require, "require")
    local item_helper = require_fn(M.REQUIRE_PATHS[1])
    local item_config_tool = require_fn(M.REQUIRE_PATHS[2])
    local weapon_assembly_tool = require_fn(M.REQUIRE_PATHS[3])
    local weapon_helper_tool = require_fn(M.REQUIRE_PATHS[4])
    local item_base_tool = require_fn(M.REQUIRE_PATHS[5])
    local armed_force_expired_logic = require_fn(M.REQUIRE_PATHS[6])

    -- P0 instructions 26..30: import then call the fetched Get function with
    -- no implicit self (CALL B=1).
    local import_fn = need_function(globals.import, "import")
    local ammo_data_manager_module = import_fn("AmmoDataManager")
    local get_ammo_data_manager = ammo_data_manager_module.Get
    local ammo_data_manager = get_ammo_data_manager()

    return {
        globals = globals,
        debug_logger = debug_logger,      -- P0 R0
        info_logger = info_logger,        -- P0 R1; P0.10 price logger uses the same capture
        error_logger = error_logger,      -- P0 R2
        product = product,                -- P0 R3
        item_helper = item_helper,        -- P0 R4
        item_config_tool = item_config_tool, -- P0 R5
        weapon_assembly_tool = weapon_assembly_tool, -- P0 R6
        weapon_helper_tool = weapon_helper_tool, -- P0 R7
        item_base_tool = item_base_tool,  -- P0 R8
        armed_force_expired_logic = armed_force_expired_logic, -- P0 R9
        ammo_data_manager_module = ammo_data_manager_module, -- P0 R10
        ammo_data_manager = ammo_data_manager, -- P0 R11
    }
end

function M.validate(context)
    if type(context) ~= "table" then return false, "product context missing" end
    if type(context.product) ~= "table" then return false, "source product table missing" end
    if type(context.debug_logger) ~= "function" then return false, "debug logger missing" end
    if type(context.info_logger) ~= "function" then return false, "info logger missing" end
    if type(context.error_logger) ~= "function" then return false, "error logger missing" end
    if type(context.item_helper) ~= "table" or type(context.item_helper.GetSubTypeById) ~= "function" then
        return false, "ItemHelperTool capture missing GetSubTypeById"
    end
    if context.item_config_tool == nil then return false, "ItemConfigTool missing" end
    if context.weapon_assembly_tool == nil then return false, "WeaponAssemblyTool missing" end
    if context.weapon_helper_tool == nil then return false, "WeaponHelperTool missing" end
    if context.item_base_tool == nil then return false, "ItemBaseTool missing" end
    if context.armed_force_expired_logic == nil then return false, "ArmedForceExpiredLogic missing" end
    if context.ammo_data_manager_module == nil then return false, "AmmoDataManager import missing" end
    if context.ammo_data_manager == nil then return false, "AmmoDataManager.Get() result missing" end
    return true
end

return M

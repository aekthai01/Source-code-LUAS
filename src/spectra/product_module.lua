local S = ...
assert(type(S) == "table", "spectra module table required")
local M = {}
S.ProductModule = M

-- P0.0..P0.10 are reconstructed descriptions of stripped closures. Exported
-- field names below are exact strings recovered from root P0 bytecode.
M.PROTOTYPES = {
    CheckEquipmentBeforEnterGameProcess = "0.0",
    _CheckProcess = "0.1",
    _CheckEquipmentValue = "0.2",
    GetAllEquipmentValue = "0.3",
    _CheckMedicine = "0.4",
    _CheckUnCarryMedicine = "0.5",
    _CheckContainer = "0.6",
    _CheckBullet = "0.7",
    _CheckDurabulity = "0.8",
    CheckEquipSlotEmpty = "0.9",
    CheckEquipSlotValue = "0.10",
    DynamicGuidPriceFinishFetch = "0.11",
    CheckRaidBulletEnough = "0.12",
}
M.ROOT_FIELDS = { "EquipTypeList", "ContainerTypeList" }

local function globals_or_default(value)
    return value or _G
end

function M.CheckEquipmentBeforEnterGameProcess(module, globals)
    globals = globals_or_default(globals)
    local manager = globals.Facade.GameFlowManager

    -- P0.0 fetches CheckMainFlowSOL before calling GetCurrentGameFlow, and
    -- forwards every returned flow value. If the check is false it fetches
    -- and calls GetCurrentGameFlow a second time, then compares only result 1
    -- with EGameFlowStageType.Lobby. Preserve that control flow literally.
    local check_main, check_self = manager.CheckMainFlowSOL, manager
    local get_flow, flow_self = manager.GetCurrentGameFlow, manager
    local check_result = check_main(check_self, get_flow(flow_self))
    if not check_result then
        local current_flow = manager.GetCurrentGameFlow(manager)
        if current_flow == globals.EGameFlowStageType.Lobby then return end
    end

    local field = globals.Module.ArmedForce.Field
    field:ResetEquipAbnormalDatas()
    module._CheckProcess()
    local changed = globals.Module.ArmedForce.Config.evtEquipAbnormalChanged
    changed:Invoke()
end

function M._CheckProcess(module, globals)
    globals = globals_or_default(globals)
    -- P0.1: exact bytecode call order; these exported methods are plain
    -- function calls (no implicit module receiver).
    module._CheckBullet()
    module._CheckDurabulity()
    module._CheckContainer()
    module._CheckMedicine()
    module._CheckEquipmentValue()
    module._CheckNightFight()
    module.CheckRentalConsumableID()
    module._CheckSafeBoxExpiredStatus()
    module._CheckKeyChainExpiredStatus()
    module._CheckPropExpiredStatus()
    globals.Module.ArmedForce.Field:SortEquipAbnormal()
end

local function add_equipment_abnormal(globals, data, abnormal_type_name, need_value, current_value)
    local field = globals.Module.ArmedForce.Field
    local add = field.AddEquipAbnormal -- SELF fetch precedes argument construction in P0.2.
    local abnormal = {}
    abnormal.key = data.key
    abnormal.abnormalType = globals.Module.ArmedForce.Config.EAbnormalType[abnormal_type_name]
    abnormal.loc = data.abnormalDesc
    local param = {}
    param.needValue = need_value
    param.curAllValue = current_value
    abnormal.param = param
    add(field, abnormal)
end

function M._CheckEquipmentValue(module, globals)
    globals = globals_or_default(globals)
    local current_value = module.GetAllEquipmentValue()
    local need_value, max_value = globals.Server.GameModeServer:GetMapNeedValue()
    local lower_field = globals.Module.ArmedForce.Field
    local lower_get_data = lower_field.GetEquipmentCheckData
    local lower_type = globals.Module.ArmedForce.Config.EAbnormalType.EquipmentAllValueNotEnough
    local lower_data = lower_get_data(lower_field, lower_type, 0)
    if lower_data and lower_data.switch and need_value ~= 0 and current_value < need_value then
        add_equipment_abnormal(globals, lower_data, "EquipmentAllValueNotEnough", need_value, current_value)
    end

    local upper_field = globals.Module.ArmedForce.Field
    local upper_get_data = upper_field.GetEquipmentCheckData
    local upper_type = globals.Module.ArmedForce.Config.EAbnormalType.EquipmentAllValueExceeds
    local upper_data = upper_get_data(upper_field, upper_type, 0)
    if upper_data and upper_data.switch and max_value ~= 0 and max_value < current_value then
        add_equipment_abnormal(globals, upper_data, "EquipmentAllValueExceeds", max_value, current_value)
    end
end

local function emit_log(logger, message)
    if type(logger) == "function" then logger(message) end
end

function M.GetAllEquipmentValue(module, globals, dependencies)
    globals = globals_or_default(globals)
    dependencies = dependencies or {}
    local logger, error_logger = dependencies.logger, dependencies.error_logger
    emit_log(logger, "CheckEquipLogic.GetAllEquipmentValue ============================= START =============================")

    local challenge = globals.Module.LobbySOLChallenge:CheckInSOLChallengeMode()
    local currency_type
    if challenge then
        currency_type = globals.ECurrencyClientType.SOLChallengeCoin
        if not currency_type then currency_type = globals.ECurrencyClientType.OnlyUnBind end
    else
        currency_type = globals.ECurrencyClientType.OnlyUnBind
    end

    local server = globals.Server.ArmedForceServer
    local total_value
    if server:CheckIsRentalStatus() then
        local rental_plan = server:GetCurRentalPlan()
        if rental_plan then
            total_value = rental_plan.preset_price
            local format = globals.string.format
            emit_log(logger, format(
                "CheckEquipLogic.GetAllEquipmentValue 【IsRentalStatus】result ==> consumable_id = %s, type_id = %s, preset_id = %s, totalValue = %s",
                rental_plan.consumable_id, rental_plan.type_id, rental_plan.preset_id, total_value))
        else
            emit_log(error_logger,
                "CheckEquipLogic.GetAllEquipmentValue IsRentalStatus but curRentalPlan is nil!!!")
            total_value = 0
        end
    else
        local slots = {
            globals.ESlotType.Helmet,
            globals.ESlotType.BreastPlate,
            globals.ESlotType.ChestHanging,
            globals.ESlotType.Bag,
            globals.ESlotType.MainWeaponLeft,
            globals.ESlotType.MainWeaponRight,
            globals.ESlotType.Pistrol,
        }
        total_value = 0
        for _, slot in pairs(slots) do
            total_value = total_value + module.CheckEquipSlotValue(slot)
        end
        local group_id = server:GetCurSlotGroupId()
        local format = globals.string.format
        emit_log(logger, format(
            "CheckEquipLogic.GetAllEquipmentValue 【%s】result ==> totalValue = %s",
            group_id, total_value))
    end

    emit_log(logger, "CheckEquipLogic.GetAllEquipmentValue ============================= END =============================")
    globals.Module.ArmedForce.Config.evtAllEquipmentValueChanged:Invoke(total_value, currency_type)
    return total_value, currency_type
end

-- P0.5: for each value yielded by the captured enum list, query the
-- LackMedicine check. Keep ipairs order, table.contains argument order,
-- switch filtering, and the lack of output deduplication from the bytecode.
-- This is a reconstructed function name only where root P0 exports the exact
-- public field `_CheckUnCarryMedicine`; stripped local names are not inferred.
function M._CheckUnCarryMedicine(module, globals, medicine_type_values, carried_medicine_types)
    globals = globals_or_default(globals)
    local result = {
        key = 0,
        unCarryMedicinesTypeList = {},
        unCarryMedicinesTypeStrList = {},
    }
    for _, medicine_type in globals.ipairs(medicine_type_values) do
        local field = globals.Module.ArmedForce.Field
        local get_check_data = field.GetEquipmentCheckData
        local abnormal_type = globals.Module.ArmedForce.Config.EAbnormalType.LackMedicine
        local check_data = get_check_data(field, abnormal_type, medicine_type)
        if check_data and check_data.switch
            and not globals.table.contains(carried_medicine_types, medicine_type) then
            result.key = globals.math.max(result.key, check_data.key)
            globals.table.insert(result.unCarryMedicinesTypeList, medicine_type)
            globals.table.insert(result.unCarryMedicinesTypeStrList, check_data.abnormalDesc)
        end
    end
    return result
end

-- P0.4 captures the root module table and reads its `_CheckUnCarryMedicine`
-- field at call time. It passes (table.values(EDispensingMedicineType),
-- Field:GetMedicineType()) in that order. The only emitted abnormal is
-- LackMedicine, and it is gated by a nonempty result list.
function M._CheckMedicine(module, globals)
    globals = globals_or_default(globals)
    local medicine_field = globals.Module.ArmedForce.Field
    local get_medicine_types = medicine_field.GetMedicineType
    local carried_medicine_types = get_medicine_types(medicine_field)
    local check_missing = module._CheckUnCarryMedicine
    local values = globals.table.values
    local medicine_type_enum = globals.EDispensingMedicineType
    local medicine_type_values = values(medicine_type_enum)
    local missing = check_missing(medicine_type_values, carried_medicine_types)
    if missing and #missing.unCarryMedicinesTypeList > 0 then
        local concat = globals.table.concat
        local descriptions = missing.unCarryMedicinesTypeStrList
        local comma = globals.CommonConfig.Loc.Comma
        local joined = concat(descriptions, comma)
        local add_field = globals.Module.ArmedForce.Field
        local add_abnormal = add_field.AddEquipAbnormal
        local abnormal = { key = missing.key }
        abnormal.abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.LackMedicine
        abnormal.loc = globals.string.format(
            globals.Module.ArmedForce.Config.Loc.UnableToResolveTheState, joined)
        abnormal.param = { abnormalTypeList = missing.unCarryMedicinesTypeList }
        add_abnormal(add_field, abnormal)
    end
end

-- P0.6 `_CheckContainer`: sum free/total capacity for the three recovered
-- slots, optionally add the storage-space abnormal, then inspect the selected
-- safe-box group and add medicine types from each slot's items. Method names,
-- constants, tolerances and comparison directions come directly from P0.6.
function M._CheckContainer(module, globals)
    globals = globals_or_default(globals)

    -- Reconstructed descriptive name for nested prototype P0.6.0, created at
    -- P0.6 entry and capturing this invocation's runtime environment.
    local function add_medicine_types_from_items(items)
        if not items then return end
        for _, item in globals.pairs(items) do
            if item.itemMainType == globals.EItemType.Medicine then
                local health_feature = item:GetFeature(globals.EFeatureType.Health)
                if health_feature and health_feature.medicineType then
                    local field = globals.Module.ArmedForce.Field
                    local add_medicine_type = field.AddMedicineType
                    add_medicine_type(field, health_feature.medicineType)
                end
            end
        end
    end

    local initial_field = globals.Module.ArmedForce.Field
    local get_check_data = initial_field.GetEquipmentCheckData
    local storage_type = globals.Module.ArmedForce.Config.EAbnormalType.StorageSpaceIsTight
    local storage_data = get_check_data(initial_field, storage_type, 0)

    local total_capacity, remaining_capacity = 0, 0
    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()
    local function inspect_slot(slot_name)
        local slot = globals.Server.InventoryServer:GetSlot(
            globals.ESlotType[slot_name], slot_group_id)
        local capacity = slot:GetTotalCapacity()
        capacity = capacity + 1e-6
        total_capacity = total_capacity + capacity
        local remaining = slot:GetRemainingSpaceSize()
        remaining = remaining + 1e-6
        remaining_capacity = remaining_capacity + remaining
        add_medicine_types_from_items(slot:GetItems())
    end

    inspect_slot("ChestHangingContainer")
    inspect_slot("BagContainer")
    inspect_slot("Pocket")

    if storage_data and storage_data.switch and storage_data.checkValue >= 0 then
        local math_util = globals.MathUtil
        local remaining_ratio = math_util.GetTheSecondDecimal(remaining_capacity / total_capacity)
        local configured_ratio = globals.MathUtil.GetTheSecondDecimal(storage_data.checkValue)
        if remaining_ratio < configured_ratio then
            local field = globals.Module.ArmedForce.Field
            local add_abnormal = field.AddEquipAbnormal
            local abnormal = { key = storage_data.key }
            abnormal.abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.StorageSpaceIsTight
            local format = globals.string.format
            local description = storage_data.abnormalDesc
            local get_rounded_number = globals.MathUtil.GetRoundingNum
            local rounded_values = globals.table.pack(
                get_rounded_number(storage_data.checkValue * 100))
            abnormal.loc = format(description,
                globals.table.unpack(rounded_values, 1, rounded_values.n))
            abnormal.param = {}
            add_abnormal(field, abnormal)
        end
    end

    local challenge_mode = globals.Module.LobbySOLChallenge:CheckInSOLChallengeMode()
    local safe_box_group
    if challenge_mode then
        safe_box_group = globals.ESlotGroup.SOLChallenge
    end
    if not safe_box_group then
        safe_box_group = globals.ESlotGroup.Player
    end
    local safe_box = globals.Server.InventoryServer:GetSlot(
        globals.ESlotType.SafeBoxContainer, safe_box_group)
    local used_capacity = safe_box:GetUsedCapacity()

    local current_field = globals.Module.ArmedForce.Field
    local get_safe_box_data = current_field.GetEquipmentCheckData
    local unnecessary_type = globals.Module.ArmedForce.Config.EAbnormalType.HasUnnecessaryItems
    local unnecessary_data = get_safe_box_data(current_field, unnecessary_type, 0)
    if unnecessary_data and unnecessary_data.switch and unnecessary_data.checkValue >= 0 then
        local rounded_threshold = globals.MathUtil.GetRoundingNum(unnecessary_data.checkValue)
        if rounded_threshold < used_capacity then
            local field = globals.Module.ArmedForce.Field
            local add_abnormal = field.AddEquipAbnormal
            local abnormal = { key = unnecessary_data.key }
            abnormal.abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.HasUnnecessaryItems
            abnormal.loc = unnecessary_data.abnormalDesc
            abnormal.param = {}
            add_abnormal(field, abnormal)
        end
    end

    add_medicine_types_from_items(safe_box:GetItems())
end

-- P0.7 and nested P0.7.0 reconstruct the bullet check. The nested prototype
-- name is descriptive because its original debug symbol is stripped. Captured
-- helpers remain explicit inputs so the bridge can install this method only
-- when it has recovered the original closure values.
function M._CheckBullet(module, globals, dependencies)
    globals = globals_or_default(globals)
    dependencies = assert(dependencies, "P0.7 captured dependencies required")
    local item_helper = assert(dependencies.item_helper, "P0.7 ItemHelperTool capture missing")
    local debug_logger = assert(dependencies.debug_logger, "P0.7 debug logger capture missing")
    local error_logger = assert(dependencies.error_logger, "P0.7 error logger capture missing")

    local abnormal_key = 0
    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()

    -- Reconstructed descriptive name for P0.7.0. Its four-result failure
    -- contract and one-result success contract match the bytecode's CALL C=5.
    local function inspect_bullet_slot(slot_type)
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        local item = slot:GetEquipItem()
        if not item then return true end

        local subtype = item_helper.GetSubTypeById(item.id)
        local field = globals.Module.ArmedForce.Field
        local check_data = field:GetEquipmentCheckData(
            globals.Module.ArmedForce.Config.EAbnormalType.LackBullet, subtype)
        if not check_data or not check_data.switch then return true end

        local required_bullets = globals.MathUtil.GetRoundingNum(check_data.checkValue)
        if required_bullets < 0 then
            error_logger("CheckEquipLogic._CheckBullet checkValue 小于0！！！", subtype)
            return true
        end

        debug_logger("[Debug] Get Value = ", required_bullets,
            "checkValue = ", check_data.checkValue)
        local matched_bullets = module.GetMatchBulletNumByWeaponItem(item, slot_group_id)
        if matched_bullets < required_bullets then
            local format_args = {
                BulletName = globals.ItemConfig.MapWeaponItemType2Name[subtype],
                BulletNum = required_bullets,
            }
            local location = globals.StringUtil.PluralTextFormat(check_data.abnormalDesc, format_args)
            abnormal_key = globals.math.max(abnormal_key, check_data.key)
            return false, subtype, matched_bullets - required_bullets, location
        end
        return true
    end

    local left_ok, left_subtype, _, left_location = inspect_bullet_slot(
        globals.ESlotType.MainWeaponLeft)
    local right_ok, right_subtype, _, right_location = inspect_bullet_slot(
        globals.ESlotType.MainWeaponRight)
    local pistol_ok, _, _, pistol_location = inspect_bullet_slot(globals.ESlotType.Pistrol)

    local abnormal_types, locations = {}, {}
    if not left_ok and not right_ok then
        globals.table.insert(abnormal_types, globals.ESlotType.MainWeaponLeft)
        globals.table.insert(abnormal_types, globals.ESlotType.MainWeaponRight)
        if left_subtype == right_subtype then
            globals.table.insert(locations, globals.tostring(left_location))
        else
            globals.table.insert(locations, globals.tostring(left_location))
            globals.table.insert(locations, globals.tostring(right_location))
        end
    elseif not left_ok then
        globals.table.insert(abnormal_types, globals.ESlotType.MainWeaponLeft)
        globals.table.insert(locations, globals.tostring(left_location))
    elseif not right_ok then
        globals.table.insert(abnormal_types, globals.ESlotType.MainWeaponRight)
        globals.table.insert(locations, globals.tostring(right_location))
    end

    if not pistol_ok then
        globals.table.insert(abnormal_types, globals.ESlotType.Pistrol)
        globals.table.insert(locations, globals.tostring(pistol_location))
    end

    local location
    if not globals.table.isempty(abnormal_types) then
        location = globals.table.concat(locations, globals.CommonConfig.Loc.Comma)
    end
    if location then
        local field = globals.Module.ArmedForce.Field
        local add_abnormal = field.AddEquipAbnormal
        local abnormal = {}
        abnormal.key = abnormal_key
        abnormal.abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.LackBullet
        abnormal.loc = location
        local param = {}
        param.abnormalTypeList = abnormal_types
        abnormal.param = param
        add_abnormal(field, abnormal)
    end
end

-- P0.8 and nested P0.8.0 reconstruct the helmet/breastplate durability check.
-- `check_durability_slot` is a descriptive name for stripped P0.8.0.
function M._CheckDurabulity(module, globals, dependencies)
    globals = globals_or_default(globals)
    dependencies = assert(dependencies, "P0.8 captured dependencies required")
    local error_logger = assert(dependencies.error_logger, "P0.8 error logger capture missing")

    local abnormal_key = 0
    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()

    local function check_durability_slot(slot_type)
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        local item = slot:GetEquipItem()
        if not item then return true end

        local equipment_feature = item:GetFeature(globals.EFeatureType.Equipment)
        if not equipment_feature then return true end
        if not equipment_feature:IsHelmet() and not equipment_feature:IsBreastPlate() then
            return true
        end

        local field = globals.Module.ArmedForce.Field
        local check_data = field:GetEquipmentCheckData(
            globals.Module.ArmedForce.Config.EAbnormalType.InsufficientDurability, slot_type)
        if not check_data or not check_data.switch then return true end

        local check_value = check_data.checkValue
        if not (0 <= check_value) then
            error_logger("CheckEquipLogic._CheckDurabulity checkValue 小于0！！！", slot_type)
            return true
        end
        if not check_value then return true end

        local durability = globals.MathUtil.GetTheSecondDecimal(
            equipment_feature:GetDurabilityPercent())
        local normalized_threshold = globals.MathUtil.GetTheSecondDecimal(check_value)
        if durability <= normalized_threshold then
            abnormal_key = globals.math.max(abnormal_key, check_data.key)
            local format = globals.string.format
            local description = check_data.abnormalDesc
            local slot_name = globals.Module.Inventory.Config.SlotNameMapping[slot_type]
            local location = format(description, slot_name,
                globals.MathUtil.GetRoundingNum(check_value * 100))
            return false, location
        end
        return true
    end

    local helmet_ok, helmet_location = check_durability_slot(globals.ESlotType.Helmet)
    local breastplate_ok, breastplate_location = check_durability_slot(globals.ESlotType.BreastPlate)
    local abnormal_types, locations = {}, {}
    if not helmet_ok then
        globals.table.insert(abnormal_types, globals.ESlotType.Helmet)
        globals.table.insert(locations, globals.tostring(helmet_location))
    end
    if not breastplate_ok then
        globals.table.insert(abnormal_types, globals.ESlotType.BreastPlate)
        globals.table.insert(locations, globals.tostring(breastplate_location))
    end

    local location
    if not helmet_ok or not breastplate_ok then
        location = globals.table.concat(locations, globals.CommonConfig.Loc.Comma)
    end
    if location then
        local field = globals.Module.ArmedForce.Field
        local add_abnormal = field.AddEquipAbnormal
        local abnormal = {}
        abnormal.key = abnormal_key
        abnormal.abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.InsufficientDurability
        abnormal.loc = location
        local param = {}
        param.abnormalTypeList = abnormal_types
        abnormal.param = param
        add_abnormal(field, abnormal)
    end
end

-- P0.9 public argument is the slot type. It returns `(true)` when empty and
-- `(false, item)` when occupied, after resolving the current slot group.
function M.CheckEquipSlotEmpty(module, globals, slot_type)
    globals = globals_or_default(globals)
    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()
    local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
    local item = slot:GetEquipItem()
    if not item then return true end
    return false, item
end

-- P0.10 computes the selected slot's dynamic guide price. `price_logger` is
-- the captured U1 value from the payload closure; the descriptive label does
-- not claim to recover its stripped debug name. Both formatted calls remain
-- the final logger argument so open returns from string.format are forwarded.
function M.CheckEquipSlotValue(module, globals, slot_type, dependencies)
    globals = globals_or_default(globals)
    dependencies = assert(dependencies, "P0.10 captured dependencies required")
    local price_logger = assert(dependencies.price_logger,
        "P0.10 captured price logger missing")

    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()
    local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
    local item = slot:GetEquipItem()
    if not item then
        price_logger(globals.string.format(
            "CheckEquipLogic.GetAllEquipmentValue Equip ==> slot = %s, equipName = nil, price = 0",
            slot_type))
        return 0
    end

    local price = globals.Server.ShopServer:GetShopSingleDynamicGuidePriceByItem(
        item, nil, false)
    price_logger(globals.string.format(
        "CheckEquipLogic.GetAllEquipmentValue Equip ==> slot = %s, equipName = %s, price = %s",
        slot_type, item.name, price))
    return price or 0
end

-- P0.11: preserve the one explicit boolean-like gate, the open return list
-- from GetCurrentGameFlow forwarded to CheckMainFlowSOL, the false-flow Lobby
-- comparison, and the plain zero-argument call through the captured R3 table.
function M.DynamicGuidPriceFinishFetch(product, globals, should_finish_fetch)
    globals = globals_or_default(globals)
    local manager = globals.Facade.GameFlowManager

    local check_main, check_self = manager.CheckMainFlowSOL, manager
    local get_flow, flow_self = manager.GetCurrentGameFlow, manager
    local check_result = check_main(check_self, get_flow(flow_self))

    local flow_allows_finish = check_result
    if not check_result then
        local current_flow = manager.GetCurrentGameFlow(manager)
        flow_allows_finish = current_flow == globals.EGameFlowStageType.Lobby
    end

    if flow_allows_finish and should_finish_fetch then
        local check_equipment_value = product._CheckEquipmentValue
        check_equipment_value()
    end
end

-- P0.12 and nested P0.12.0. R2 error_logger, R1 info_logger, root globals
-- and source R3 product table are explicit source dependencies. The nested
-- match helper is resolved dynamically from R3 per occupied slot. No payload
-- closure is inspected or called by this implementation.
function M.CheckRaidBulletEnough(product, globals, dependencies, match_mode_id)
    dependencies = assert(dependencies, "P0.12 source dependencies required")
    globals = globals or dependencies.globals or _G
    local error_logger = assert(dependencies.error_logger, "P0.12 R2 error logger missing")
    local info_logger = assert(dependencies.info_logger, "P0.12 R1 info logger missing")

    if not match_mode_id then
        error_logger("CheckEquipLogic.CheckRaidBulletEnough matchModeID is nil")
        return
    end

    local slots = {
        globals.ESlotType.MainWeaponLeft,
        globals.ESlotType.MainWeaponRight,
        globals.ESlotType.Pistrol,
    }
    local enough = false
    local abnormal_data = {}
    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()

    local function check_slot(slot_type)
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        local weapon_item = slot:GetEquipItem()
        if weapon_item then
            local weapon_prefix_id = globals.tonumber(globals.string.sub(
                globals.tostring(weapon_item.id), 1, 4))
            local field = globals.Module.ArmedForce.Field
            local configured_ammo = field:GetRaidBulletCheckNum(match_mode_id, weapon_prefix_id)
            local get_match_bullet_num = product.GetMatchBulletNumByWeaponItem
            local matched_bullets = get_match_bullet_num(weapon_item, slot_group_id)
            if 0 < configured_ammo then
                if configured_ammo < matched_bullets then
                    enough = true
                    info_logger(globals.string.format(
                        "CheckEquipLogic.CheckRaidBulletEnough raid子弹检查结果 matchModeID = %s, weaponPrefixID = %s, 槽位 = %s, 子弹足够 携带num = %s",
                        match_mode_id, weapon_prefix_id, slot_type, matched_bullets))
                else
                    local abnormal = {
                        id = weapon_item.id,
                        checkBulletNum = configured_ammo,
                        needNum = configured_ammo - matched_bullets,
                    }
                    abnormal_data[slot_type] = abnormal
                    info_logger(globals.string.format(
                        "CheckEquipLogic.CheckRaidBulletEnough raid子弹检查结果 matchModeID = %s, weaponPrefixID = %s, 槽位 = %s, id = %s, checkBulletNum = %s, needNum = %s",
                        match_mode_id, weapon_prefix_id, slot_type, weapon_item.id,
                        configured_ammo, configured_ammo - matched_bullets))
                end
            else
                error_logger("CheckEquipLogic.CheckRaidBulletEnough Not configured ",
                    match_mode_id, weapon_prefix_id)
            end
        else
            info_logger(globals.string.format(
                "CheckEquipLogic.CheckRaidBulletEnough raid子弹检查结果 matchModeID = %s, weaponPrefixID = %s, 槽位 = %s, 没带武器",
                match_mode_id, globals.weaponPrefixID, slot_type))
        end
    end

    for _, slot_type in globals.ipairs(slots) do
        check_slot(slot_type)
    end

    info_logger(globals.string.format(
        "CheckEquipLogic.CheckRaidBulletEnough raid子弹检查结果 ==> bEnough = %s", enough))
    return enough, abnormal_data
end

return M

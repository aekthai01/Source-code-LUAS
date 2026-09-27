local S = ...
assert(type(S) == "table", "spectra module table required")
local M = {}
S.ProductModule = M

-- P0.0..P0.3 are reconstructed descriptions of stripped closures. Exported
-- field names below are exact strings recovered from root P0 bytecode.
M.PROTOTYPES = {
    CheckEquipmentBeforEnterGameProcess = "0.0",
    _CheckProcess = "0.1",
    _CheckEquipmentValue = "0.2",
    GetAllEquipmentValue = "0.3",
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

return M

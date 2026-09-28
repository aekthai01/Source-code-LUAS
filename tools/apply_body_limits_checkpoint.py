#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    assert count == 1, f"{path}: expected one match, got {count}: {old[:120]!r}"
    p.write_text(text.replace(old, new), encoding="utf-8")


def insert_before(path, marker, addition):
    replace_once(path, marker, addition + marker)


replace_once(
    "src/spectra/product_module.lua",
    "-- P0.0..P0.18 are reconstructed descriptions of stripped closures. Exported\n",
    "-- P0.0..P0.23 are reconstructed descriptions of stripped closures. Exported\n",
)
replace_once(
    "src/spectra/product_module.lua",
    '    _CheckPropExpiredStatus = "0.18",\n}',
    '    _CheckPropExpiredStatus = "0.18",\n'
    '    CheckPlayerBodyItemsByList = "0.19",\n'
    '    CheckNightVisionLimitByList = "0.20",\n'
    '    CheckThermalImagingLimitByList = "0.21",\n'
    '    CheckPlayerBodyItemsEntryQuality = "0.22",\n'
    '    CheckRentalConsumableID = "0.23",\n'
    '}',
)

body_impl = r'''

-- P0.19 and nested P0.19.0. The parent captures root R2/R4/R6 plus the
-- source R3 product table. Receiver expansion deliberately consumes only the
-- first result from GetRawPropInfo and calls the assembly helper as a static
-- function with (raw_prop, false, false, true).
function M.CheckPlayerBodyItemsByList(product, globals, dependencies, check_list)
    globals = globals_or_default(globals)
    dependencies = assert(dependencies, "P0.19 source dependencies required")
    local error_logger = assert(dependencies.error_logger, "P0.19 R2 error logger missing")
    local item_helper = assert(dependencies.item_helper, "P0.19 R4 ItemHelperTool missing")
    local weapon_assembly_tool = assert(dependencies.weapon_assembly_tool,
        "P0.19 R6 WeaponAssemblyTool missing")

    if not check_list then
        error_logger("CheckEquipLogic.CheckNightVisionLimitByList checkList is nil!!!")
        return false, {}
    end

    local result_keys
    local matched = {}
    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()

    local function collect_item(item)
        local item_id = item.id
        local main_type = item_helper.GetMainTypeById(item_id)
        if main_type == globals.EItemType.Receiver then
            local raw_prop = item:GetRawPropInfo()
            if not raw_prop then return end
            local ids = weapon_assembly_tool.GetItemIDsByPropInfo(
                raw_prop, false, false, true)
            if globals.table.isempty(ids) then return end
            for _, candidate_id in globals.ipairs(ids) do
                if globals.table.isInList(candidate_id, check_list)
                    and not matched[candidate_id] then
                    matched[candidate_id] = true
                end
            end
        else
            if globals.table.isInList(item_id, check_list) and not matched[item_id] then
                matched[item_id] = true
            end
        end
    end

    for _, slot_type in globals.ipairs(product.EquipTypeList) do
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        if slot then
            local item = slot:GetEquipItem()
            if item then collect_item(item) end
        end
    end

    for _, slot_type in globals.ipairs(product.ContainerTypeList) do
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        if slot then
            local items = slot:GetItems()
            if items and not globals.table.isempty(items) then
                for _, item in globals.ipairs(items) do
                    if item then collect_item(item) end
                end
            end
        end
    end

    result_keys = globals.table.keys(matched)
    return not globals.table.isempty(result_keys), result_keys
end

-- P0.20 is a distinct exported prototype whose whole body is a dynamic R3
-- field lookup followed by a tailcall. Returning the call directly preserves
-- every result from a runtime replacement of CheckPlayerBodyItemsByList.
function M.CheckNightVisionLimitByList(product, globals, check_list)
    return product.CheckPlayerBodyItemsByList(check_list)
end

-- P0.21 has the same tailcall shape as P0.20 but remains a separate public
-- prototype/export.
function M.CheckThermalImagingLimitByList(product, globals, check_list)
    return product.CheckPlayerBodyItemsByList(check_list)
end

-- P0.22 and nested P0.22.0/P0.22.1/P0.22.2. setdefault is called exactly so
-- an explicit false remains false. The selected comparator stays strict and
-- the -1 sentinel is handled before comparator invocation.
function M.CheckPlayerBodyItemsEntryQuality(product, globals, dependencies, limit_max)
    globals = globals_or_default(globals)
    dependencies = assert(dependencies, "P0.22 source dependencies required")
    local item_helper = assert(dependencies.item_helper, "P0.22 R4 ItemHelperTool missing")
    local item_config_tool = assert(dependencies.item_config_tool, "P0.22 R5 ItemConfigTool missing")
    local weapon_assembly_tool = assert(dependencies.weapon_assembly_tool,
        "P0.22 R6 WeaponAssemblyTool missing")
    local error_logger = assert(dependencies.error_logger, "P0.22 R2 error logger missing")

    limit_max = globals.setdefault(limit_max, true)
    local result = {
        [globals.ESlotType.Helmet] = -1,
        [globals.ESlotType.BreastPlate] = -1,
        [globals.ESlotType.BulletLeft] = -1,
    }
    local slot_group_id = globals.Server.ArmedForceServer:GetCurSlotGroupId()

    local comparator
    if limit_max then
        comparator = function(new_quality, current_quality)
            return current_quality < new_quality
        end
    else
        comparator = function(new_quality, current_quality)
            return new_quality < current_quality
        end
    end

    local function update_quality(slot_type, new_quality)
        local current_quality = result[slot_type]
        if current_quality == -1 or comparator(new_quality, current_quality) then
            result[slot_type] = new_quality
        end
    end

    local function collect_quality(item)
        local item_id = item.id
        local main_type = item_helper.GetMainTypeById(item_id)
        local sub_type = item_helper.GetSubTypeById(item_id)
        local quality = item_config_tool.GetItemQuality(item_id)

        if main_type == globals.EItemType.Receiver then
            local raw_prop = item:GetRawPropInfo()
            local bullets = weapon_assembly_tool.GetWeaponBullets(raw_prop)
            if not bullets then return end
            if globals.table.isempty(bullets) then return end
            for _, bullet in globals.ipairs(bullets) do
                local bullet_id = bullet.id
                if item_helper.GetMainTypeById(bullet_id) == globals.EItemType.Bullet then
                    local bullet_quality = item_config_tool.GetItemQuality(bullet_id)
                    update_quality(globals.ESlotType.BulletLeft, bullet_quality)
                end
            end
        elseif main_type == globals.EItemType.Equipment then
            if sub_type == globals.EEquipmentType.Helmet then
                update_quality(globals.ESlotType.Helmet, quality)
            elseif sub_type == globals.EEquipmentType.BreastPlate then
                update_quality(globals.ESlotType.BreastPlate, quality)
            end
        elseif main_type == globals.EItemType.Bullet then
            update_quality(globals.ESlotType.BulletLeft, quality)
        end
    end

    for _, slot_type in globals.ipairs(product.EquipTypeList) do
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        if slot then
            local item = slot:GetEquipItem()
            if item then collect_quality(item) end
        end
    end

    for _, slot_type in globals.ipairs(product.ContainerTypeList) do
        local slot = globals.Server.InventoryServer:GetSlot(slot_type, slot_group_id)
        if slot then
            local items = slot:GetItems()
            if items and not globals.table.isempty(items) then
                for _, item in globals.ipairs(items) do
                    if item then collect_quality(item) end
                end
            end
        end
    end

    error_logger(globals.string.format(
        "CheckEquipLogic.CheckPlayerBodyItemsEntryQuality [bLimitMax = %s, 头盔品质 = %s, 护甲品质 = %s, 子弹品质 = %s]",
        limit_max,
        result[globals.ESlotType.Helmet],
        result[globals.ESlotType.BreastPlate],
        result[globals.ESlotType.BulletLeft]
    ))
    return result
end

-- P0.23 captures only root _ENV. Both ArmedForce calls use SELF semantics and
-- the emitted record keeps the bytecode's explicit empty param table.
function M.CheckRentalConsumableID(product, globals)
    globals = globals_or_default(globals)
    local field = globals.Module.ArmedForce.Field
    local check_data = field:GetEquipmentCheckData(
        globals.Module.ArmedForce.Config.EAbnormalType.RentalVoucherDoNotMeetEntryRequirements,
        0)
    if not check_data then return end
    if not check_data.switch then return end

    local consumable_id = globals.Server.ArmedForceServer:GetCurRentalPlan_ConsumableID()
    if not (0 < consumable_id) then return end
    if globals.Module.ArmedForce:CheckConsumableIDCanBeApply(consumable_id) then return end

    globals.Module.ArmedForce.Field:AddEquipAbnormal({
        key = check_data.key,
        abnormalType = globals.Module.ArmedForce.Config.EAbnormalType.RentalVoucherDoNotMeetEntryRequirements,
        loc = check_data.abnormalDesc,
        param = {},
    })
end
'''
insert_before("src/spectra/product_module.lua", "\nreturn M\n", body_impl)

replace_once(
    "src/spectra/product_constructor.lua",
    "-- Source-only constructor for the reconstructed P0.0..P0.18 boundary. The\n",
    "-- Source-only constructor for the reconstructed P0.0..P0.23 boundary. The\n",
)
replace_once(
    "src/spectra/product_constructor.lua",
    '    product._CheckPropExpiredStatus = bind(product, globals,\n'
    '        Product._CheckPropExpiredStatus, p18, "expired_prop")\n',
    '    product._CheckPropExpiredStatus = bind(product, globals,\n'
    '        Product._CheckPropExpiredStatus, p18, "expired_prop")\n'
    '    local p19 = {\n'
    '        error_logger = context.error_logger,\n'
    '        item_helper = context.item_helper,\n'
    '        weapon_assembly_tool = context.weapon_assembly_tool,\n'
    '    }\n'
    '    product.CheckPlayerBodyItemsByList = bind(product, globals,\n'
    '        Product.CheckPlayerBodyItemsByList, p19, "static_one_arg_deps")\n'
    '    product.CheckNightVisionLimitByList = bind(product, globals,\n'
    '        Product.CheckNightVisionLimitByList, nil, "one_arg")\n'
    '    product.CheckThermalImagingLimitByList = bind(product, globals,\n'
    '        Product.CheckThermalImagingLimitByList, nil, "one_arg")\n'
    '    local p22 = {\n'
    '        item_helper = context.item_helper,\n'
    '        item_config_tool = context.item_config_tool,\n'
    '        weapon_assembly_tool = context.weapon_assembly_tool,\n'
    '        error_logger = context.error_logger,\n'
    '    }\n'
    '    product.CheckPlayerBodyItemsEntryQuality = bind(product, globals,\n'
    '        Product.CheckPlayerBodyItemsEntryQuality, p22, "static_one_arg_deps")\n'
    '    product.CheckRentalConsumableID = bind(product, globals, Product.CheckRentalConsumableID)\n',
)

replace_once(
    "src/spectra/product_module_bridge.lua",
    '    "_CheckPropExpiredStatus",\n}',
    '    "_CheckPropExpiredStatus",\n'
    '    "CheckPlayerBodyItemsByList",\n'
    '    "CheckNightVisionLimitByList",\n'
    '    "CheckThermalImagingLimitByList",\n'
    '    "CheckPlayerBodyItemsEntryQuality",\n'
    '    "CheckRentalConsumableID",\n'
    '}',
)
replace_once(
    "src/spectra/product_module_bridge.lua",
    '        _CheckPropExpiredStatus = {\n'
    '            armed_force_expired_logic = context.armed_force_expired_logic,\n'
    '        },\n',
    '        _CheckPropExpiredStatus = {\n'
    '            armed_force_expired_logic = context.armed_force_expired_logic,\n'
    '        },\n'
    '        CheckPlayerBodyItemsByList = {\n'
    '            error_logger = context.error_logger,\n'
    '            item_helper = context.item_helper,\n'
    '            weapon_assembly_tool = context.weapon_assembly_tool,\n'
    '        },\n'
    '        CheckPlayerBodyItemsEntryQuality = {\n'
    '            item_helper = context.item_helper,\n'
    '            item_config_tool = context.item_config_tool,\n'
    '            weapon_assembly_tool = context.weapon_assembly_tool,\n'
    '            error_logger = context.error_logger,\n'
    '        },\n',
)
replace_once(
    "src/spectra/product_module_bridge.lua",
    '        elseif name == "_CheckPropExpiredStatus" then\n'
    '            result = table.pack(pcall(target, product, environment,\n'
    '                dependencies.armed_force_expired_logic))\n'
    '        else',
    '        elseif name == "_CheckPropExpiredStatus" then\n'
    '            result = table.pack(pcall(target, product, environment,\n'
    '                dependencies.armed_force_expired_logic))\n'
    '        elseif name == "CheckPlayerBodyItemsByList"\n'
    '            or name == "CheckPlayerBodyItemsEntryQuality" then\n'
    '            result = table.pack(pcall(target, product, environment, dependencies, arguments[1]))\n'
    '        elseif name == "CheckNightVisionLimitByList"\n'
    '            or name == "CheckThermalImagingLimitByList" then\n'
    '            result = table.pack(pcall(target, product, environment, arguments[1]))\n'
    '        elseif name == "CheckRentalConsumableID" then\n'
    '            result = table.pack(pcall(target, product, environment))\n'
    '        else',
)
replace_once(
    "src/spectra/product_module_bridge.lua",
    '        _CheckPropExpiredStatus = Source._CheckPropExpiredStatus,\n'
    '    }',
    '        _CheckPropExpiredStatus = Source._CheckPropExpiredStatus,\n'
    '        CheckPlayerBodyItemsByList = Source.CheckPlayerBodyItemsByList,\n'
    '        CheckNightVisionLimitByList = Source.CheckNightVisionLimitByList,\n'
    '        CheckThermalImagingLimitByList = Source.CheckThermalImagingLimitByList,\n'
    '        CheckPlayerBodyItemsEntryQuality = Source.CheckPlayerBodyItemsEntryQuality,\n'
    '        CheckRentalConsumableID = Source.CheckRentalConsumableID,\n'
    '    }',
)
replace_once(
    "src/spectra/product_module_bridge.lua",
    "-- Transitional installation still overlays the payload-created product\n",
    "-- Transitional installation still overlays the payload-created product\n",
)

# Ownership is still derived from one authoritative mapping.
replace_once(
    "tools/full_payload_forensics.py",
    "# P0.0..P0.18 no longer depend on payload closure captures. Migrated child\n",
    "# P0.0..P0.23 no longer depend on payload closure captures. Migrated child\n",
)
replace_once("tools/full_payload_forensics.py", "    for number in range(19):\n", "    for number in range(24):\n")
replace_once(
    "tools/full_payload_forensics.py",
    '    for path in ("0.6.0", "0.7.0", "0.8.0", "0.12.0", "0.13.0"):\n',
    '    for path in ("0.6.0", "0.7.0", "0.8.0", "0.12.0", "0.13.0",\n'
    '                 "0.19.0", "0.22.0", "0.22.1", "0.22.2"):\n',
)
replace_once(
    "tools/full_payload_forensics.py",
    '        "", "## P0.0..P0.18 source-only preparation", "",\n'
    '        "- All nineteen public methods P0.0..P0.18 receive source-owned captures and helpers; none use `debug.getupvalue`.",',
    '        "", "## P0.0..P0.23 source-only preparation", "",\n'
    '        "- All twenty-four public methods P0.0..P0.23 receive source-owned captures and helpers; none use `debug.getupvalue`.",',
)
replace_once(
    "tools/full_payload_forensics.py",
    '        "- P0.18 uses source R3 traversal lists plus root R9 ArmedForceExpiredLogic with a plain one-argument CheckExpired ABI and exact three-field ExpiredProp record.",\n'
    '        "- `ProductModule.create(context, globals)` creates/binds P0.0..P0.18 on the same source R3 product table and emits exact `EquipTypeList` / `ContainerTypeList` order.",\n'
    '        "- The transitional payload overlay remains restorable; P0.0..P0.18 neither inspect nor call payload closures and do not extract payload upvalues.",',
    '        "- P0.18 uses source R3 traversal lists plus root R9 ArmedForceExpiredLogic with a plain one-argument CheckExpired ABI and exact three-field ExpiredProp record.",\n'
    '        "- P0.19/P0.19.0 use source R3 traversal lists plus R2/R4/R6 captures, one-result receiver raw-prop semantics, static expansion ABI, matched-map dedupe and engine `table.keys` ordering.",\n'
    '        "- P0.20/P0.21 remain distinct exports and tail-forward every return through a dynamic source R3 `CheckPlayerBodyItemsByList` lookup.",\n'
    '        "- P0.22/P0.22.0/P0.22.1/P0.22.2 preserve setdefault(false,true), strict comparators, exact three-slot result state and static R4/R5/R6 helper ABIs.",\n'
    '        "- P0.23 preserves the RentalVoucherDoNotMeetEntryRequirements gate, ArmedForce SELF call and exact four-field abnormal record with an empty `param` table.",\n'
    '        "- `ProductModule.create(context, globals)` creates/binds P0.0..P0.23 on the same source R3 product table and emits exact `EquipTypeList` / `ContainerTypeList` order.",\n'
    '        "- The transitional payload overlay remains restorable; P0.0..P0.23 neither inspect nor call payload closures and do not extract payload upvalues.",',
)
replace_once(
    "tools/full_payload_forensics.py",
    "P0.0..P0.18 are source-owned with `source_only_dependency=true`; their root captures/helpers are recreated from source without loading the embedded payload. Remaining root methods P0.19..P0.28 stay payload-owned until their bounded reconstruction checkpoints complete.",
    "P0.0..P0.23 are source-owned with `source_only_dependency=true`; their root captures/helpers are recreated from source without loading the embedded payload. Remaining root methods P0.24..P0.28 stay payload-owned until their bounded reconstruction checkpoints complete.",
)

# Validator moves the source-only boundary and records this focused suite.
replace_once("tools/validate_phase_d.py", "    assert root_source_owned>=19\n", "    assert root_source_owned>=24\n")
replace_once(
    "tools/validate_phase_d.py",
    "    assert roots['CheckPlayerBodyItemsByList']['current_ownership']=='payload_owned'\n",
    "    assert captured('R2','P0.19','U0') and captured('R4','P0.19','U2') and captured('R6','P0.19','U3') and captured('R3','P0.19','U4')\n"
    "    assert captured('R3','P0.20','U0') and captured('R3','P0.21','U0')\n"
    "    assert captured('R4','P0.22','U1') and captured('R5','P0.22','U2') and captured('R6','P0.22','U3') and captured('R3','P0.22','U4') and captured('R2','P0.22','U5')\n"
    "    assert prototypes['0.19']['numparams']==1 and prototypes['0.19']['instruction_count']==87 and len(prototypes['0.19']['upvalues'])==5\n"
    "    assert prototypes['0.19.0']['numparams']==1 and prototypes['0.19.0']['instruction_count']==57 and len(prototypes['0.19.0']['upvalues'])==5\n"
    "    assert prototypes['0.20']['numparams']==1 and prototypes['0.20']['instruction_count']==8 and len(prototypes['0.20']['upvalues'])==1\n"
    "    assert prototypes['0.21']['numparams']==1 and prototypes['0.21']['instruction_count']==8 and len(prototypes['0.21']['upvalues'])==1\n"
    "    assert prototypes['0.22']['numparams']==1 and prototypes['0.22']['instruction_count']==103 and len(prototypes['0.22']['upvalues'])==6\n"
    "    assert prototypes['0.22.0']['numparams']==2 and prototypes['0.22.0']['instruction_count']==9 and len(prototypes['0.22.0']['upvalues'])==0\n"
    "    assert prototypes['0.22.1']['numparams']==2 and prototypes['0.22.1']['instruction_count']==9 and len(prototypes['0.22.1']['upvalues'])==0\n"
    "    assert prototypes['0.22.2']['numparams']==1 and prototypes['0.22.2']['instruction_count']==131 and len(prototypes['0.22.2']['upvalues'])==6\n"
    "    assert prototypes['0.23']['numparams']==0 and prototypes['0.23']['instruction_count']==51 and len(prototypes['0.23']['upvalues'])==1\n"
    "    migrated={'0.19','0.19.0','0.20','0.21','0.22','0.22.0','0.22.1','0.22.2','0.23'}\n"
    "    assert migrated <= set(groups['source_owned'])\n"
    "    assert all(inv['source_files'][p]=='src/spectra/product_module.lua' for p in migrated)\n"
    "    for name in ('CheckPlayerBodyItemsByList','CheckNightVisionLimitByList','CheckThermalImagingLimitByList','CheckPlayerBodyItemsEntryQuality','CheckRentalConsumableID'):\n"
    "        assert roots[name]['source_only_dependency'] is True\n"
    "    assert roots['_CheckPropinfoDownloadWithLog']['current_ownership']=='payload_owned'\n",
)
replace_once(
    "tools/validate_phase_d.py",
    "      'product_module.lua':'product-module: ok','product_night.lua':'product-night: ok','product_expiration.lua':'product-expiration: ok','product_source_only.lua':'product-source-only: ok','product_module_bridge.lua':'product-module-bridge: ok',\n",
    "      'product_module.lua':'product-module: ok','product_night.lua':'product-night: ok','product_expiration.lua':'product-expiration: ok','product_body_limits.lua':'product-body-limits: ok','product_source_only.lua':'product-source-only: ok','product_module_bridge.lua':'product-module-bridge: ok',\n",
)
replace_once("tools/validate_phase_d.py", "      'phase':'E5.5-root-expiration-source-only',\n", "      'phase':'E5.6-root-body-limits-source-only',\n")
replace_once(
    "tools/validate_phase_d.py",
    "'p0_0_through_p0_18':True",
    "'p0_0_through_p0_23':True",
)

# Existing integration suites must follow the same public boundary.
replace_once(
    "tests/product_source_only.lua",
    '    "_CheckSafeBoxExpiredStatus","_CheckKeyChainExpiredStatus","_CheckPropExpiredStatus",\n}',
    '    "_CheckSafeBoxExpiredStatus","_CheckKeyChainExpiredStatus","_CheckPropExpiredStatus",\n'
    '    "CheckPlayerBodyItemsByList","CheckNightVisionLimitByList",\n'
    '    "CheckThermalImagingLimitByList","CheckPlayerBodyItemsEntryQuality",\n'
    '    "CheckRentalConsumableID",\n'
    '}',
)
replace_once(
    "tests/product_module_bridge.lua",
    "-- All P0.0..P0.18 public methods install from one source context. No payload\n",
    "-- All P0.0..P0.23 public methods install from one source context. No payload\n",
)
replace_once(
    "tests/product_module_bridge.lua",
    '    eq(status.source_owned_root_methods,19,"P0.0..P0.18 public methods source-owned")',
    '    eq(status.source_owned_root_methods,24,"P0.0..P0.23 public methods source-owned")',
)
replace_once(
    "tests/product_expiration.lua",
    '    eq(Bridge.status().source_owned_root_methods,19,"bridge owns P0.0..P0.18")',
    '    eq(Bridge.status().source_owned_root_methods,24,"bridge owns P0.0..P0.23")',
)

print("body-limits checkpoint patch applied")

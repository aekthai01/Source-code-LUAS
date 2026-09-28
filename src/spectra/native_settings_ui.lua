local S = ...
assert(type(S) == "table", "spectra module table required")

-- Phase-D reconstruction of payload prototype P0.29.105.
-- Original debug/local names were stripped. Public/global names and engine API names below
-- come from constants/call-sites in the verified baseline payload; helper names are reconstructed.

local M = {}
S.NativeSettingsUI = M

M.PROTOTYPE = "0.29.105"
M.PAGE_TITLE = "@DrkZeref" -- intentional user-requested divergence from the embedded payload.
M.TITLE_CLASS_PATH = "/Game/BluePrints/UI/UMG/Common/Library/WBP_TitleWithLine.WBP_TitleWithLine_C"
M.REQUIRED_HOOK_COUNT = 9
M.HOOK_METHODS = {
    "_InitDynamicBtns",
    "SetSelectedModePanel",
    "OnInitExtraData",
    "OnShowBegin",
    "OnActivate",
    "_FetchSettingSystemByTab",
    "_UpdateSysetemSettingPanel",
    "OnHideBegin",
    "OnClose",
}

M.UI_MODEL = {
    { section = "Combat", row = 1 },
    { kind = "toggle", row = 2, column = 0, title = "No Recoil", on = "Enable", off = "Disable", feature = "no_recoil" },
    { kind = "toggle", row = 2, column = 1, title = "Bullet Spread Control", on = "Enable", off = "Disable", feature = "converge" },
    { kind = "toggle", row = 3, column = 0, title = "Hip-Fire Aim", on = "Enable", off = "Disable", feature = "aim" },
    { kind = "toggle", row = 3, column = 1, title = "ADS Aim", on = "Enable", off = "Disable", feature = "anti_shake" },
    { section = "Visuals", row = 4 },
    { kind = "toggle", row = 5, column = 0, title = "Bot Highlight", on = "Enable", off = "Disable" },
    { kind = "choice2", row = 5, column = 1, title = "Bot Color", first = "Red", second = "Green" },
    { kind = "choice2", row = 6, column = 0, title = "Player Color", first = "Red", second = "Green" },
    { kind = "toggle", row = 6, column = 1, title = "Player X-Ray", on = "Enable", off = "Disable" },
    { section = "Aim Settings", row = 7 },
    { kind = "choice4", row = 8, column = 0, span = 2, title = "Target Bone", choices = { "Head", "Chest", "Legs", "Point & Shoot" } },
    { kind = "slider", row = 9, column = 0, span = 2, title = "Aim Speed", min = 1, max = 100, default = 50, global_key = "custom_aim_speed" },
    { kind = "slider", row = 10, column = 0, span = 2, title = "Aim FOV", min = 1, max = 360, default = 90, global_key = "custom_aim_range" },
    { kind = "slider", row = 11, column = 0, span = 2, title = "Aim Distance", min = 1, max = 500, default = 150, global_key = "custom_aim_distance" },
    { kind = "slider", row = 12, column = 0, span = 2, title = "Aim Lock Delay", min = 1, max = 100, default = 1, global_key = "custom_aim_lock_time" },
}

local function safe_get(obj, key)
    if obj == nil then return nil end
    local ok, value = pcall(function() return obj[key] end)
    if ok then return value end
    return nil
end

local function unwrap(obj)
    if obj == nil then return nil end
    if type(obj) == "table" then
        return rawget(obj, "__cppinst") or rawget(obj, "_cppIns") or rawget(obj, "_cppinst") or obj
    end
    return obj
end

local function from_weak(value)
    local fn = rawget(_G, "getfromweak")
    if type(fn) == "function" then
        local ok, result = pcall(fn, value)
        if ok and result ~= nil then return result end
    end
    return value
end

local function pack(...)
    return { n = select("#", ...), ... }
end

local unpack_values = table.unpack or unpack

local function delayed(seconds, fn)
    local timer = rawget(_G, "Timer")
    local delay = safe_get(timer, "DelayCall")
    if type(delay) ~= "function" then
        fn()
        return
    end
    local ok = pcall(delay, seconds, fn)
    if not ok then pcall(delay, timer, seconds, fn) end
end

local function import_symbol(name)
    local existing = rawget(_G, name)
    if existing ~= nil then return existing end
    local import = rawget(_G, "import")
    if type(import) ~= "function" then return nil end
    local ok, value = pcall(import, name)
    if ok then return value end
    return nil
end

local function require_table(name)
    local req = rawget(_G, "require") or require
    if type(req) ~= "function" then return nil end
    local ok, value = pcall(req, name)
    if ok and type(value) == "table" then return value end
    return nil
end

local function facade_manager(name)
    local facade = rawget(_G, "Facade")
    local value = safe_get(facade, name)
    if value ~= nil then return value end
    return rawget(_G, name)
end

local function localize(text, key)
    local fn = rawget(_G, "NewLuaLocText")
    if type(fn) == "function" then
        local ok, value = pcall(fn, text, "DongDongNativeSetting", key)
        if ok and value ~= nil then return value end
    end
    return text
end

local function make_margin(import_fn, left, top, right, bottom)
    local ctor = rawget(_G, "FMargin")
    if type(ctor) == "function" then
        local ok, margin = pcall(ctor, left, top, right, bottom)
        if ok and margin ~= nil then return margin end
    end
    if type(import_fn) == "function" then
        local ok_class, margin_class = pcall(import_fn, "Margin")
        if ok_class and margin_class ~= nil then
            local ok_obj, margin = pcall(margin_class)
            if ok_obj and margin ~= nil then
                margin.Left, margin.Top, margin.Right, margin.Bottom = left, top, right, bottom
                return margin
            end
        end
    end
    return nil
end

local function slot_as_grid(ui_util, widget)
    if widget == nil then return nil end
    local unwrapped = unwrap(widget)
    local fn = safe_get(ui_util, "SlotAsGridSlot")
    if type(fn) == "function" then
        local ok, slot = pcall(fn, unwrapped)
        if ok and slot ~= nil then return slot end
        ok, slot = pcall(fn, widget)
        if ok then return slot end
    end
    return safe_get(widget, "Slot")
end

local function configure_grid_slot(slot, row, column, span, padding)
    if slot == nil then return end
    pcall(function() slot:SetRow(row) end)
    pcall(function() slot:SetColumn(column) end)
    pcall(function() slot:SetColumnSpan(span or 1) end)
    local eh = rawget(_G, "EHorizontalAlignment")
    local ev = rawget(_G, "EVerticalAlignment")
    if eh then pcall(function() slot:SetHorizontalAlignment(eh.HAlign_Fill) end) end
    if ev then pcall(function() slot:SetVerticalAlignment(ev.VAlign_Fill) end) end
    if padding ~= nil then pcall(function() slot:SetPadding(padding) end) end
end

local function add_grid_child(grid, widget, row, column, span, padding, ui_util)
    local raw_widget = unwrap(widget)
    local ok, slot = pcall(function() return grid:AddChildToGrid(raw_widget, row, column) end)
    if not ok or slot == nil then slot = slot_as_grid(ui_util, raw_widget) end
    configure_grid_slot(slot, row, column, span, padding)
    return slot
end

local function normalize_color(value)
    value = string.lower(tostring(value or "")):gsub("[^%w]", "")
    if value == "none" or value == "off" or value == "disabled" then return "none" end
    if value == "green" then return "green" end
    return "red"
end

local function call_global(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return false, nil end
    local ok, result = pcall(fn, ...)
    return ok, result
end

local function ensure_toggle_state()
    local state = rawget(_G, "custom_dongdong_toggle_state")
    if type(state) ~= "table" then
        state = {}
        rawset(_G, "custom_dongdong_toggle_state", state)
    end
    for _, key in ipairs({ "no_recoil", "converge", "aim", "anti_shake" }) do
        if state[key] == nil then state[key] = false end
    end
    return state
end

local function set_feature_local(name, enabled, view, current_grid)
    local toggles = ensure_toggle_state()
    enabled = enabled == true
    if enabled and name == "aim" then
        toggles.aim, toggles.anti_shake = true, false
    elseif enabled and name == "anti_shake" then
        toggles.anti_shake, toggles.aim = true, false
    else
        toggles[name] = enabled
    end
    call_global("set_dongdong_feature_config", name, enabled)
    if name == "aim" or name == "anti_shake" then
        delayed(0.03, function()
            if safe_get(view, "_dongdong_native_grid") == current_grid then M.build_page(view) end
        end)
    end
end

local function reapply_aim_after_slider_change()
    local revision = (tonumber(rawget(_G, "custom_dongdong_aim_slider_revision")) or 0) + 1
    rawset(_G, "custom_dongdong_aim_slider_revision", revision)
    delayed(0.18, function()
        if rawget(_G, "custom_dongdong_aim_slider_revision") ~= revision then return end
        local toggles = ensure_toggle_state()
        if toggles.aim == true then
            call_global("set_dongdong_feature_config", "aim", true)
        elseif toggles.anti_shake == true then
            call_global("set_dongdong_feature_config", "anti_shake", true)
        end
        call_global("set_dongdong_aim_part")
    end)
end

local function set_aim_part(value)
    rawset(_G, "custom_aim_target_part", value)
    if not call_global("set_dongdong_aim_part") then
        -- The payload normally exports this function. No invented engine API fallback.
    end
end

local function set_slider(global_key, value)
    rawset(_G, global_key, value)
    reapply_aim_after_slider_change()
end

local function add_sub_ui(deps, view, grid, ui_id)
    local ok, weak = pcall(function() return deps.ui_manager:AddSubUI(view, ui_id, grid) end)
    if not ok then return nil end
    return unwrap(from_weak(weak))
end

local function add_two_button(deps, view, grid, row, column, title, a, b, first_selected, cb_a, cb_b)
    local widget = add_sub_ui(deps, view, grid, deps.setting_btn_two_id)
    if widget == nil then return nil end
    pcall(function() widget:InitBtnDynamic(title, a, b, first_selected == true) end)
    pcall(function() widget:SetBtnClickByIndex(1, cb_a) end)
    pcall(function() widget:SetBtnClickByIndex(2, cb_b) end)
    local slot = safe_get(widget, "Slot") or slot_as_grid(deps.ui_util, widget)
    local left = column == 0 and 0 or 16
    local right = column == 0 and 16 or 0
    configure_grid_slot(slot, row, column, 1, make_margin(deps.import_fn, left, 13, right, 13))
    table.insert(view._dongdong_native_buttons, widget)
    return widget
end

local function make_full_width(deps, widget, row, top, bottom)
    local slot = safe_get(widget, "Slot") or slot_as_grid(deps.ui_util, widget)
    configure_grid_slot(slot, row, 0, 2, make_margin(deps.import_fn, 0, top or 13, 0, bottom or 13))
    return slot
end

local function add_four_button(deps, view, grid, row, title, selected, callbacks)
    local widget = add_sub_ui(deps, view, grid, deps.setting_btn_four_id)
    if widget == nil then return nil end
    local title_widget = safe_get(widget, "_wtTitle")
    if title_widget ~= nil then pcall(function() title_widget:SetText(title) end) end
    for i, text in ipairs({ "Head", "Chest", "Legs", "Point & Shoot" }) do
        pcall(function() widget:SetBtnTxt(i, text) end)
        pcall(function() widget:SetBtnClickByIndex(i, callbacks[i]) end)
    end
    local enum_index = math.max(0, math.min(3, (selected or 1) - 1))
    pcall(function() widget:InitSettingBtnByEume(enum_index) end)
    make_full_width(deps, widget, row, 13, 13)
    table.insert(view._dongdong_native_buttons, widget)
    return widget
end

local function add_slider(deps, view, grid, row, title, min_value, max_value, current, step, on_change)
    local widget = add_sub_ui(deps, view, grid, deps.setting_slider_id)
    if widget == nil then return nil end
    pcall(function() widget.BpTitle = title end)
    local last = math.max(min_value, math.min(max_value, math.floor((tonumber(current) or min_value) + 0.5)))
    local function changed(value)
        local next_value = math.max(min_value, math.min(max_value, math.floor((tonumber(value) or last) + 0.5)))
        if next_value == last then return end
        last = next_value
        pcall(function() widget._wtTxtValue:SetText(title .. "：" .. tostring(last)) end)
        on_change(last)
    end
    pcall(function() widget:InitSettingSlider(min_value, max_value, current, changed, changed, false, step or 1) end)
    pcall(function()
        widget._name = title
        widget._wtTxtValue:SetText(title .. "：" .. tostring(last))
    end)
    make_full_width(deps, widget, row, 13, 13)
    table.insert(view._dongdong_native_buttons, widget)
    return widget
end

local function configure_title_widget(widget, text, loc_key, font_style)
    if widget == nil then return false end
    local localized = localize(text, loc_key)
    pcall(function() widget.WBP_TitleWithLine_Name = localized end)
    pcall(function() widget["Set text"](widget, localized) end)
    local text_block = safe_get(widget, "wtDFTextBlockTitle")
    if text_block == nil then
        pcall(function() text_block = widget:GetWidgetFromName("wtDFTextBlockTitle") end)
    end
    if text_block ~= nil then
        pcall(function() text_block:SetText(localized) end)
        pcall(function() text_block:SetFontStyleID(font_style or "Header3_28pt") end)
    end
    pcall(function() widget:SynchronizeProperties() end)
    return true
end

local function hide_title_line(widget)
    if widget == nil then return end
    local line
    pcall(function() line = widget:GetWidgetFromName("Line_113") end)
    local vis = rawget(_G, "ESlateVisibility")
    if line ~= nil and vis ~= nil then pcall(function() line:SetVisibility(vis.Collapsed) end) end
end

local function finish_title_load(state, class)
    local waiters = state.title_waiters or {}
    state.title_waiters = {}
    state.title_loading = false
    if class ~= nil then state.title_class = class end
    for _, waiter in ipairs(waiters) do pcall(waiter, class) end
end

local function request_title_class(deps, state, callback)
    if type(callback) ~= "function" then return end
    if state.title_class ~= nil then callback(state.title_class); return end
    state.title_waiters = state.title_waiters or {}
    table.insert(state.title_waiters, callback)
    if state.title_loading == true then return end
    state.title_loading = true

    local resource_manager = facade_manager("ResourceManager")
    local async = safe_get(resource_manager, "AsyncLoadResource")
    if type(async) ~= "function" then finish_title_load(state, nil); return end
    local function loaded(result)
        local class
        if type(result) == "table" then class = result[M.TITLE_CLASS_PATH] end
        finish_title_load(state, class)
    end
    local ok = pcall(async, resource_manager, nil, M.TITLE_CLASS_PATH, loaded, nil)
    if not ok then ok = pcall(async, nil, M.TITLE_CLASS_PATH, loaded, nil) end
    if not ok then finish_title_load(state, nil) end
end

local function create_title_widget(deps, context, class, text, key, hide_line, font_style)
    if context == nil or class == nil then return nil end
    local creator = safe_get(deps.widget_blueprint_library, "Create")
    if type(creator) ~= "function" then return nil end
    local ok, widget = pcall(creator, unwrap(context), class, nil)
    if not ok or widget == nil then return nil end
    configure_title_widget(widget, text, key, font_style)
    if hide_line == true then hide_title_line(widget) end
    return widget
end

local function add_headers_async(deps, state, view, grid, build_token)
    request_title_class(deps, state, function(class)
        if class == nil then return end
        if safe_get(view, "_dongdong_native_grid") ~= grid then return end
        if safe_get(view, "_dongdong_native_build_token") ~= build_token then return end
        local specs = {
            { row = 0, text = M.PAGE_TITLE, key = "PageTitle", hide = true, font = "Header4_32pt", padding = {24,10,0,28} },
            { row = 1, text = "Combat", key = "FunctionSection", hide = false, font = "Header3_28pt", padding = {24,0,0,14} },
            { row = 4, text = "Visuals", key = "ColorSection", hide = false, font = "Header3_28pt", padding = {24,28,0,14} },
            { row = 7, text = "Aim Settings", key = "AdjustSection", hide = false, font = "Header3_28pt", padding = {24,28,0,14} },
        }
        for _, spec in ipairs(specs) do
            local widget = create_title_widget(deps, view, class, spec.text, spec.key, spec.hide, spec.font)
            if widget ~= nil then
                table.insert(view._dongdong_native_widgets, widget)
                local p = spec.padding
                add_grid_child(grid, widget, spec.row, 0, 2, make_margin(deps.import_fn, p[1], p[2], p[3], p[4]), deps.ui_util)
            end
        end
        pcall(function() grid:InvalidateLayoutAndVolatility() end)
    end)
end

local function resolve_dependencies()
    local ids = rawget(_G, "UIName2ID")
    local ui_table = rawget(_G, "UITable")
    local ui_manager = facade_manager("UIManager")
    local req = rawget(_G, "require") or require
    local import_fn = rawget(_G, "import")
    if type(ids) ~= "table" or ui_table == nil or ui_manager == nil or type(req) ~= "function" or type(import_fn) ~= "function" then return nil end

    local view_id = rawget(ids, "SystemSettingMainView")
    local btn2_id = rawget(ids, "SettingBtnTwo")
    local btn4_id = rawget(ids, "SettingBtnFour")
    local slider_id = rawget(ids, "SettingSlider")
    if view_id == nil or btn2_id == nil or btn4_id == nil or slider_id == nil then return nil end

    local view_class = require_table("DFM.Business.Module.SystemSettingModule.UI.SystemSettingMainView")
    local ui_util = require_table("DFM.YxFramework.Managers.UI.Util.UIUtil")
    local grid_panel = import_symbol("GridPanel")
    local scroll_box = import_symbol("ScrollBox")
    local wbl = import_symbol("WidgetBlueprintLibrary")
    local wll = import_symbol("WidgetLayoutLibrary")
    if type(view_class) ~= "table" or type(ui_util) ~= "table" or grid_panel == nil or scroll_box == nil or wbl == nil or wll == nil then return nil end

    ui_table.SubUIs = type(ui_table.SubUIs) == "table" and ui_table.SubUIs or {}
    local function add_unique(value)
        for _, existing in ipairs(ui_table.SubUIs) do if existing == value then return end end
        table.insert(ui_table.SubUIs, value)
    end
    add_unique(btn2_id); add_unique(btn4_id); add_unique(slider_id)

    return {
        ids = ids,
        ui_table = ui_table,
        ui_manager = ui_manager,
        view_class = view_class,
        view_id = view_id,
        row_id = btn2_id, -- exact P0.29.105 behavior: custom nav row id reuses SettingBtnTwo.
        setting_btn_two_id = btn2_id,
        setting_btn_four_id = btn4_id,
        setting_slider_id = slider_id,
        ui_util = ui_util,
        grid_panel = grid_panel,
        scroll_box = scroll_box,
        widget_blueprint_library = wbl,
        widget_layout_library = wll,
        import_fn = import_fn,
    }
end

local function remove_sub_ui_by_parent(deps, view, child)
    if child == nil then return end
    pcall(function() deps.ui_manager:RemoveSubUIByParent(view, child) end)
end

function M.cleanup(view, deps)
    if view == nil then return end
    deps = deps or M._deps or resolve_dependencies()
    local grid = safe_get(view, "_dongdong_native_grid")
    local scroll = safe_get(view, "_dongdong_native_scroll")
    if grid ~= nil then
        if deps ~= nil then remove_sub_ui_by_parent(deps, view, grid) end
        pcall(function() grid:RemoveFromParent() end)
    end
    if scroll ~= nil then pcall(function() scroll:RemoveFromParent() end) end
    view._dongdong_native_scroll = nil
    view._dongdong_native_grid = nil
    view._dongdong_native_buttons = nil
    view._dongdong_native_widgets = nil
    view._dongdong_native_build_token = nil
end

function M.build_page(view)
    if view == nil then return false end
    local deps = M._deps or resolve_dependencies()
    if deps == nil then return false end
    M._deps = deps
    M.cleanup(view, deps)

    local root = unwrap(from_weak(safe_get(view, "_wtRootMain")))
    if root == nil then return false end

    local ok_scroll, scroll = pcall(deps.scroll_box)
    local ok_grid, grid = pcall(deps.grid_panel)
    if not ok_scroll or scroll == nil or not ok_grid or grid == nil then return false end

    pcall(function()
        local e = rawget(_G, "EConsumeMouseWheel")
        if e then scroll:SetConsumeMouseWheel(e.WhenScrollingPossible) end
    end)
    pcall(function()
        local e = rawget(_G, "ESlateVisibility")
        if e then scroll:SetScrollBarVisibility(e.Collapsed) end
    end)
    pcall(function() scroll:SetAnimateWheelScrolling(true) end)
    pcall(function() deps.ui_util.AddWidgetToParent_Full(scroll, root) end)
    pcall(function() grid:SetColumnFill(0, 1.0); grid:SetColumnFill(1, 1.0) end)

    local scroll_slot
    pcall(function() scroll_slot = scroll:AddChild(grid) end)
    if scroll_slot ~= nil then
        local eh = rawget(_G, "EHorizontalAlignment")
        local ev = rawget(_G, "EVerticalAlignment")
        if eh then pcall(function() scroll_slot:SetHorizontalAlignment(eh.HAlign_Fill) end) end
        if ev then pcall(function() scroll_slot:SetVerticalAlignment(ev.VAlign_Top) end) end
    end

    view._dongdong_native_scroll = scroll
    view._dongdong_native_grid = grid
    view._dongdong_native_buttons = {}
    view._dongdong_native_widgets = {}
    local build_token = {}
    view._dongdong_native_build_token = build_token

    local toggles = ensure_toggle_state()
    add_two_button(deps, view, grid, 2, 0, "No Recoil", "Enable", "Disable", toggles.no_recoil,
        function() set_feature_local("no_recoil", true, view, grid) end,
        function() set_feature_local("no_recoil", false, view, grid) end)
    add_two_button(deps, view, grid, 2, 1, "Bullet Spread Control", "Enable", "Disable", toggles.converge,
        function() set_feature_local("converge", true, view, grid) end,
        function() set_feature_local("converge", false, view, grid) end)
    add_two_button(deps, view, grid, 3, 0, "Hip-Fire Aim", "Enable", "Disable", toggles.aim,
        function() set_feature_local("aim", true, view, grid) end,
        function() set_feature_local("aim", false, view, grid) end)
    add_two_button(deps, view, grid, 3, 1, "ADS Aim", "Enable", "Disable", toggles.anti_shake,
        function() set_feature_local("anti_shake", true, view, grid) end,
        function() set_feature_local("anti_shake", false, view, grid) end)

    local ai_key = normalize_color(rawget(_G, "custom_ai_color_key"))
    local ai_enabled = ai_key ~= "none"
    local ai_display_key = ai_key
    if ai_display_key == "none" then ai_display_key = normalize_color(rawget(_G, "custom_ai_color_last_key") or "red") end
    local player_key = normalize_color(rawget(_G, "custom_real_color_key") or "green")

    add_two_button(deps, view, grid, 5, 0, "Bot Highlight", "Enable", "Disable", ai_enabled,
        function()
            local key = normalize_color(rawget(_G, "custom_ai_color_last_key") or ai_display_key or "red")
            call_global("set_ai_color", key)
        end,
        function() call_global("set_ai_color", "none") end)
    add_two_button(deps, view, grid, 5, 1, "Bot Color", "Red", "Green", ai_display_key == "red",
        function()
            rawset(_G, "custom_ai_color_last_key", "red")
            if normalize_color(rawget(_G, "custom_ai_color_key")) ~= "none" then call_global("set_ai_color", "red") end
        end,
        function()
            rawset(_G, "custom_ai_color_last_key", "green")
            if normalize_color(rawget(_G, "custom_ai_color_key")) ~= "none" then call_global("set_ai_color", "green") end
        end)
    add_two_button(deps, view, grid, 6, 0, "Player Color", "Red", "Green", player_key == "red",
        function() call_global("set_real_player_color", "red") end,
        function() call_global("set_real_player_color", "green") end)
    add_two_button(deps, view, grid, 6, 1, "Player X-Ray", "Enable", "Disable", rawget(_G, "custom_character_xray_enabled") == true,
        function() call_global("set_character_xray", true) end,
        function() call_global("set_character_xray", false) end)

    local part = rawget(_G, "custom_aim_target_part") or "head"
    if part == "miss" then part = "free" end
    rawset(_G, "custom_aim_target_part", part)
    local selected = ({ head = 1, chest = 2, leg = 3, free = 4 })[part] or 1
    add_four_button(deps, view, grid, 8, "Target Bone", selected, {
        function() set_aim_part("head") end,
        function() set_aim_part("chest") end,
        function() set_aim_part("leg") end,
        function() set_aim_part("free") end,
    })

    local speed = tonumber(rawget(_G, "custom_aim_speed")) or 50
    local fov = tonumber(rawget(_G, "custom_aim_range")) or 90
    local distance = tonumber(rawget(_G, "custom_aim_distance")) or 150
    local lock_time = tonumber(rawget(_G, "custom_aim_lock_time")) or 1
    rawset(_G, "custom_aim_speed", speed)
    rawset(_G, "custom_aim_range", fov)
    rawset(_G, "custom_aim_distance", distance)
    rawset(_G, "custom_aim_lock_time", lock_time)

    add_slider(deps, view, grid, 9, "Aim Speed", 1, 100, speed, 1, function(v) set_slider("custom_aim_speed", v) end)
    add_slider(deps, view, grid, 10, "Aim FOV", 1, 360, fov, 1, function(v) set_slider("custom_aim_range", v) end)
    add_slider(deps, view, grid, 11, "Aim Distance", 1, 500, distance, 1, function(v) set_slider("custom_aim_distance", v) end)
    add_slider(deps, view, grid, 12, "Aim Lock Delay", 1, 100, lock_time, 1, function(v) set_slider("custom_aim_lock_time", v) end)

    add_headers_async(deps, M._state, view, grid, build_token)
    pcall(function() view._wtResetPanel:Visible() end)
    pcall(function() view._wtResourceFixBtn:Collapsed() end)
    pcall(function() view:_ShowCloudBtn() end)
    return true
end

local function remove_existing_direct_tab(view, deps)
    local nav = safe_get(view, "_uiNavIDList")
    local tabs = safe_get(view, "_tabTable")
    if type(nav) ~= "table" or type(tabs) ~= "table" then return nil end
    local found
    for i = #nav, 1, -1 do
        local desc = tabs[i]
        if nav[i] == deps.row_id and type(desc) == "table" and desc.__dongdong_native_direct == true then
            if found == nil then found = desc end
            table.remove(nav, i); table.remove(tabs, i)
        end
    end
    return found
end

local function add_custom_tab(view, direct, deps)
    local nav = safe_get(view, "_uiNavIDList")
    local tabs = safe_get(view, "_tabTable")
    if type(nav) ~= "table" or type(tabs) ~= "table" then return false end
    local descriptor = remove_existing_direct_tab(view, deps) or {}
    descriptor.keyText = M.PAGE_TITLE
    descriptor.__dongdong_native_direct = true
    local index = direct == true and 1 or (#nav + 1)
    table.insert(nav, index, deps.row_id)
    table.insert(tabs, index, descriptor)
    M._state.tab_index = index
    pcall(function() deps.ui_manager:RegSwitchSubUI(view, nav) end)
    return true
end

local function is_custom_tab(view, requested, deps)
    local nav = safe_get(view, "_uiNavIDList")
    local tabs = safe_get(view, "_tabTable")
    local index = (tonumber(requested) or -1) + 1
    local desc = type(tabs) == "table" and tabs[index] or nil
    return type(nav) == "table"
        and nav[index] == deps.row_id
        and type(desc) == "table"
        and desc.__dongdong_native_direct == true
end

local function remove_native_root(deps, view)
    pcall(function() deps.ui_manager:RemoveSubUIByParent(view, view._wtRootMain) end)
end

local function make_generic_wrapper(class, method_name, before, after, state)
    local original = safe_get(class, method_name)
    if type(original) ~= "function" then return false end
    local prior = state.wrappers[method_name]
    if type(prior) == "table" and original == prior.wrapper then return true end

    local entry = { original = original }
    entry.wrapper = function(self, ...)
        local args = pack(...)
        if type(before) == "function" then pcall(before, self, args) end
        local results = pack(pcall(function() return original(self, unpack_values(args, 1, args.n)) end))
        local ok = results[1]
        if not ok then error(results[2], 0) end
        if type(after) == "function" then pcall(after, self, args) end
        return unpack_values(results, 2, results.n)
    end
    class[method_name] = entry.wrapper
    state.wrappers[method_name] = entry
    return safe_get(class, method_name) == entry.wrapper
end

local function restore_wrappers(class, wrappers)
    if type(class) ~= "table" or type(wrappers) ~= "table" then return end
    for method, entry in pairs(wrappers) do
        if type(entry) == "table" and type(entry.original) == "function" then
            if safe_get(class, method) == entry.wrapper then class[method] = entry.original end
        end
    end
end

local function install_hooks(deps, state)
    local class = deps.view_class
    local count = 0
    if make_generic_wrapper(class, "_InitDynamicBtns", nil, function(self) add_custom_tab(self, false, deps) end, state) then count = count + 1 end
    if make_generic_wrapper(class, "SetSelectedModePanel", function(self) add_custom_tab(self, false, deps) end,
        function(self) add_custom_tab(self, true, deps) end, state) then count = count + 1 end
    if make_generic_wrapper(class, "OnInitExtraData", nil, function(self) self._tabType = 1 end, state) then count = count + 1 end
    if make_generic_wrapper(class, "OnShowBegin", function(self) add_custom_tab(self, true, deps); self._tabType = 1 end,
        function(self) add_custom_tab(self, true, deps); self._tabType = 1 end, state) then count = count + 1 end
    if make_generic_wrapper(class, "OnActivate", nil, function(self) add_custom_tab(self, true, deps) end, state) then count = count + 1 end

    local original_fetch = safe_get(class, "_FetchSettingSystemByTab")
    if type(original_fetch) == "function" then
        local entry = { original = original_fetch }
        entry.wrapper = function(self, requested, ...)
            if is_custom_tab(self, requested, deps) then
                self._tabType = (tonumber(requested) or 0) + 1
                remove_native_root(deps, self)
                M.build_page(self)
                return
            end
            M.cleanup(self, deps)
            return original_fetch(self, requested, ...)
        end
        class._FetchSettingSystemByTab = entry.wrapper
        state.wrappers._FetchSettingSystemByTab = entry
        count = count + 1
    end

    local original_update = safe_get(class, "_UpdateSysetemSettingPanel")
    if type(original_update) == "function" then
        local entry = { original = original_update }
        entry.wrapper = function(self, ...)
            if is_custom_tab(self, (tonumber(self._tabType) or 1) - 1, deps) then
                remove_native_root(deps, self)
                M.build_page(self)
                return
            end
            M.cleanup(self, deps)
            return original_update(self, ...)
        end
        class._UpdateSysetemSettingPanel = entry.wrapper
        state.wrappers._UpdateSysetemSettingPanel = entry
        count = count + 1
    end

    if make_generic_wrapper(class, "OnHideBegin", function(self) M.cleanup(self, deps) end, nil, state) then count = count + 1 end
    if make_generic_wrapper(class, "OnClose", function(self) M.cleanup(self, deps) end, nil, state) then count = count + 1 end
    return count
end

M._state = {
    wrappers = {},
    installed = false,
    hook_count = 0,
    title_waiters = {},
    title_loading = false,
    title_class = nil,
}

function M.install()
    if M._state.installed == true and M._state.hook_count == M.REQUIRED_HOOK_COUNT then
        return M._state.hook_count
    end
    local deps = resolve_dependencies()
    if deps == nil then return 0 end
    M._deps = deps

    -- If the bytecode payload installed P0.29.105 first, replace it only after all
    -- dependencies are resolved. Restore only methods that still equal the recorded wrapper.
    local payload_state = rawget(_G, "custom_dongdong_api_settings")
    local old_wrappers = type(payload_state) == "table" and payload_state.wrappers or nil
    if type(old_wrappers) == "table" then restore_wrappers(deps.view_class, old_wrappers) end

    local new_state = {
        wrappers = {}, installed = false, hook_count = 0,
        title_waiters = M._state.title_waiters or {}, title_loading = M._state.title_loading == true,
        title_class = M._state.title_class,
    }
    local count = install_hooks(deps, new_state)
    new_state.hook_count = count
    new_state.row_id = deps.row_id
    new_state.installed = count == M.REQUIRED_HOOK_COUNT

    if not new_state.installed then
        restore_wrappers(deps.view_class, new_state.wrappers)
        -- Put previous bytecode wrappers back if they were removed.
        if type(old_wrappers) == "table" then
            for method, entry in pairs(old_wrappers) do
                if type(entry) == "table" and type(entry.wrapper) == "function" then
                    deps.view_class[method] = entry.wrapper
                end
            end
        end
        return 0
    end

    M._state = new_state
    rawset(_G, "custom_dongdong_api_settings", new_state)
    rawset(_G, "custom_character_color_setting_hook_count", count)
    rawset(_G, "InstallDongDongNativeSettingPage", M.install)
    return count
end

function M.takeover_after_payload_load()
    local count = M.install()
    if count ~= 0 then return true, count end
    -- Mirrors the finite retry windows present in P0.29 without creating a UI watchdog.
    for _, delay in ipairs({ 0.4, 1.2, 2.8 }) do
        delayed(delay, function()
            if M._state.installed ~= true then M.install() end
        end)
    end
    return false, 0
end

function M.get_catalog()
    return {
        prototype = M.PROTOTYPE,
        page_title = M.PAGE_TITLE,
        baseline_page_title = M.BASELINE_PAGE_TITLE,
        hook_methods = M.HOOK_METHODS,
        controls = M.UI_MODEL,
    }
end

local S = ...
assert(type(S) == "table", "spectra module table required")

local Runtime = assert(S.Runtime, "Runtime module required")
local Storage = assert(S.Storage, "Storage module required")
local M = {}
S.LoginUI = M

local state = Runtime.get_state()

local function ui_manager()
    local facade = rawget(_G, "Facade")
    return Runtime.safe_get(facade, "UIManager") or rawget(_G, "UIManager")
end

local function ui_id(name)
    return Runtime.safe_get(rawget(_G, "UIName2ID"), name)
end

local function clear_login_refs()
    state.login_ui = nil
    state.login_handle = nil
    state._s5 = false
    state._s6 = false
end

function M.is_live()
    local widget = state.login_ui
    if widget == nil then
        return false
    end

    -- No IsValid-style engine API is present in the baseline. Probe only fields
    -- that the baseline itself accesses; a destroyed userdata normally fails here.
    local inner = Runtime.safe_get(widget, "_wtCommonPopWinV2")
    if inner == nil then
        return false
    end
    return type(Runtime.safe_get(inner, "SetTitle")) == "function"
end

function M.close()
    local manager = ui_manager()
    local close_fn = Runtime.safe_get(manager, "CloseUI")
    if type(close_fn) == "function" and state.login_ui ~= nil then
        pcall(close_fn, manager, state.login_ui)
    end
    clear_login_refs()
end

local function configure_widget(widget, CommonPopWindows, center_confirm)
    state.login_ui = widget
    state._s5 = widget ~= nil
    state._s6 = false

    if widget == nil then
        return
    end

    local pop = Runtime.safe_get(widget, "_wtCommonPopWinV2")
    if pop == nil then
        return
    end

    local set_title = Runtime.safe_get(pop, "SetTitle")
    if type(set_title) == "function" then
        pcall(set_title, pop, "License Verification")
    end

    local handle_type = Runtime.safe_get(
        Runtime.safe_get(CommonPopWindows, "EHandleBtnType"),
        "Confirm"
    ) or 2

    local buttons = {}
    buttons[handle_type] = {
        btnText = "Unlock",
        fClickCallback = function()
            local input = Runtime.safe_get(widget, "_wt_WBP_inputBox")
            local get_text = Runtime.safe_get(input, "GetText")
            local card = ""
            if type(get_text) == "function" then
                local ok, value = pcall(get_text, input)
                if ok then card = value end
            end
            if S.Auth and type(S.Auth.authenticate) == "function" then
                S.Auth.authenticate(card)
            end
        end,
        caller = widget,
        bNeedClose = false,
        bNeedDeClose = false,
    }

    local set_buttons = Runtime.safe_get(pop, "SetConfirmBtnType")
    if type(set_buttons) == "function" then
        pcall(set_buttons, pop, center_confirm, buttons, true)
    end

    local set_close = Runtime.safe_get(pop, "SetPopIsOnClose")
    if type(set_close) == "function" then
        pcall(set_close, pop, false)
    end

    local set_background = Runtime.safe_get(pop, "SetBackgroudClickable")
    if type(set_background) == "function" then
        pcall(set_background, pop, false)
    end

    local collapse_close = Runtime.safe_get(pop, "CollapseCloseBtn")
    if type(collapse_close) == "function" then
        pcall(collapse_close, pop)
    end
end

function M.open_license(force)
    if state._s1 == true then
        return true
    end

    if M.is_live() then
        state._s5 = true
        return true
    end

    -- Stale flags/handles must never block a manual reopen.
    state.login_ui = nil
    state.login_handle = nil
    state._s5 = false
    if force then
        state._s6 = false
    elseif state._s6 == true then
        return true
    end

    local ok_param_mod, CommonRenameUIParam =
        pcall(require, "DFM.Business.DataStruct.CommonWidgetStruct.CommonRenameUIParam")
    local ok_pop_mod, CommonPopWindows =
        pcall(require, "DFM.Business.Module.CommonWidgetModule.UI.CommonPopWindows")

    local manager = ui_manager()
    local id = ui_id("CommonRenamePopWindows")
    local async_show = Runtime.safe_get(manager, "AsyncShowUI")
    local default_ctor = ok_param_mod and Runtime.safe_get(CommonRenameUIParam, "Default") or nil

    if not ok_param_mod
        or not ok_pop_mod
        or type(default_ctor) ~= "function"
        or id == nil
        or type(async_show) ~= "function" then
        return false
    end

    local ok_param, param = pcall(default_ctor)
    if not ok_param or param == nil then
        return false
    end

    Runtime.try_method(param, "SetTitle", "License Verification")
    Runtime.try_method(param, "SetContent", "Enter your license key to unlock")
    Runtime.try_method(param, "SetInputBoxHintText", "Enter license key")
    Runtime.try_method(param, "SetInputBoxText", Storage.get_card())

    local center_confirm = Runtime.safe_get(
        Runtime.safe_get(CommonPopWindows, "EConfirmBtnType"),
        "CenterConfirm"
    ) or 1
    Runtime.try_method(param, "SetConfirmBtnType", center_confirm)

    local set_callback = Runtime.safe_get(param, "SetCallback")
    if type(set_callback) == "function" then
        pcall(set_callback, param, function(card)
            if S.Auth and type(S.Auth.authenticate) == "function" then
                S.Auth.authenticate(card)
            end
        end)
    end

    state._s6 = true
    local ok_show, handle = pcall(
        async_show,
        manager,
        id,
        function(widget)
            configure_widget(widget, CommonPopWindows, center_confirm)
        end,
        nil,
        param
    )

    if not ok_show then
        state._s6 = false
        state._sb = tostring(handle)
        return false
    end

    state.login_handle = handle
    return true
end

-- Legacy/manual welcome. Automatic bootstrap never calls this, so ConfirmWindows
-- is no longer coupled to account-login -> Lobby transition.
function M.open_control()
    if state._s1 == true then
        return true
    end
    if state._s3 == true or state._s4 == true or M.is_live() or state._s6 == true then
        return true
    end

    local manager = ui_manager()
    local id = ui_id("ConfirmWindows")
    local async_show = Runtime.safe_get(manager, "AsyncShowUI")
    if manager == nil or id == nil or type(async_show) ~= "function" then
        return false
    end

    local unlock = function()
        state._s3 = false
        state._s4 = false
        Runtime.delay(0.2, function()
            M.open_license(true)
        end)
    end
    local later = function()
        state._s3 = false
        state._s4 = false
    end

    state._s4 = true
    local ok, handle = pcall(
        async_show,
        manager,
        id,
        nil,
        nil,
        "@DrkZeref  ",
        "This device is locked\nConnect securely and verify your license key to continue",
        unlock,
        later,
        "Later",
        "Unlock",
        nil, nil, nil, nil, nil, nil,
        false,
        true,
        nil
    )
    state._s4 = false

    if ok then
        state._s3 = true
        state.entry_handle = handle
        return true
    end
    state._sb = tostring(handle)
    return false
end

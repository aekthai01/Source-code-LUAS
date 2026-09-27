local S = ...
assert(type(S) == "table", "spectra module table required")

local Runtime = assert(S.Runtime, "Runtime module required")
local Storage = assert(S.Storage, "Storage module required")
local Auth = assert(S.Auth, "Auth module required")
local LoginUI = assert(S.LoginUI, "LoginUI module required")

local M = {}
S.Bootstrap = M

local state = Runtime.get_state()

local LOBBY_BIND_RETRY_SECONDS = 1.0
local LOBBY_BIND_RETRY_LIMIT = 60

local function initialize_state()
    if state._s0 == true then
        return false
    end
    state._s0 = true
    state._s1 = false
    state._s2 = false
    state._s3 = false
    state._s4 = false
    state._s5 = false
    state._s6 = false
    state._s7 = false
    state._s8 = 0
    state._s9 = type(state._s9) == "table" and state._s9 or {}
    state._sa = type(state._sa) == "table" and state._sa or {}
    state._sb = nil
    state._sc = nil
    state._sd = nil
    state._se = nil
    state.lobby_ready = false
    state.lobby_listener = nil
    state.lobby_listener_registered = false
    state.lobby_bind_retry_count = 0
    state.lobby_bind_retry_scheduled = false
    state.saved_key_invalid = false
    return true
end

local function is_lobby_ready_now()
    local facade = rawget(_G, "Facade")
    local manager = Runtime.safe_get(facade, "GameFlowManager")
    local get_current = Runtime.safe_get(manager, "GetCurrentGameFlow")
    local stage_type = rawget(_G, "EGameFlowStageType")
    local lobby = Runtime.safe_get(stage_type, "Lobby")
    if type(get_current) ~= "function" or lobby == nil then
        return false
    end
    local ok, current = pcall(get_current, manager)
    return ok and current == lobby
end

local function open_login_if_ready()
    if state._s1 == true or state._s7 == true then
        return
    end
    if state.lobby_ready == true then
        LoginUI.open_license(false)
    end
end

local function on_lobby_ready()
    state.lobby_ready = true
    Runtime.delay(0.6, open_login_if_ready)
end

local function register_lobby_listener()
    if state.lobby_listener_registered == true then
        return true
    end

    local ok, events = pcall(require, "DFM.BusinessEntrance.EntranceGlobalEvents")
    local event = ok and Runtime.safe_get(events, "evtLobbyBusinessInit") or nil
    local add_listener = Runtime.safe_get(event, "AddListener")
    if event == nil or type(add_listener) ~= "function" then
        state._sb = "evtLobbyBusinessInit unavailable"
        return false
    end

    local callback = function()
        on_lobby_ready()
    end
    local ok_add = pcall(add_listener, event, callback)
    if ok_add then
        state.lobby_listener = callback
        state.lobby_listener_registered = true
        state._sb = nil
    end
    return ok_add
end

local function can_schedule_delay()
    local timer = rawget(_G, "Timer")
    return type(Runtime.safe_get(timer, "DelayCall")) == "function"
end

local ensure_lobby_watcher

local function schedule_lobby_bind_retry()
    if state.lobby_bind_retry_scheduled == true
        or state.lobby_listener_registered == true
        or state.lobby_ready == true
        or state._s1 == true
        or state.lobby_bind_retry_count >= LOBBY_BIND_RETRY_LIMIT
        or not can_schedule_delay() then
        return false
    end

    state.lobby_bind_retry_scheduled = true
    local scheduled = Runtime.delay(LOBBY_BIND_RETRY_SECONDS, function()
        state.lobby_bind_retry_scheduled = false
        state.lobby_bind_retry_count = state.lobby_bind_retry_count + 1
        ensure_lobby_watcher()
    end)
    if not scheduled then
        state.lobby_bind_retry_scheduled = false
    end
    return scheduled
end

ensure_lobby_watcher = function()
    if state._s1 == true or state.lobby_ready == true then
        return true
    end

    if is_lobby_ready_now() then
        on_lobby_ready()
        return true
    end

    if register_lobby_listener() then
        if is_lobby_ready_now() then
            on_lobby_ready()
        end
        return true
    end

    schedule_lobby_bind_retry()
    return false
end

local function install_manual_entrypoints()
    rawset(_G, "OpenSpectraLogin", function()
        state._s5 = false
        state._s6 = false
        return LoginUI.open_license(true)
    end)

    rawset(_G, "OpenSpectraControl", function()
        state._s3 = false
        state._s4 = false
        return LoginUI.open_control()
    end)
end

local function start_saved_key_auth()
    local saved = Storage.get_card()
    if saved == "" then
        state.auto_login_attempted = false
        return false
    end

    state.auto_login_attempted = true
    state.auto_login_key = saved

    return Auth.authenticate(saved, function(ok, kind)
        state.auto_login_key = nil
        if ok then
            return
        end

        if kind == "server_reject" then
            Storage.clear_card()
            state.saved_key_invalid = true
        end

        if is_lobby_ready_now() then
            state.lobby_ready = true
        end
        open_login_if_ready()
    end)
end

function M.start()
    if not initialize_state() then
        return false
    end

    install_manual_entrypoints()

    local crypto_ok = S.Crypto.self_test()
    state._c7 = crypto_ok == true

    ensure_lobby_watcher()

    if not start_saved_key_auth() then
        open_login_if_ready()
    end

    return true
end

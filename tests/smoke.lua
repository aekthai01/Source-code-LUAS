local ROOT = arg[1] or "."
local function path(name) return ROOT .. "/src/spectra/" .. name end

local function clear_module(name)
    package.loaded[name] = nil
    package.preload[name] = nil
end

local function install_lobby_module(ctx)
    package.preload["DFM.BusinessEntrance.EntranceGlobalEvents"] = function()
        local evt = {}
        function evt:AddListener(cb)
            ctx.lobby_cb = cb
            ctx.lobby_listener_adds = (ctx.lobby_listener_adds or 0) + 1
            return true
        end
        return {evtLobbyBusinessInit = evt}
    end
    package.loaded["DFM.BusinessEntrance.EntranceGlobalEvents"] = nil
end

local function new_env(initial_key, opts)
    opts = opts or {}
    _G._x1 = nil
    _G.OpenSpectraLogin = nil
    _G.OpenSpectraControl = nil
    _G.DEVICE_ID = "WRONG-GLOBAL-DEVICE-ID"
    _G.ULuautils = nil
    _G.import = nil
    _G.Timer = nil
    _G.EGameFlowStageType = nil

    for _, name in ipairs({
        "DFM.BusinessEntrance.EntranceGlobalEvents",
        "DFM.Business.DataStruct.CommonWidgetStruct.CommonRenameUIParam",
        "DFM.Business.Module.CommonWidgetModule.UI.CommonPopWindows",
        "Common.Components.dkjson",
        "DFM.YxFramework.Plugin.Json.Json",
        "DFM.YxFramework.Managers.Resource.HttpLoader",
    }) do
        clear_module(name)
    end

    local store = {}
    if initial_key then store["SPECTRA_WY_71438_CARD"] = initial_key end

    local ctx = {
        ui_count = 0,
        tips = {},
        lobby_cb = nil,
        lobby_listener_adds = 0,
        payload_loads = 0,
        store = store,
        timers = {},
    }

    local pop = {
        SetTitle = function() end,
        SetPopIsOnClose = function() end,
        SetBackgroudClickable = function() end,
        CollapseCloseBtn = function() end,
        SetConfirmBtnType = function() end,
    }
    local input = { GetText = function() return "MANUAL-KEY" end }

    _G.Module = {
        CommonTips = {
            ShowSimpleTip = function(_, message, severity)
                ctx.tips[#ctx.tips + 1] = {message, severity}
            end,
        },
    }

    _G.Facade = {
        ConfigManager = {
            GetUserString = function(_, key) return store[key] or "" end,
            SetUserString = function(_, key, value) store[key] = value; return true end,
        },
        UIManager = {
            AsyncShowUI = function(_, id, callback, _, param, ...)
                ctx.ui_count = ctx.ui_count + 1
                local widget = {
                    _wtCommonPopWinV2 = pop,
                    _wt_WBP_inputBox = input,
                }
                ctx.last_widget = widget
                if type(callback) == "function" then callback(widget) end
                return widget
            end,
            CloseUI = function() return true end,
        },
    }
    _G.UIName2ID = {CommonRenamePopWindows = 101, ConfirmWindows = 102}

    if not opts.defer_lobby_module then
        install_lobby_module(ctx)
    end

    package.preload["DFM.Business.DataStruct.CommonWidgetStruct.CommonRenameUIParam"] = function()
        local Param = {}
        local mt = {__index = {
            SetTitle = function() end,
            SetContent = function() end,
            SetInputBoxHintText = function() end,
            SetInputBoxText = function() end,
            SetConfirmBtnType = function() end,
            SetCallback = function(self, cb) self.callback = cb end,
        }}
        function Param.Default() return setmetatable({}, mt) end
        return Param
    end
    package.loaded["DFM.Business.DataStruct.CommonWidgetStruct.CommonRenameUIParam"] = nil

    package.preload["DFM.Business.Module.CommonWidgetModule.UI.CommonPopWindows"] = function()
        return {
            EConfirmBtnType = {CenterConfirm = 1},
            EHandleBtnType = {Confirm = 2},
        }
    end
    package.loaded["DFM.Business.Module.CommonWidgetModule.UI.CommonPopWindows"] = nil

    if opts.timer_queue then
        _G.Timer = {
            DelayCall = function(seconds, cb)
                ctx.timers[#ctx.timers + 1] = {seconds = seconds, callback = cb}
                return true
            end,
        }
    end

    local S = {}
    for _, name in ipairs({
        "runtime.lua", "crypto.lua", "storage.lua", "transport.lua",
        "payload_embed.lua", "payload_loader.lua", "auth.lua",
        "login_ui.lua", "bootstrap.lua",
    }) do
        assert(loadfile(path(name)))(S)
    end

    -- Baseline DEVICE_ID is a private wrapper-config field, not _G.DEVICE_ID.
    S.Config.DEVICE_ID = "DEVICE-TEST"

    S.PayloadLoader.load_once = function()
        assert(type(_G.OpenSpectraLogin) == "function", "manual login global missing before payload load")
        assert(type(_G.OpenSpectraControl) == "function", "manual control global missing before payload load")
        local state = S.Runtime.get_state()
        if not state._s2 then
            state._s2 = true
            ctx.payload_loads = ctx.payload_loads + 1
        end
        return true
    end

    ctx.install_lobby_module = function() install_lobby_module(ctx) end
    ctx.run_next_timer = function()
        local item = table.remove(ctx.timers, 1)
        assert(item, "expected queued timer")
        item.callback()
        return item.seconds
    end

    return S, ctx
end

local function install_transport_success(S, verifier)
    S.Transport.get = function(_, url, callback)
        local data_hex = assert(url:match("[?&]data=([0-9a-f]+)"))
        local plaintext = S.Crypto.rc4(assert(S.Crypto.hex_decode(data_hex)), S.Auth.RC4_KEY)
        assert(plaintext:find("&markcode=DEVICE%-TEST&"), "private DEVICE_ID was not used")
        assert(not plaintext:find("WRONG%-GLOBAL"), "_G.DEVICE_ID leaked into request")
        if verifier then verifier(url, plaintext) end
        local t = assert(plaintext:match("&t=(%d+)"))
        local value = assert(plaintext:match("&value=([^&]+)"))
        local check = S.Crypto.md5(t .. S.Auth.REQUEST_SIGN_SECRET .. value)
        local response = string.format(
            '{"code":73913,"time":%s,"check":"%s","msg":"ok"}',
            t, check
        )
        callback(true, S.Crypto.rc4_encrypt_hex(response, S.Auth.RC4_KEY), nil)
        return true
    end
end

-- 1) Saved key: authenticate immediately, never create Login UI, payload exactly once.
do
    local S, ctx = new_env("SAVED-KEY")
    install_transport_success(S)
    assert(S.Runtime.get_device_id() == "DEVICE-TEST")
    assert(S.Bootstrap.start())
    local state = S.Runtime.get_state()
    assert(state._s1 == true, "saved-key auth did not succeed")
    assert(ctx.ui_count == 0, "saved-key path opened UI")
    assert(ctx.payload_loads == 1, "payload did not load exactly once")
    assert(ctx.store["SPECTRA_WY_71438_CARD"] == "SAVED-KEY")
end

-- 2) First-time: no UI before lobby; lobby event opens license UI once.
-- Destroyed widget must not be protected by a stale boolean.
do
    local S, ctx = new_env(nil)
    assert(S.Bootstrap.start())
    assert(ctx.ui_count == 0, "first-time path opened UI before lobby")
    assert(type(ctx.lobby_cb) == "function", "lobby listener was not installed")
    ctx.lobby_cb()
    assert(ctx.ui_count == 1, "lobby did not open license UI")
    local state = S.Runtime.get_state()
    assert(state._s5 == true)
    ctx.last_widget._wtCommonPopWinV2 = nil
    assert(_G.OpenSpectraLogin())
    assert(ctx.ui_count == 2, "manual reopen was blocked by stale UI state")
end

-- 3) Saved key rejected by server: clear it, do not loop, wait for lobby before UI.
do
    local S, ctx = new_env("BAD-KEY")
    S.Transport.get = function(_, _, callback)
        local response = '{"code":123,"time":1,"check":"","msg":"invalid key"}'
        callback(true, S.Crypto.rc4_encrypt_hex(response, S.Auth.RC4_KEY), nil)
        return true
    end
    assert(S.Bootstrap.start())
    assert(ctx.store["SPECTRA_WY_71438_CARD"] == "", "rejected saved key was not cleared")
    assert(ctx.ui_count == 0, "rejected saved key opened UI before lobby")
    ctx.lobby_cb()
    assert(ctx.ui_count == 1, "rejected saved key did not open UI after lobby")
end

-- 4) If injected after evtLobbyBusinessInit already fired, the payload-proven
-- GameFlowManager current-stage check recognizes Lobby.
do
    local S, ctx = new_env(nil)
    _G.EGameFlowStageType = {Lobby = 77}
    _G.Facade.GameFlowManager = {
        GetCurrentGameFlow = function() return 77 end,
    }
    assert(S.Bootstrap.start())
    assert(ctx.ui_count == 1, "already-in-Lobby state was not recognized")
end

-- 5) EntranceGlobalEvents can appear after wrapper start. Retry only listener
-- registration; never reopen UI on a timer.
do
    local S, ctx = new_env(nil, {defer_lobby_module = true, timer_queue = true})
    assert(S.Bootstrap.start())
    assert(ctx.ui_count == 0)
    assert(#ctx.timers == 1, "missing lobby module did not schedule bind retry")
    assert(ctx.timers[1].seconds == 1.0, "unexpected lobby bind retry cadence")

    ctx.install_lobby_module()
    ctx.run_next_timer()
    assert(type(ctx.lobby_cb) == "function", "late lobby module was not bound")
    assert(ctx.lobby_listener_adds == 1, "listener was registered more than once")
    assert(ctx.ui_count == 0, "listener retry opened UI by itself")

    ctx.lobby_cb()
    assert(#ctx.timers == 1, "lobby callback did not queue baseline 0.6 s delay")
    assert(ctx.run_next_timer() == 0.6)
    assert(ctx.ui_count == 1, "late-bound lobby event did not open login UI")
end

-- 6) Runtime bridges must use baseline paths/signatures.
do
    local S, ctx = new_env(nil)
    assert(S.Runtime.show_tip("tip-test", 5))
    assert(ctx.tips[#ctx.tips][1] == "tip-test")
    assert(ctx.tips[#ctx.tips][2] == 5)

    _G.ULuautils = {
        GetStringFromBytes = function(value)
            assert(value == "BYTE-VALUE", "GetStringFromBytes received an invented self argument")
            return "decoded-bytes"
        end,
    }
    assert(S.Runtime.bytes_to_string("already-string") == "already-string")
    local proxy = setmetatable({}, {__tostring = function() return "BYTE-VALUE" end})
    _G.ULuautils.GetStringFromBytes = function(value)
        assert(value == proxy, "GetStringFromBytes ABI mismatch")
        return "decoded-bytes"
    end
    assert(S.Runtime.bytes_to_string(proxy) == "decoded-bytes")

    package.preload["Common.Components.dkjson"] = function()
        return {
            decode = function(text, pos, null_value)
                assert(text == '{"code":7}')
                assert(pos == 1 and null_value == nil, "dkjson baseline decode ABI mismatch")
                return {code = 7}, #text + 1, nil
            end,
        }
    end
    package.loaded["Common.Components.dkjson"] = nil
    assert(S.Runtime.parse_json('{"code":7}').code == 7)

    clear_module("Common.Components.dkjson")
    package.preload["DFM.YxFramework.Plugin.Json.Json"] = function()
        return {
            createJson = function()
                return {
                    decode = function(text)
                        assert(text == '{"code":8}')
                        return {code = 8}
                    end,
                }
            end,
        }
    end
    package.loaded["DFM.YxFramework.Plugin.Json.Json"] = nil
    assert(S.Runtime.parse_json('{"code":8}').code == 8)
end

-- 7) HttpLoader fallback must complete once, unbind, and release once even if
-- the engine event fires repeatedly.
do
    local S = select(1, new_env(nil))
    local counts = {callback = 0, unbind = 0, release = 0, bind = 0}
    local captured
    local event = {}
    function event:Bind(cb, caller)
        counts.bind = counts.bind + 1
        captured = {cb = cb, caller = caller}
        return true
    end
    function event:Unbind(cb, caller)
        assert(captured and cb == captured.cb and caller == captured.caller)
        counts.unbind = counts.unbind + 1
        return true
    end
    local loader = {evtOnBatchComplete = event}
    function loader:RequestUrl(url, content_type)
        assert(url == "https://example.invalid/test")
        return "REQUEST-HANDLE"
    end
    function loader:Release()
        counts.release = counts.release + 1
    end
    package.preload["DFM.YxFramework.Managers.Resource.HttpLoader"] = function()
        return {
            NewIns = function(_, tag)
                assert(tag == "SPECTRA.http-loader-test")
                return loader
            end,
        }
    end
    package.loaded["DFM.YxFramework.Managers.Resource.HttpLoader"] = nil

    assert(S.Transport.get("http-loader-test", "https://example.invalid/test", function(ok, body, err)
        counts.callback = counts.callback + 1
        assert(ok == true and body == "BODY" and err == nil)
    end))
    assert(captured, "HttpLoader callback was not bound")
    captured.cb(nil, "not-request-handle", "BODY")
    captured.cb(nil, "not-request-handle", "BODY-AGAIN")
    assert(counts.callback == 1, "HttpLoader completed more than once")
    assert(counts.unbind == 1, "HttpLoader callback was not unbound exactly once")
    assert(counts.release == 1, "HttpLoader was not released exactly once")
end


-- 8) HttpLoader must not treat callback metadata/status strings as the body.
-- Baseline proto 0.16.1 consumes only its third callback parameter.
do
    local S = select(1, new_env(nil))
    local captured
    local event = {}
    function event:Bind(cb, caller)
        captured = {cb = cb, caller = caller}
        return true
    end
    function event:Unbind() return true end
    local loader = {evtOnBatchComplete = event}
    function loader:RequestUrl() return "REQUEST-HANDLE" end
    function loader:Release() end
    package.preload["DFM.YxFramework.Managers.Resource.HttpLoader"] = function()
        return {NewIns = function() return loader end}
    end
    package.loaded["DFM.YxFramework.Managers.Resource.HttpLoader"] = nil

    local result
    assert(S.Transport.get("arg-fidelity", "https://example.invalid/test", function(ok, body, err)
        result = {ok = ok, body = body, err = err}
    end))
    -- Second arg is deliberately a tempting string. The third arg is nil.
    captured.cb(nil, "THIS-IS-NOT-THE-BODY", nil)
    assert(result and result.ok == false, "HttpLoader incorrectly accepted callback metadata as body")
    assert(result.body == nil)
    assert(result.err == "HttpLoader returned an empty response")
end

print("smoke: ok")

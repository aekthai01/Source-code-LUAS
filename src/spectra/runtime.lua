local S = ...
assert(type(S) == "table", "spectra module table required")

local M = {}
S.Runtime = M
S.Config = type(S.Config) == "table" and S.Config or {}

local function safe_rawget(name)
    local ok, value = pcall(rawget, _G, name)
    if ok then
        return value
    end
    return nil
end

function M.safe_get(obj, key)
    local t = type(obj)
    if t ~= "table" and t ~= "userdata" then
        return nil
    end
    local ok, value = pcall(function()
        return obj[key]
    end)
    if ok then
        return value
    end
    return nil
end

function M.try_call(fn, ...)
    if type(fn) ~= "function" then
        return false, "not_a_function"
    end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        return false, tostring(a)
    end
    return true, a, b, c
end

function M.try_method(obj, name, ...)
    local fn = M.safe_get(obj, name)
    if type(fn) ~= "function" then
        return false, "missing_method:" .. tostring(name)
    end
    return M.try_call(fn, obj, ...)
end

function M.trim(value)
    local s = tostring(value or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

function M.normalize_card(value)
    local s = tostring(value or "")
    s = s:gsub("\239\187\191", "") -- U+FEFF
    s = s:gsub("\226\128\139", "") -- U+200B
    s = s:gsub("\226\128\140", "") -- U+200C
    s = s:gsub("\226\128\141", "") -- U+200D
    s = s:gsub("\226\129\160", "") -- U+2060
    s = s:gsub("\194\160", " ")     -- U+00A0
    s = s:gsub("\227\128\128", " ") -- U+3000
    s = M.trim(s)
    if #s >= 2 then
        local first = s:sub(1, 1)
        local last = s:sub(-1)
        if (first == '"' and last == '"') or (first == "'" and last == "'") then
            s = s:sub(2, -2)
        end
    end
    return (s:gsub("%s+", ""))
end

function M.delay(seconds, callback)
    local timer = safe_rawget("Timer")
    local delay_call = M.safe_get(timer, "DelayCall")
    if type(delay_call) ~= "function" then
        callback()
        return false
    end

    local ok = pcall(delay_call, seconds, callback)
    if not ok then
        ok = pcall(delay_call, timer, seconds, callback)
    end
    return ok
end

function M.show_tip(message, severity)
    local module_root = safe_rawget("Module")
    local tips = M.safe_get(module_root, "CommonTips")
    local fn = M.safe_get(tips, "ShowSimpleTip")
    if type(fn) ~= "function" then
        return false
    end
    return pcall(fn, tips, tostring(message or ""), severity or 3)
end

function M.get_timestamp()
    local os_table = safe_rawget("os")
    local time_fn = M.safe_get(os_table, "time")
    if type(time_fn) == "function" then
        local ok, value = pcall(time_fn)
        if ok and type(value) == "number" then
            return math.floor(value)
        end
    end
    return 0
end

function M.get_device_id()
    local direct = S.Config.DEVICE_ID
    if type(direct) == "string" and direct ~= "" then
        return direct
    end

    local bridge = safe_rawget("CharacterColorWeiYanGetDeviceId")
    if type(bridge) == "function" then
        local ok, value = pcall(bridge)
        if ok and value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end

    do
        local require_fn = safe_rawget("require")
        if type(require_fn) == "function" then
            local ok, info_module = pcall(require_fn, "Common.Framework.Util.DeviceOSInfo")
            if ok and info_module ~= nil then
                local get_info = M.safe_get(info_module, "GetDeviceOSInfo")
                if type(get_info) == "function" then
                    local ok_info, info = pcall(get_info)
                    if not ok_info then
                        ok_info, info = pcall(get_info, info_module)
                    end
                    if ok_info and info ~= nil then
                        for _, key in ipairs({"DeviceId", "deviceId", "device_id"}) do
                            local ok_value, value = pcall(function() return info[key] end)
                            if ok_value and value ~= nil and tostring(value) ~= "" then
                                return tostring(value)
                            end
                        end
                    end
                end
            end
        end
    end

    do
        local import_fn = safe_rawget("import")
        if type(import_fn) == "function" then
            local ok_import, module = pcall(import_fn, "GetDeviceInfo")
            if ok_import and module ~= nil then
                local get_info = M.safe_get(module, "GetDeviceInfo")
                if type(get_info) == "function" then
                    for _, key in ipairs({"QIMEI36", "QIMEI", "OAID", "ANDROID_ID", "DeviceId"}) do
                        local ok_value, value = pcall(get_info, key)
                        if not ok_value then
                            ok_value, value = pcall(get_info, module, key)
                        end
                        if ok_value and value ~= nil and tostring(value) ~= "" then
                            return tostring(value)
                        end
                    end
                end
            end
        end
    end

    do
        local server_root = safe_rawget("Server")
        local account_server = M.safe_get(server_root, "AccountServer")
        local get_player_id = M.safe_get(account_server, "GetPlayerId")
        if type(get_player_id) == "function" then
            local ok, value = pcall(get_player_id, account_server)
            if ok and value ~= nil then
                local text = tostring(value)
                if text ~= "" and text ~= "0" then
                    return "player-" .. text
                end
            end
        end
    end

    for _, name in ipairs({
        "GetDeviceId", "GetDeviceID", "GetUniqueDeviceId", "GetUniqueDeviceID",
        "GetMachineCode", "GetAndroidId", "GetAndroidID",
    }) do
        local fn = safe_rawget(name)
        if type(fn) == "function" then
            local ok, value = pcall(fn)
            if ok and value ~= nil and tostring(value) ~= "" then
                return tostring(value)
            end
        end
    end

    return nil, "Unable to read device ID: DeviceOSInfo/GetDeviceInfo is unavailable"
end

function M.bytes_to_string(value)
    if type(value) == "string" then
        return value
    end
    local util = safe_rawget("ULuautils")
    local fn = M.safe_get(util, "GetStringFromBytes")
    if type(fn) == "function" then
        local ok, result = pcall(fn, value)
        if ok and type(result) == "string" then
            return result
        end
    end
    return ""
end

function M.parse_json(text)
    local ok, dkjson = pcall(require, "Common.Components.dkjson")
    if ok and type(dkjson) == "table" and type(dkjson.decode) == "function" then
        local ok_decode, result, _, decode_err = pcall(dkjson.decode, text, 1, nil)
        if ok_decode and not decode_err and type(result) == "table" then
            return result
        end
    end

    local ok_dfm, json_mod = pcall(require, "DFM.YxFramework.Plugin.Json.Json")
    local create_json = ok_dfm and M.safe_get(json_mod, "createJson") or nil
    if type(create_json) == "function" then
        local ok_create, decoder = pcall(create_json)
        local decode = ok_create and M.safe_get(decoder, "decode") or nil
        if type(decode) == "function" then
            local ok_decode, result = pcall(decode, text)
            if ok_decode and type(result) == "table" then
                return result
            end
        end
    end

    local result = {
        code = tonumber(text:match([["code"%s*:%s*(-?%d+)]])),
        time = tonumber(text:match([["time"%s*:%s*(%d+)]])),
        check = text:match([["check"%s*:%s*"([0-9a-fA-F]+)"]]),
        msg = text:match([["msg"%s*:%s*"([^"]*)"]]),
    }
    if result.code then
        return result
    end
    return nil
end

function M.server_message(data)
    if type(data) ~= "table" then
        return "Invalid server data"
    end
    if type(data.msg) == "string" then
        return data.msg
    end
    if type(data.msg) == "table" then
        for _, key in ipairs({"msg", "message", "note"}) do
            local value = data.msg[key]
            if value ~= nil and M.trim(value) ~= "" then
                return M.trim(value)
            end
        end
    end
    return "Status code " .. tostring(data.code or "unknown")
end

function M.get_state()
    local state = rawget(_G, "_x1")
    if type(state) ~= "table" then
        state = {}
        rawset(_G, "_x1", state)
    end
    return state
end

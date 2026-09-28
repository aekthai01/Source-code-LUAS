local S = ...
assert(type(S) == "table", "spectra module table required")

local Runtime = assert(S.Runtime, "Runtime module required")
local M = {}
S.Transport = M

local state = Runtime.get_state()
state._s9 = type(state._s9) == "table" and state._s9 or {}
state._sa = type(state._sa) == "table" and state._sa or {}

local function http_downloader_body(value)
    local body = Runtime.bytes_to_string(value)
    if body == "" then
        return nil
    end
    return body
end

local function http_loader_body(payload, content_type)
    -- Baseline proto 0.16.1 reads only callback parameter R2 (the third
    -- parameter), first attempting payload[content_type], then the first table
    -- value, and finally passing that value to GetStringFromBytes. It does not
    -- scan status/request metadata arguments for a convenient string.
    local value = Runtime.safe_get(payload, content_type)
    if value == nil and type(payload) == "table" then
        for _, candidate in pairs(payload) do
            value = candidate
            break
        end
    end
    if value == nil then
        value = payload
    end

    local body = Runtime.bytes_to_string(value)
    if body == "" then
        return nil
    end
    return body
end

local function with_http_loader(tag, url, callback, previous_error)
    local ok_require, mod = pcall(require, "DFM.YxFramework.Managers.Resource.HttpLoader")
    local new_ins = ok_require and Runtime.safe_get(mod, "NewIns") or nil
    if type(new_ins) ~= "function" then
        callback(false, nil, "HttpLoader is unavailable; " .. tostring(previous_error or ""))
        return false
    end

    -- Baseline proto 0.16 invokes NewIns(module, "SPECTRA." .. tag).
    local ok_new, loader = pcall(new_ins, mod, "SPECTRA." .. tostring(tag))
    if not ok_new or loader == nil then
        callback(false, nil, "Failed to create HttpLoader; " .. tostring(previous_error or loader))
        return false
    end
    state._sa[tag] = loader

    local event = Runtime.safe_get(loader, "evtOnBatchComplete")
    local bind = Runtime.safe_get(event, "Bind")
    local request = Runtime.safe_get(loader, "RequestUrl")
    if type(bind) ~= "function" or type(request) ~= "function" then
        state._sa[tag] = nil
        local release = Runtime.safe_get(loader, "Release")
        if type(release) == "function" then pcall(release, loader) end
        callback(false, nil, "HttpLoader interface is incomplete")
        return false
    end

    local done = false
    local request_handle = nil
    local holder = {}

    local function finish(ok, body, err)
        if done then
            return
        end
        done = true
        state._sa[tag] = nil

        -- Baseline proto 0.16.0 explicitly unbinds the same callback/caller
        -- pair before releasing the loader.
        local unbind = Runtime.safe_get(event, "Unbind")
        if type(unbind) == "function" then
            pcall(unbind, event, holder.on_complete, holder)
        end

        local release = Runtime.safe_get(loader, "Release")
        if type(release) == "function" then
            pcall(release, loader)
        end
        callback(ok, body, err)
    end

    holder.on_complete = function(_, callback_request, payload)
        if done then return end
        -- Preserve the guard visible in baseline proto 0.16.1.
        if request_handle ~= nil and callback_request == request_handle then
            return
        end

        local content_root = rawget(_G, "EHttpContentType")
        local content_type = Runtime.safe_get(content_root, "String") or 1
        local body = http_loader_body(payload, content_type)
        if body == nil then
            finish(false, nil, "HttpLoader returned an empty response")
        else
            finish(true, body, nil)
        end
    end

    local ok_bind, bind_err = pcall(bind, event, holder.on_complete, holder)
    if not ok_bind then
        finish(false, nil, "Failed to bind HttpLoader callback: " .. tostring(bind_err))
        return false
    end

    local content_root = rawget(_G, "EHttpContentType")
    local content_type = Runtime.safe_get(content_root, "String") or 1
    local ok_start, start_result = pcall(request, loader, url, content_type)
    if not ok_start then
        finish(false, nil, "Failed to start HttpLoader: " .. tostring(start_result))
        return false
    end
    request_handle = start_result
    return true
end

function M.get(tag, url, callback)
    local import_fn = rawget(_G, "import")
    local mod = nil
    if type(import_fn) == "function" then
        local ok, result = pcall(import_fn, "HttpDownloader")
        if ok then mod = result end
    end

    local factory = Runtime.safe_get(mod, "HttpDownloader")
        or Runtime.safe_get(mod, "NewIns")
        or (type(mod) == "function" and mod or nil)

    if type(factory) ~= "function" then
        return with_http_loader(tag, url, callback, "HttpDownloader is unavailable")
    end

    local ok_new, downloader = pcall(factory)
    if not ok_new or downloader == nil then
        ok_new, downloader = pcall(factory, mod)
    end
    if not ok_new or downloader == nil then
        return with_http_loader(tag, url, callback,
            "Failed to create HttpDownloader: " .. tostring(downloader))
    end

    state._s9[tag] = downloader

    local success_event = Runtime.safe_get(downloader, "OnByteSuccess")
    local fail_event = Runtime.safe_get(downloader, "OnFail")
    local success_add = Runtime.safe_get(success_event, "Add")
    local fail_add = Runtime.safe_get(fail_event, "Add")
    local start = Runtime.safe_get(downloader, "StartDownLoadBytes")

    if type(success_add) ~= "function" or type(fail_add) ~= "function" or type(start) ~= "function" then
        state._s9[tag] = nil
        return with_http_loader(tag, url, callback, "HttpDownloader interface is incomplete")
    end

    local done = false
    local function complete(ok, body, err)
        if done then return false end
        done = true
        state._s9[tag] = nil
        callback(ok, body, err)
        return true
    end

    local function fallback_once(reason)
        if done then return false end
        done = true
        state._s9[tag] = nil
        return with_http_loader(tag, url, callback, reason)
    end

    local success_cb = function(value)
        if done then return end
        local body = http_downloader_body(value)
        if body == nil then
            fallback_once("HttpDownloader returned an empty response")
            return
        end
        complete(true, body, nil)
    end

    local fail_cb = function(...)
        if done then return end
        local args = {...}
        local reason = "HttpDownloader request failed"
        for i = #args, 1, -1 do
            if args[i] ~= nil and tostring(args[i]) ~= "" then
                reason = tostring(args[i])
                break
            end
        end
        fallback_once(reason)
    end

    local ok_success = pcall(success_add, success_event, success_cb)
    if not ok_success then ok_success = pcall(success_add, success_event, success_cb, downloader) end
    local ok_fail = pcall(fail_add, fail_event, fail_cb)
    if not ok_fail then ok_fail = pcall(fail_add, fail_event, fail_cb, downloader) end
    if not ok_success or not ok_fail then
        return fallback_once("Failed to bind HttpDownloader callbacks")
    end

    local ok_start, start_err = pcall(start, downloader, url)
    if not ok_start then
        return fallback_once("Failed to start HttpDownloader: " .. tostring(start_err))
    end
    return true
end

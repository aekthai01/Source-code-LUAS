local S = ...
assert(type(S) == "table", "spectra module table required")

local Runtime = assert(S.Runtime, "Runtime module required")
local Crypto = assert(S.Crypto, "Crypto module required")
local M = {}
S.PayloadLoader = M

local state = Runtime.get_state()

function M.load_once()
    if state._s2 == true then
        return true
    end
    if state._s1 ~= true then
        return false
    end

    local encoded = S.PayloadBase64
    if type(encoded) ~= "string" or encoded == "" then
        state._sb = "embedded_payload_missing"
        Runtime.show_tip("Module loading failed", 4)
        return false
    end

    local bytes, decode_err = Crypto.base64_decode(encoded)
    if type(bytes) ~= "string" then
        state._sb = tostring(decode_err or "embedded_payload_decode_failed")
        Runtime.show_tip("Module loading failed", 4)
        return false
    end

    local chunk, load_err = load(bytes, "@spectra-product", "b", _G)
    if type(chunk) ~= "function" then
        state._sb = tostring(load_err)
        Runtime.show_tip("Module loading failed", 4)
        return false
    end

    local ok, result = pcall(chunk)
    if not ok then
        state._sb = tostring(result)
        Runtime.show_tip("Module startup failed", 4)
        return false
    end

    state._s2 = true
    state.product = result
    state._sb = nil

    if type(S.PayloadUIBridge) == "table" and type(S.PayloadUIBridge.after_payload_load) == "function" then
        local bridge_ok, bridge_err = pcall(S.PayloadUIBridge.after_payload_load)
        if not bridge_ok then
            state._payload_ui_bridge_error = tostring(bridge_err)
        else
            state._payload_ui_bridge_error = nil
        end
    end

    S.PayloadBase64 = nil
    S.PayloadBase64Chunks = nil
    return true
end

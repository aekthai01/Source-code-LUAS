local S = ...
assert(type(S) == "table", "spectra module table required")

local Runtime = assert(S.Runtime, "Runtime module required")
local Crypto = assert(S.Crypto, "Crypto module required")
local Storage = assert(S.Storage, "Storage module required")
local Transport = assert(S.Transport, "Transport module required")
local PayloadLoader = assert(S.PayloadLoader, "PayloadLoader module required")

local M = {}
S.Auth = M

M.APP_ID = "71438"
M.REQUEST_SIGN_SECRET = "f052b3414cc670a954ab10a"
M.RC4_KEY = "gddbf544aa9a227c85f"
M.BASE_URL = "https://zxx.spwz.online/connect/kmlogon"
M.SUCCESS_CODE = 73913
M.FRESHNESS_SECONDS = 30

local state = Runtime.get_state()

local function make_challenge()
    local timestamp = tostring(Runtime.get_timestamp())
    local random_fn = type(math) == "table" and math.random or nil
    if type(random_fn) == "function" then
        local ok, value = pcall(random_fn, 1000, 99999)
        if ok and type(value) == "number" then
            return tostring(math.floor(value)) .. timestamp
        end
    end

    local seed = Crypto.md5(timestamp .. "|" .. tostring({}) .. "|" .. M.APP_ID)
    local n = tonumber(seed:sub(1, 8), 16) or 0
    n = (n % 99000) + 1000
    return tostring(n) .. timestamp
end

function M.build_request(card, device_id, secret_override)
    card = tostring(card)
    device_id = tostring(device_id)
    local timestamp = tostring(Runtime.get_timestamp())
    local value = make_challenge()
    local secret = tostring(secret_override or M.REQUEST_SIGN_SECRET)

    local sign_source = table.concat({
        "kami=", card,
        "&markcode=", device_id,
        "&t=", timestamp,
        "&", secret,
    })
    local sign = Crypto.md5(sign_source):lower()

    local plaintext = table.concat({
        "kami=", card,
        "&markcode=", device_id,
        "&t=", timestamp,
        "&sign=", sign,
        "&value=", value,
    })

    local encrypted = Crypto.rc4_encrypt_hex(plaintext, tostring(M.RC4_KEY))
    local sep = M.BASE_URL:find("?", 1, true) and "&" or "?"
    local url = M.BASE_URL
        .. sep .. "id=kmlogon"
        .. "&app=" .. Crypto.url_encode(M.APP_ID)
        .. "&data=" .. encrypted

    local diagnostic = {
        card = card,
        device_id = device_id,
        timestamp = tonumber(timestamp),
        value = value,
        sign = sign,
        _c1 = secret,
        signature_rule = "official_https_get_diagnostic",
        card_byte_length = #card,
        card_hex = Crypto.hex_lower(card),
        card_md5 = Crypto.md5(card),
        device_byte_length = #device_id,
        device_md5 = Crypto.md5(device_id),
        sign_source_length = #sign_source,
        sign_source_md5 = Crypto.md5(sign_source),
        inner_data_length = #plaintext,
        inner_data_md5 = Crypto.md5(plaintext),
        encrypted_length = #encrypted,
        encrypted_md5 = Crypto.md5(encrypted),
        url_length = #url,
        transport_scheme = "HTTPS",
    }
    return url, diagnostic
end

local function complete(on_result, ok, kind, message, data)
    if type(on_result) == "function" then
        pcall(on_result, ok, kind, message, data)
    end
end

local function fail(on_result, kind, message, severity)
    state._s7 = false
    state._sb = tostring(message or "")
    Runtime.show_tip(message, severity or 4)
    complete(on_result, false, kind, message, nil)
    return false
end

function M.authenticate(card, on_result)
    card = Runtime.normalize_card(card)

    if state._s7 == true then
        Runtime.show_tip("Verification request in progress", 2)
        complete(on_result, false, "busy", "Verification request in progress", nil)
        return false
    end
    if card == "" then
        Runtime.show_tip("Enter license key", 3)
        complete(on_result, false, "empty_key", "Enter license key", nil)
        return false
    end

    if state._c7 == nil then
        state._c7 = Crypto.self_test()
    end
    if state._c7 ~= true then
        Runtime.show_tip("Crypto self-test failed", 4)
        complete(on_result, false, "crypto_self_test", "Crypto self-test failed", nil)
        return false
    end

    local device_id, device_err = Runtime.get_device_id()
    if device_id == nil or device_id == "" then
        return fail(on_result, "device_id", tostring(device_err or "Unable to read device ID"), 4)
    end

    state._s7 = true
    Runtime.show_tip("Establishing secure connection", 2)

    local url, diagnostic = M.build_request(card, device_id)
    state._sc = {
        time = diagnostic.timestamp,
        value = diagnostic.value,
        device = device_id,
        sign = diagnostic.sign,
    }

    local request_timestamp = diagnostic.timestamp
    local request_value = diagnostic.value
    local tag = "login-" .. tostring(request_timestamp)

    local started = Transport.get(tag, url, function(ok, body, err)
        state._s7 = false

        if not ok then
            local text = Runtime.trim(err)
            if text == "" then text = "Network request failed" end
            state._sb = tostring(err)
            Runtime.show_tip("Connection failed: " .. text, 5)
            complete(on_result, false, "network", text, nil)
            return
        end

        local encrypted_response = Crypto.hex_decode(body)
        if encrypted_response == nil then
            state._sb = "response_not_hex"
            Runtime.show_tip("Invalid server response format", 4)
            complete(on_result, false, "response_format", "Invalid server response format", nil)
            return
        end

        local plaintext = Crypto.rc4(encrypted_response, M.RC4_KEY)
        local response = Runtime.parse_json(plaintext)
        state._sd = response

        if type(response) ~= "table" or tonumber(response.code) ~= M.SUCCESS_CODE then
            local message = Runtime.server_message(response)
            Runtime.show_tip("Verification failed: " .. message, 4)
            complete(on_result, false, "server_reject", message, response)
            return
        end

        local response_time = math.floor(tonumber(response.time) or 0)
        if response_time <= 0
            or math.abs(response_time - request_timestamp) > M.FRESHNESS_SECONDS then
            Runtime.show_tip("Verification failed: response expired", 4)
            complete(on_result, false, "response_freshness", "response expired", response)
            return
        end

        local expected_check = Crypto.md5(
            tostring(response_time) .. M.REQUEST_SIGN_SECRET .. request_value
        )
        local actual_check = tostring(response.check):lower()
        if actual_check ~= expected_check then
            Runtime.show_tip("Verification failed: data check failed", 4)
            complete(on_result, false, "response_check", "data check failed", response)
            return
        end

        state._s1 = true
        state.card = card
        state._se = response
        state._sb = nil
        Storage.set_card(card)

        if S.LoginUI and type(S.LoginUI.close) == "function" then
            S.LoginUI.close()
        end

        local loaded = PayloadLoader.load_once()
        if loaded then
            Runtime.show_tip("SPECTRA verification successful", 4)
            complete(on_result, true, "success", "SPECTRA verification successful", response)
        else
            complete(on_result, false, "payload_load", tostring(state._sb or "Module startup failed"), response)
        end
    end)

    if not started then
        state._s7 = false
        return false
    end
    return true
end

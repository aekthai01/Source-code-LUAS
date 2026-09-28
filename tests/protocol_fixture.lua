local ROOT = arg[1] or "."
local function path(name) return ROOT .. "/src/spectra/" .. name end

_G._x1 = nil
local S = {}
for _, name in ipairs({
    "runtime.lua", "crypto.lua", "storage.lua", "transport.lua",
    "payload_embed.lua", "payload_loader.lua", "auth.lua",
}) do
    assert(loadfile(path(name)))(S)
end

local original_timestamp = S.Runtime.get_timestamp
local original_random = math.random
S.Runtime.get_timestamp = function() return 1700000000 end
math.random = function(a, b)
    assert(a == 1000 and b == 99999)
    return 4242
end

local url, diag = S.Auth.build_request("CARD-TEST-001", "DEVICE-TEST")

S.Runtime.get_timestamp = original_timestamp
math.random = original_random

local expected_sign_source =
    "kami=CARD-TEST-001&markcode=DEVICE-TEST&t=1700000000&f052b3414cc670a954ab10a"
local expected_sign = "53d59cfbc96297ca3b013ad9784b6951"
local expected_value = "42421700000000"
local expected_plaintext =
    "kami=CARD-TEST-001&markcode=DEVICE-TEST&t=1700000000&sign=" ..
    expected_sign .. "&value=" .. expected_value
local expected_cipher =
    "a47752dde6fa03b45bba176f86ababddd664e4b7fb7f97ac91f2f56c50179d54" ..
    "feaeecee37fb7eff97a81c48fe9bc189543630549e4f544ac8402bd3e9ece7de" ..
    "7f6573db5c2dafa622a1dff85916cbb471fa64362b1ee7756e98a9091d5cd04d" ..
    "f22d10f6bfe5a5603db949dfbb0332"
local expected_url =
    "https://zxx.spwz.online/connect/kmlogon?id=kmlogon&app=3731343338&data=" .. expected_cipher

assert(diag.timestamp == 1700000000)
assert(diag.value == expected_value)
assert(diag.sign == expected_sign)
assert(S.Crypto.md5(expected_sign_source) == expected_sign)
assert(S.Crypto.rc4_encrypt_hex(expected_plaintext, S.Auth.RC4_KEY) == expected_cipher)
assert(url == expected_url, "wire URL drifted from deterministic fixture")
assert(S.Crypto.url_encode(S.Auth.APP_ID) == "3731343338")

print("protocol-fixture: ok")

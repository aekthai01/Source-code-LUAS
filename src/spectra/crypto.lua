local S = ...
assert(type(S) == "table", "spectra module table required")

local M = {}
S.Crypto = M

local MASK = 0xffffffff

local function u32(x)
    return x & MASK
end

local function rol(x, n)
    x = u32(x)
    return u32((x << n) | (x >> (32 - n)))
end

local MD5_SHIFT = {
    7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
    5,9,14,20, 5,9,14,20, 5,9,14,20, 5,9,14,20,
    4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
    6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21,
}

local MD5_K = {
    0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
    0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
    0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
    0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
    0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
    0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
    0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
    0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391,
}

local function le_u32(s, i)
    local a,b,c,d = s:byte(i, i + 3)
    return u32(a | (b << 8) | (c << 16) | (d << 24))
end

local function le_bytes_u32(x)
    x = u32(x)
    return string.char(
        x & 0xff,
        (x >> 8) & 0xff,
        (x >> 16) & 0xff,
        (x >> 24) & 0xff
    )
end

function M.md5(message)
    message = tostring(message or "")
    local original_len = #message
    local bit_len = original_len * 8

    local padding_len = (56 - ((original_len + 1) % 64)) % 64
    local low = bit_len & MASK
    local high = math.floor(bit_len / 4294967296) & MASK
    local padded = message .. "\128" .. string.rep("\0", padding_len)
        .. le_bytes_u32(low) .. le_bytes_u32(high)

    local a0 = 0x67452301
    local b0 = 0xefcdab89
    local c0 = 0x98badcfe
    local d0 = 0x10325476

    for offset = 1, #padded, 64 do
        local m = {}
        for j = 0, 15 do
            m[j] = le_u32(padded, offset + j * 4)
        end

        local A, B, C, D = a0, b0, c0, d0
        for i = 0, 63 do
            local F, g
            if i <= 15 then
                F = (B & C) | ((~B) & D)
                g = i
            elseif i <= 31 then
                F = (D & B) | ((~D) & C)
                g = (5 * i + 1) % 16
            elseif i <= 47 then
                F = B ~ C ~ D
                g = (3 * i + 5) % 16
            else
                F = C ~ (B | (~D))
                g = (7 * i) % 16
            end

            F = u32(F)
            local next_d = D
            D = C
            C = B
            B = u32(B + rol(u32(A + F + MD5_K[i + 1] + m[g]), MD5_SHIFT[i + 1]))
            A = next_d
        end

        a0 = u32(a0 + A)
        b0 = u32(b0 + B)
        c0 = u32(c0 + C)
        d0 = u32(d0 + D)
    end

    local digest = le_bytes_u32(a0) .. le_bytes_u32(b0) .. le_bytes_u32(c0) .. le_bytes_u32(d0)
    return (digest:gsub(".", function(ch)
        return string.format("%02x", string.byte(ch))
    end))
end

function M.rc4(data, key)
    data = tostring(data or "")
    key = tostring(key or "")
    assert(#key > 0, "RC4 key must not be empty")

    local s = {}
    for i = 0, 255 do
        s[i] = i
    end

    local j = 0
    for i = 0, 255 do
        j = (j + s[i] + key:byte((i % #key) + 1)) % 256
        s[i], s[j] = s[j], s[i]
    end

    local i = 0
    j = 0
    local out = {}
    for n = 1, #data do
        i = (i + 1) % 256
        j = (j + s[i]) % 256
        s[i], s[j] = s[j], s[i]
        local k = s[(s[i] + s[j]) % 256]
        out[n] = string.char(data:byte(n) ~ k)
    end
    return table.concat(out)
end

function M.hex_lower(data)
    return (data:gsub(".", function(ch)
        return string.format("%02x", string.byte(ch))
    end))
end

function M.hex_upper(data)
    return (data:gsub(".", function(ch)
        return string.format("%02X", string.byte(ch))
    end))
end

function M.hex_decode(text)
    text = tostring(text or "")
    if (#text % 2) ~= 0 or text:find("[^0-9A-Fa-f]") then
        return nil
    end
    local out = {}
    for i = 1, #text, 2 do
        out[#out + 1] = string.char(tonumber(text:sub(i, i + 1), 16))
    end
    return table.concat(out)
end

function M.rc4_encrypt_hex(data, key)
    return M.hex_lower(M.rc4(data, key))
end

function M.url_encode(value)
    return M.hex_upper(tostring(value or ""))
end

local B64 = {}
do
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #alphabet do
        B64[alphabet:sub(i, i)] = i - 1
    end
end

function M.base64_decode(text)
    text = tostring(text or ""):gsub("%s", "")
    if (#text % 4) ~= 0 then
        return nil, "invalid_base64_length"
    end

    local out = {}
    for pos = 1, #text, 4 do
        local c1 = text:sub(pos, pos)
        local c2 = text:sub(pos + 1, pos + 1)
        local c3 = text:sub(pos + 2, pos + 2)
        local c4 = text:sub(pos + 3, pos + 3)

        local a = B64[c1]
        local b = B64[c2]
        local c = (c3 == "=") and 0 or B64[c3]
        local d = (c4 == "=") and 0 or B64[c4]
        if a == nil or b == nil or c == nil or d == nil then
            return nil, "invalid_base64_character"
        end

        local n = (a << 18) | (b << 12) | (c << 6) | d
        out[#out + 1] = string.char((n >> 16) & 0xff)
        if c3 ~= "=" then
            out[#out + 1] = string.char((n >> 8) & 0xff)
        end
        if c4 ~= "=" then
            out[#out + 1] = string.char(n & 0xff)
        end
    end
    return table.concat(out)
end

function M.self_test()
    local rc4_vector = M.rc4_encrypt_hex("Plaintext", "Key")
    local md5_vector = M.md5("abc")
    return rc4_vector == "bbf316e8d940af0ad3"
       and md5_vector == "900150983cd24fb0d6963f7d28e17f72",
       rc4_vector,
       md5_vector
end

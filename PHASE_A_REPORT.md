# SPECTRA Lua 5.3 Reconstruction — Phase A / Phase C checkpoint

## 1. Baseline ที่ใช้

ไฟล์แนบในแชทนี้ถูกใช้เป็น source of truth เพียงไฟล์เดียว

- Size: **180,034 bytes**
- SHA-256: **`35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536`**
- Lua signature: `1b 4c 75 61`
- Version: `0x53` = **Lua 5.3**
- Format: `0`
- `LUAC_DATA`: `19 93 0d 0a 1a 0a`
- scalar sizes: `int=4`, `size_t=4`, `Instruction=4`, `lua_Integer=8`, `lua_Number=8`
- `LUAC_INT`: `0x5678`
- `LUAC_NUM`: `370.5`
- main upvalues: `1`

Outer chunk:

- prototypes: **83**
- instructions: **4,907**
- constants: **1,876**
- upvalues: **258**
- lineinfo: **0**
- locvars: **0**
- root: maxstack `68`, instructions `1114`, constants `914`, child prototypes `37`
- root source name: stripped / `nil`

ดังนั้นชื่อ local, comments และ debug line mapping ต้นฉบับกู้แบบ 1:1 ไม่ได้

## 2. Embedded payload

Outer root constants `K35..K835` เป็น Base64 ต่อเนื่อง **801 fragments**

- Base64 length: **144,712**
- decoded size: **108,533 bytes**
- decoded SHA-256: **`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`**
- Lua 5.3 bytecode อีกชั้น
- source name: **`穷途陌路        _全新寫法.lua`**
- prototypes: **296**
- instructions: **13,494**
- constants: **2,919**
- upvalues: **978**
- lineinfo: **0**
- locvars: **0**
- root: maxstack `21`, instructions `127`, constants `58`, child prototypes `30`

`embedded_payload.bin` ที่ export ออกมาเป็น bytes เดิมตรงกับ Base64 ใน baseline

## 3. Custom opcode permutation

Runtime ใช้ permutation คงที่ของ opcode space Lua 5.3 ไม่ใช่ per-function mapping

Mapping ที่ใช้กับ converter:

- raw `0` → `MOVE`
- raw `1` → `SELF`
- raw `2` → `ADD`
- raw `3` → `SUB`
- raw `4` → `MUL`
- raw `5` → `MOD`
- raw `6` → `POW`
- raw `7` → `DIV`
- raw `8` → `IDIV`
- raw `9` → `BAND`
- raw `10` → `BOR`
- raw `11` → `BXOR`
- raw `12` → `SHL`
- raw `13` → `SHR`
- raw `14` → `UNM`
- raw `15` → `BNOT`
- raw `16` → `NOT`
- raw `17` → `LEN`
- raw `18` → `CONCAT`
- raw `19` → `JMP`
- raw `20` → `EQ`
- raw `21` → `LT`
- raw `22` → `LE`
- raw `23` → `TEST`
- raw `24` → `TESTSET`
- raw `25` → `CALL`
- raw `26` → `TAILCALL`
- raw `27` → `RETURN`
- raw `28` → `FORLOOP`
- raw `29` → `FORPREP`
- raw `30` → `TFORCALL`
- raw `31` → `TFORLOOP`
- raw `32` → `SETLIST`
- raw `33` → `CLOSURE`
- raw `34` → `VARARG`
- raw `35` → `LOADK`
- raw `36` → `LOADKX`
- raw `37` → `LOADBOOL`
- raw `38` → `LOADNIL`
- raw `39` → `GETUPVAL`
- raw `40` → `GETTABUP`
- raw `41` → `GETTABLE`
- raw `42` → `SETTABUP`
- raw `43` → `SETUPVAL`
- raw `44` → `SETTABLE`
- raw `45` → `NEWTABLE`
- raw `46` → `EXTRAARG`

ระดับหลักฐานต้องแยกดังนี้:

- **44/47 raw opcodes ถูก observe โดยตรง** อย่างน้อยหนึ่งครั้งใน outer หรือ embedded payload และ semantic mapping สอดคล้องกับ instruction use
- raw `8` (`IDIV`), `36` (`LOADKX`), `46` (`EXTRAARG`) **ไม่ปรากฏในทั้งสอง chunks** จึงเป็น inferred slots จาก permutation structure / Lua 5.3 opcode space ไม่ใช่ semantic instance ที่ observe โดยตรง
- รายละเอียด count อยู่ใน `validation.json`

`tools/remap_lua53.py` ถูกตรวจด้วย baseline round-trip:

1. custom baseline → standard Lua 5.3 + `size_t=8`
2. standard → custom + `size_t=4`
3. output กลับมา SHA-256 **ตรง baseline เดิมทุก byte**

payload custom → standard → custom ก็กลับมา byte-identical เช่นกัน และ rebuilt custom chunk round-trip กลับเป็น compiler output ได้ตรงทุก byte

## 4. Protocol / crypto ที่ verify จาก bytecode

ค่าจริง:

- app id: **`71438`**
- request signing secret: **`f052b3414cc670a954ab10a`**
- RC4 key: **`gddbf544aa9a227c85f`**
- base URL: **`https://zxx.spwz.online/connect/kmlogon`**
- success code: **`73913`**
- freshness: **30 seconds**
- storage key: **`SPECTRA_WY_71438_CARD`**

Request signing source จริง:

```text
kami=<key>&markcode=<device>&t=<timestamp>&<request_sign_secret>
```

ดังนั้น `value` **ไม่อยู่ใน string ที่นำไป MD5 sign**

Request plaintext ที่ถูก RC4:

```text
kami=<key>&markcode=<device>&t=<timestamp>&sign=<md5(sign_source)>&value=<challenge>
```

Wire URL:

```text
https://zxx.spwz.online/connect/kmlogon?id=kmlogon&app=<encoded_app>&data=<rc4_hex>
```

รายละเอียดที่ hypothesis เดิมคลาดเคลื่อน:

- ฟังก์ชันใน binary ชื่อ `url_encode` แต่ behavior จริงคือ byte → uppercase `%02X` **โดยไม่มี `%`**
- เพราะฉะนั้น app บน wire คือ **`3731343338`**, ไม่ใช่ literal `71438`
- `data` เป็น lowercase hex

Response:

1. response body ต้องเป็น hex
2. hex decode
3. RC4 decrypt ด้วย `gddbf544aa9a227c85f`
4. parse JSON
5. `tonumber(code) == 73913`
6. `response_time = floor(tonumber(time) or 0)`
7. `response_time > 0`
8. `abs(response_time - request_timestamp) <= 30`
9. expected check:
   ```text
   md5(tostring(response_time) .. request_sign_secret .. request_value)
   ```
10. `lower(tostring(response.check)) == expected_check`

Crypto self-tests จาก source reconstruction ผ่าน:

- `RC4("Plaintext","Key")` → `bbf316e8d940af0ad3`
- `md5("abc")` → `900150983cd24fb0d6963f7d28e17f72`

หมายเหตุ: `"response expired"` ใน baseline หมายถึง response timestamp freshness ไม่ได้พิสูจน์ว่า license key หมดอายุ

## 5. Device ID lookup ที่พบจริง

Active authentication path ใช้ prototype `0.31` ซึ่งอ่านตามลำดับนี้:

1. `DEVICE_ID` จาก **private wrapper config table** (`root R0.DEVICE_ID`) ถ้าเป็น non-empty string
2. global function `CharacterColorWeiYanGetDeviceId()`
3. `require("Common.Framework.Util.DeviceOSInfo").GetDeviceOSInfo()`:
   - `DeviceId`
   - `deviceId`
   - `device_id`
4. `import("GetDeviceInfo").GetDeviceInfo(...)`:
   - `QIMEI36`
   - `QIMEI`
   - `OAID`
   - `ANDROID_ID`
   - `DeviceId`
5. `Server.AccountServer:GetPlayerId()` → `"player-" .. id`
6. global functions:
   - `GetDeviceId`
   - `GetDeviceID`
   - `GetUniqueDeviceId`
   - `GetUniqueDeviceID`
   - `GetMachineCode`
   - `GetAndroidId`
   - `GetAndroidID`

สำคัญ: `DEVICE_ID` ข้อแรก **ไม่ใช่ `_G.DEVICE_ID`**. Root prototype สร้าง config table ของ wrapper ไว้ใน `R0` และ `0.31` capture table นี้เป็น upvalue

Baseline ยังมี prototype `0.18` ซึ่งเป็น implementation รุ่นเก่าที่สามารถอ่าน/เขียน `SPECTRA_WY_71438_DEVICE` และสร้าง `dfm-<time>-<random>` fallback ได้ แต่ root ใส่ `0.18` ลง `R26` ที่ instruction `1043` แล้ว overwrite `R26` ด้วย `0.31` ที่ instruction `1079` **ก่อน** สร้าง authentication closure `0.22` ที่ instruction `1088`. ดังนั้น `0.18` ไม่อยู่ใน active login/auth path ของ baseline นี้

ใน active `0.31`, `_g0 == true` ทำให้ test-device fallback ถูกปิด และ failure คืน:

```text
Unable to read device ID: DeviceOSInfo/GetDeviceInfo is unavailable
```

Clean source จึงเก็บ optional override ไว้ใน `S.Config.DEVICE_ID` (private module config) และไม่อ่าน `_G.DEVICE_ID`, ไม่สร้าง device API และไม่ synthesize fake identifier

## 6. Storage

Baseline ใช้:

- `Facade.ConfigManager:GetUserString(key)`
- `Facade.ConfigManager:SetUserString(key, value)`

namespace/prefix:

```text
SPECTRA_WY_71438_
```

license key:

```text
SPECTRA_WY_71438_CARD
```

## 7. Login/UI behavior เดิม

ข้อค้นพบสำคัญ: **License UI ตัวจริงไม่ได้สร้างด้วย `ConfirmWindows`**

License UI ใช้:

- `DFM.Business.DataStruct.CommonWidgetStruct.CommonRenameUIParam`
- `DFM.Business.Module.CommonWidgetModule.UI.CommonPopWindows`
- `UIName2ID.CommonRenamePopWindows`
- `Facade.UIManager:AsyncShowUI(...)`

ค่า UI:

- title: `License Verification`
- content: `Enter your license key to unlock`
- hint: `Enter license key`
- button: `Unlock`
- input เริ่มจาก `GetUserString("SPECTRA_WY_71438_CARD")`
- `bNeedClose=false`
- `bNeedDeClose=false`
- close/background click ถูก disable เมื่อ method มีอยู่

`ConfirmWindows` เป็น **welcome entry window**:

- title: **`@DrkZeref  `**
- content:
  `This device is locked\nConnect securely and verify your license key to continue`
- buttons: `Later`, `Unlock`
- Unlock → `DelayCall(0.2, open_license)`

Startup เดิม:

- register `evtLobbyBusinessInit`; callback → `DelayCall(0.6, startup)`
- พร้อมกันนั้น root ยัง `DelayCall(0.8, startup)` อีกทาง
- `startup()` พยายามเปิด welcome และถ้าไม่ได้ จะ retry ทุก 1s สูงสุด 60 ครั้ง

จุดนี้คือ race ที่สำคัญ: welcome/entry path ถูก schedule ทั้งจาก root timer และ Lobby event ขณะที่ transition สามารถ destroy UI ได้

`OpenSpectraLogin` เดิม clear `_s3/_s4` แล้วเรียก license opener แต่ license opener short-circuit ถ้า `_s5` หรือ `_s6` ค้าง จึงมี stale-state failure ได้

## 8. Lobby readiness ที่ยืนยันเพิ่มจาก embedded payload

Payload prototypes `0.0` และ `0.11` ใช้ API จริง:

- `Facade.GameFlowManager`
- `GetCurrentGameFlow`
- `EGameFlowStageType.Lobby`
- และมี `CheckMainFlowSOL(...)`

Clean bootstrap ใช้ **เฉพาะ current-flow equality กับ `EGameFlowStageType.Lobby`** เป็น synchronous check เมื่อ script อาจถูกโหลดหลัง `evtLobbyBusinessInit` ผ่านไปแล้ว

จึงไม่ต้องใช้ infinite watchdog หรือ timer retry เพื่อเดาว่า Lobby พร้อมหรือยัง

## 9. Payload loading เดิม

เงื่อนไขเดิม:

- ถ้า `_s2 == true` → success ทันที
- ต้อง `_s1 == true` authenticated
- Base64 decode payload
- `load(bytes, "@spectra-product", "b", _G)`
- `pcall(chunk)`
- success:
  - `_s2=true`
  - `product=<return value>`
  - `_sb=nil`
  - release captured Base64
- error:
  - `Module loading failed` หรือ `Module startup failed`

Clean wrapper รักษา flow นี้และป้องกัน double-load

## 10. Network transport เดิม

Primary:

- `import("HttpDownloader")`
- instance factory
- `OnByteSuccess:Add(...)`
- `OnFail:Add(...)`
- `StartDownLoadBytes(url)`

Fallback:

- `require("DFM.YxFramework.Managers.Resource.HttpLoader")`
- `NewIns(..., "SPECTRA." .. tag)`
- `evtOnBatchComplete:Bind(...)`
- `RequestUrl(url, EHttpContentType.String or 1)`
- `Release()`

clean source ใช้ชื่อ API เหล่านี้เท่านั้น

## 11. Wrapper call graph และ clean architecture

Call graph baseline แบบ resolve prototype/upvalue โดยตรงอยู่ใน:

- `WRAPPER_CALL_GRAPH.md` — human-readable graph พร้อม prototype IDs และ instruction evidence
- `wrapper_call_graph.json` — machine-readable edge list

แกน baseline ที่ยืนยันได้คือ:

```text
root
 ├─ register Lobby listener (0.26) -> delay(0.6, startup 0.25)
 └─ delay(0.8, startup 0.25)

startup 0.25
 └─ welcome 0.24
     └─ Unlock -> delay(0.2, license 0.23)
         └─ input callback -> auth 0.22
             ├─ device lookup 0.31
             ├─ build request 0.35
             ├─ HTTP primary 0.17 -> fallback 0.16
             └─ response 0.22.0
                 ├─ hex decode / RC4 / JSON / checks
                 ├─ SetUserString(...CARD...)
                 ├─ close login UI 0.20
                 └─ payload load_once 0.19
```

Clean wrapper files:

- `src/spectra/runtime.lua`
- `src/spectra/crypto.lua`
- `src/spectra/storage.lua`
- `src/spectra/transport.lua`
- `src/spectra/auth.lua`
- `src/spectra/login_ui.lua`
- `src/spectra/payload_loader.lua`
- `src/spectra/payload_embed.lua`
- `src/spectra/bootstrap.lua`

Lifecycle behavior ใหม่:

1. install `OpenSpectraLogin` / `OpenSpectraControl` **ก่อน** เริ่ม authentication เพื่อรองรับ transport callback แบบ synchronous
2. crypto self-test
3. ตรวจ current Lobby stage และพยายาม bind `evtLobbyBusinessInit`
4. ถ้า event module ยังไม่พร้อม ใช้ finite **listener-registration retry** ทุก 1s สูงสุด 60 ครั้ง; retry นี้ไม่เปิด/reopen UI
5. ถ้ามี saved key → authenticate โดยไม่เปิด popup
6. success → save key, close UI, load payload once
7. no saved key → เปิด License UI เมื่อ Lobby ready เท่านั้น
8. saved key server reject (`code != 73913`) → clear saved key
9. response freshness/check/network error → ไม่ตีความเป็น license expiry และไม่ยิง request loop
10. `OpenSpectraLogin()` clear stale flags และ `LoginUI.open_license(force=true)` ตรวจ widget validity จริงก่อนตัดสินใจ reuse
11. automatic path **ไม่ใช้ ConfirmWindows**
12. `OpenSpectraControl()` คง legacy welcome path สำหรับ manual compatibility และใช้ `@DrkZeref  `

Runtime fidelity corrections หลัง audit:

- JSON primary path = `Common.Components.dkjson`; secondary = `DFM.YxFramework.Plugin.Json.Json`
- tip API = `_G.Module.CommonTips.ShowSimpleTip`
- `ULuautils.GetStringFromBytes` ถูกเรียกเป็น plain function ด้วย value argument เดียว
- HttpLoader completion มี done guard, `Unbind`, `Release` และ callback once
- private `S.Config.DEVICE_ID` แทน `_G.DEVICE_ID`

## 12. Validation ของ rebuild

Exact baseline copy ที่รวมใน bundle:

- `baseline_original.luac`
- size: **180,034 bytes**
- SHA-256: **`35ee381760ea24dcfebfac44433f8fe3078b4b34df79b165968bfeb87c874536`**

Embedded payload:

- size: **108,533 bytes**
- SHA-256: **`a0438b2eb2ecdec664dc25a6093766b9d79ab2dc6bc00536d59ff901798f6263`**

Generated source:

- `spectra_wrapper_source.lua`
- size: **199,103 bytes**
- SHA-256: **`7d55f64d93c450c53684203b67ed8ca4f0bc22e589f87af6649c61f923232997`**

Compiled standard Lua 5.3:

- `spectra_wrapper.standard.luac`
- size: **180,467 bytes**
- SHA-256: **`7c5d69b2bfec29c4f4bccce7a2544a8860cafabf6a3bb7acb56f8a74cb72004b`**

Compiled target custom chunk:

- `spectra_wrapper.custom.luac`
- size: **180,467 bytes**
- SHA-256: **`44a7705e2593daea5903f89671c58266ffaa455e1533ddbbbfb8ed4bf4b072d1`**
- target `size_t=4`
- recovered custom opcode permutation applied

`tools/build.py` เรียก `tools/validate.py` อัตโนมัติหลัง compile/remap ดังนั้น `validation.json` ถูก regenerate จาก artifacts ปัจจุบัน ไม่ใช่ static report ที่ต้องเชื่อด้วยความศรัทธา

Checks ปัจจุบัน:

- baseline exact size/hash
- payload exact size/hash
- `embedded_payload.b64` strict-decodes เป็น payload เดิม
- `payload_embed.lua` มี 801 fragments และประกอบกลับเป็น Base64/payload เดิม
- baseline custom → standard → custom byte-identical
- payload custom → standard → custom byte-identical
- rebuilt custom → standard เท่ากับ compiler output และ remap กลับ byte-identical
- Lua 5.3 chunk structure / target `size_t=4`
- RC4/MD5 known vectors
- deterministic fixed protocol fixture:
  - card `CARD-TEST-001`
  - device `DEVICE-TEST`
  - timestamp `1700000000`
  - challenge `42421700000000`
  - sign `53d59cfbc96297ca3b013ad9784b6951`
  - app wire value `3731343338`
  - fixed RC4/wire URL asserted byte-for-byte
- smoke tests cover:
  - saved-key auto-auth without UI and synchronous callback entrypoint ordering
  - first-time UI only after Lobby event
  - manual reopen after destroyed/stale widget
  - server rejection clears saved key without retry loop
  - already-in-Lobby current-stage fallback
  - late `EntranceGlobalEvents` availability / finite bind retry
  - exact JSON/CommonTips/GetStringFromBytes bridge paths/signatures
  - HttpLoader duplicate completion protection + Unbind/Release exactly once
  - HttpLoader callback body fidelity: only callback argument 3 is accepted as payload, matching baseline `P0.16.1`
- opcode evidence report: 44 direct / 3 inferred-only

สิ่งที่ยัง **ไม่ได้** verify ใน sandbox คือการรัน `spectra_wrapper.custom.luac` ภายในเกม/DFM engine จริง (`validation.json: checks.game_runtime_test=false`). ขั้นนี้ต้องใช้ runtime จริงและยังเป็น Phase C checkpoint ที่เปิดอยู่

## 13. Payload source reconstruction status

ยัง **ไม่ได้ rewrite payload** ตาม checkpoint ที่กำหนด

payload bytecode ที่ embed อยู่ไม่เปลี่ยน hash

พบ `@starrmods        ` ภายใน payload เดิมสองตำแหน่ง:

- payload proto `0.29.105`, constant `K31`
- payload proto `0.29.105.17.34`, constant `K3`

ส่วน wrapper ปัจจุบันใช้ `@DrkZeref  ` ตาม baseline

สอง string ใน payload ยังไม่ถูกแก้ เพราะ Phase C ต้องรักษา embedded payload byte-identical ก่อน runtime validation

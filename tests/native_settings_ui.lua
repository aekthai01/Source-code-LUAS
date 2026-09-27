local root = assert(arg[1], "root path required")

local function eq(actual, expected, label)
    if actual ~= expected then error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function ok(value, label) if not value then error(label or "assertion failed", 2) end end

local calls = {}
local created = {}
local function record(name, ...)
    calls[#calls + 1] = { name = name, args = { ... } }
end

EHorizontalAlignment = { HAlign_Fill = "HFill" }
EVerticalAlignment = { VAlign_Fill = "VFill", VAlign_Top = "VTop" }
ESlateVisibility = { Collapsed = "Collapsed" }
EConsumeMouseWheel = { WhenScrollingPossible = "WhenScrollingPossible" }

local function slot()
    return {
        SetRow = function(self, v) self.row = v end,
        SetColumn = function(self, v) self.column = v end,
        SetColumnSpan = function(self, v) self.span = v end,
        SetHorizontalAlignment = function(self, v) self.h = v end,
        SetVerticalAlignment = function(self, v) self.v = v end,
        SetPadding = function(self, v) self.padding = v end,
    }
end

FMargin = function(l,t,r,b) return { Left=l, Top=t, Right=r, Bottom=b } end
NewLuaLocText = function(text) return text end
getfromweak = function(v) return v end

local function make_btn2()
    local w = { Slot = slot(), kind = "btn2" }
    function w:InitBtnDynamic(title, a, b, selected)
        self.title, self.a, self.b, self.selected = title, a, b, selected
    end
    function w:SetBtnClickByIndex(i, cb) self.callbacks = self.callbacks or {}; self.callbacks[i] = cb end
    created[#created+1] = w
    return w
end
local function make_btn4()
    local title = { SetText = function(self, v) self.text = v end }
    local w = { Slot = slot(), kind = "btn4", _wtTitle = title }
    function w:SetBtnTxt(i, text) self.texts = self.texts or {}; self.texts[i] = text end
    function w:SetBtnClickByIndex(i, cb) self.callbacks = self.callbacks or {}; self.callbacks[i] = cb end
    function w:InitSettingBtnByEume(v) self.enum = v end
    created[#created+1] = w
    return w
end
local function make_slider()
    local w = { Slot = slot(), kind = "slider", _wtTxtValue = { SetText = function(self,v) self.text=v end } }
    function w:InitSettingSlider(minv,maxv,current,cb1,cb2,flag,step)
        self.min,self.max,self.current,self.cb1,self.cb2,self.flag,self.step = minv,maxv,current,cb1,cb2,flag,step
    end
    created[#created+1] = w
    return w
end

UIName2ID = { SystemSettingMainView=100, SettingBtnTwo=200, SettingBtnFour=201, SettingSlider=202 }
UITable = { SubUIs = {} }

local view_class = {}
local original_calls = {}
for _, name in ipairs({"_InitDynamicBtns","SetSelectedModePanel","OnInitExtraData","OnShowBegin","OnActivate","_FetchSettingSystemByTab","_UpdateSysetemSettingPanel","OnHideBegin","OnClose"}) do
    view_class[name] = function(self, ...)
        original_calls[name] = (original_calls[name] or 0) + 1
        return name, ...
    end
end

local ui_manager = {}
function ui_manager:AddSubUI(view, id, grid)
    if id == UIName2ID.SettingBtnTwo then return make_btn2() end
    if id == UIName2ID.SettingBtnFour then return make_btn4() end
    if id == UIName2ID.SettingSlider then return make_slider() end
    error("unexpected subui id: " .. tostring(id))
end
function ui_manager:RemoveSubUIByParent(view, child) record("RemoveSubUIByParent", view, child) end
function ui_manager:RegSwitchSubUI(view, nav) record("RegSwitchSubUI", view, nav) end
local resource_manager = {}
function resource_manager:AsyncLoadResource(owner, path, callback, extra)
    callback({ [path] = { __title_class = true } })
    return true
end
Facade = { UIManager = ui_manager, ResourceManager = resource_manager }

local ui_util = {}
function ui_util.AddWidgetToParent_Full(widget, parent) parent.full_child = widget end
function ui_util.SlotAsGridSlot(widget) return widget and widget.Slot end

local old_require = require
require = function(name)
    if name == "DFM.Business.Module.SystemSettingModule.UI.SystemSettingMainView" then return view_class end
    if name == "DFM.YxFramework.Managers.UI.Util.UIUtil" then return ui_util end
    return old_require(name)
end

GridPanel = function()
    local g = { children = {} }
    function g:SetColumnFill(i,v) self["fill"..i] = v end
    function g:AddChildToGrid(widget,row,column)
        local s = widget.Slot or slot(); widget.Slot=s
        self.children[#self.children+1] = widget
        return s
    end
    function g:RemoveFromParent() self.removed=true end
    function g:InvalidateLayoutAndVolatility() self.invalidated=true end
    return g
end
ScrollBox = function()
    local s = {}
    function s:SetConsumeMouseWheel(v) self.consume=v end
    function s:SetScrollBarVisibility(v) self.scrollbar=v end
    function s:SetAnimateWheelScrolling(v) self.animate=v end
    function s:AddChild(child) self.child=child; self.child_slot=slot(); return self.child_slot end
    function s:RemoveFromParent() self.removed=true end
    return s
end
WidgetBlueprintLibrary = {
    Create = function(context, class, owner)
        local line = { SetVisibility=function(self,v) self.visibility=v end }
        local txt = { SetText=function(self,v) self.text=v end, SetFontStyleID=function(self,v) self.font=v end }
        local w = { wtDFTextBlockTitle=txt, line=line, Slot=slot() }
        function w:GetWidgetFromName(name) if name=="Line_113" then return line elseif name=="wtDFTextBlockTitle" then return txt end end
        function w:SynchronizeProperties() self.synced=true end
        return w
    end
}
WidgetLayoutLibrary = {}
import = function(name)
    if name=="GridPanel" then return GridPanel end
    if name=="ScrollBox" then return ScrollBox end
    if name=="WidgetBlueprintLibrary" then return WidgetBlueprintLibrary end
    if name=="WidgetLayoutLibrary" then return WidgetLayoutLibrary end
    if name=="Margin" then return function() return {} end end
end
Timer = { DelayCall = function(seconds, fn) fn(); return true end }

set_dongdong_feature_config = function(name, enabled) record("feature", name, enabled); custom_dongdong_toggle_state[name]=enabled; return true end
set_dongdong_aim_part = function() record("aim_part", custom_aim_target_part); return true end
set_ai_color = function(v) record("ai_color", v); custom_ai_color_key=v; return true end
set_real_player_color = function(v) record("real_color", v); custom_real_color_key=v; return true end
set_character_xray = function(v) record("xray", v); custom_character_xray_enabled=v; return true end
custom_dongdong_toggle_state = { no_recoil=false, converge=false, aim=false, anti_shake=false }
custom_ai_color_key = "red"
custom_ai_color_last_key = "red"
custom_real_color_key = "green"
custom_character_xray_enabled = true

-- Simulate bytecode payload wrappers already installed. Takeover must restore them transactionally first.
local baseline_wrappers = {}
for _, name in ipairs({"_InitDynamicBtns","SetSelectedModePanel","OnInitExtraData","OnShowBegin","OnActivate","_FetchSettingSystemByTab","_UpdateSysetemSettingPanel","OnHideBegin","OnClose"}) do
    local original = view_class[name]
    local wrapper = function(self, ...) return original(self, ...) end
    baseline_wrappers[name] = { original=original, wrapper=wrapper }
    view_class[name] = wrapper
end
custom_dongdong_api_settings = { wrappers=baseline_wrappers, installed=true, hook_count=9 }

local S = {}
assert(loadfile(root .. "/src/spectra/native_settings_ui.lua"))(S)
local UI = assert(S.NativeSettingsUI)
eq(UI.PAGE_TITLE, "@DrkZeref", "reconstructed page title")
eq(#UI.HOOK_METHODS, 9, "hook method count")

local count = UI.install()
eq(count, 9, "installed hook count")
eq(custom_character_color_setting_hook_count, 9, "published hook count")
eq(InstallDongDongNativeSettingPage, UI.install, "global installer alias")
ok(custom_dongdong_api_settings ~= nil and custom_dongdong_api_settings.installed == true, "new settings state")
for _, name in ipairs(UI.HOOK_METHODS) do
    ok(view_class[name] ~= baseline_wrappers[name].wrapper, "baseline wrapper replaced: "..name)
end

local after_first_install = view_class.OnClose
eq(UI.install(), 9, "idempotent install count")
eq(view_class.OnClose, after_first_install, "idempotent install wrapper")

local view = {
    _uiNavIDList = { 900 },
    _tabTable = { { keyText="Original" } },
    _wtRootMain = {},
    _wtResetPanel = { Visible=function(self) self.visible=true end },
    _wtResourceFixBtn = { Collapsed=function(self) self.collapsed=true end },
    _ShowCloudBtn = function(self) self.cloud=true end,
}
setmetatable(view, { __index=view_class })

view:SetSelectedModePanel()
eq(view._uiNavIDList[1], UIName2ID.SettingBtnTwo, "custom tab row id")
eq(view._tabTable[1].keyText, "@DrkZeref", "custom tab title")
ok(view._tabTable[1].__dongdong_native_direct == true, "direct custom tab marker")

view:_FetchSettingSystemByTab(0)
ok(view._dongdong_native_grid ~= nil, "custom grid built")
ok(view._dongdong_native_scroll ~= nil, "custom scroll built")
eq(#view._dongdong_native_buttons, 13, "feature control widget count")
eq(#view._dongdong_native_widgets, 4, "section/title widget count")

local by_title = {}
for _, w in ipairs(view._dongdong_native_buttons) do if w.title then by_title[w.title]=w end end
eq(by_title["No Recoil"].a, "Enable", "No Recoil enable label")
eq(by_title["No Recoil"].b, "Disable", "No Recoil disable label")
eq(by_title["Bullet Spread Control"].Slot.row, 2, "spread row")
eq(by_title["ADS Aim"].Slot.column, 1, "ADS column")
eq(by_title["Bot Highlight"].selected, true, "bot highlight initial")
eq(by_title["Bot Color"].a, "Red", "bot red label")
eq(by_title["Player Color"].b, "Green", "player green label")
eq(by_title["Player X-Ray"].selected, true, "xray initial")

local target, sliders = nil, {}
for _, w in ipairs(view._dongdong_native_buttons) do
    if w.kind=="btn4" then target=w end
    if w.kind=="slider" then sliders[w.BpTitle]=w end
end
ok(target ~= nil, "target selector exists")
eq(target.texts[1], "Head", "target head")
eq(target.texts[4], "Point & Shoot", "target free")
eq(target.enum, 0, "default target enum")
eq(sliders["Aim Speed"].min, 1, "speed min"); eq(sliders["Aim Speed"].max,100,"speed max"); eq(sliders["Aim Speed"].current,50,"speed default")
eq(sliders["Aim FOV"].max,360,"fov max"); eq(sliders["Aim FOV"].current,90,"fov default")
eq(sliders["Aim Distance"].max,500,"distance max"); eq(sliders["Aim Distance"].current,150,"distance default")
eq(sliders["Aim Lock Delay"].max,100,"lock max"); eq(sliders["Aim Lock Delay"].current,1,"lock default")

by_title["No Recoil"].callbacks[1]()
eq(calls[#calls].name, "feature", "feature callback name")
eq(calls[#calls].args[1], "no_recoil", "feature callback key")
eq(calls[#calls].args[2], true, "feature callback enabled")

target.callbacks[4]()
eq(custom_aim_target_part, "free", "target callback state")
eq(calls[#calls].name, "aim_part", "target callback dispatch")

sliders["Aim FOV"].cb1(123)
eq(custom_aim_range, 123, "slider state")

-- Cleanup hooks should not call original with stale custom UI left attached.
view:OnClose()
eq(view._dongdong_native_grid, nil, "grid cleaned on close")
eq(view._dongdong_native_scroll, nil, "scroll cleaned on close")

print("native-settings-ui: ok")

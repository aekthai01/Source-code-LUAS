local S = ...
assert(type(S) == "table", "spectra module table required")
local UI = assert(S.NativeSettingsUI, "NativeSettingsUI module required")
local M = {}
S.PayloadUIBridge = M

function M.after_payload_load()
    local ui_ok = UI.takeover_after_payload_load()
    local feature_ok = true
    if type(S.PayloadFeatureBridge) == "table" and type(S.PayloadFeatureBridge.takeover_after_payload_load) == "function" then
        feature_ok = S.PayloadFeatureBridge.takeover_after_payload_load()
    end
    local visual_ok = true
    if type(S.PayloadVisualBridge) == "table" and type(S.PayloadVisualBridge.takeover_after_payload_load) == "function" then
        visual_ok = S.PayloadVisualBridge.takeover_after_payload_load()
    end
    local product_ok = true
    if type(S.ProductModuleBridge) == "table"
        and type(S.ProductModuleBridge.after_payload_load) == "function" then
        local state = S.Runtime.get_state()
        product_ok = S.ProductModuleBridge.after_payload_load(state.product)
    end
    return ui_ok and feature_ok and visual_ok and product_ok
end

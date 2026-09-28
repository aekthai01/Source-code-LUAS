local root=assert(arg[1])
local S={}
assert(loadfile(root.."/src/spectra/product_context.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module.lua"))(S)
assert(loadfile(root.."/src/spectra/product_constructor.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module_bridge.lua"))(S)
local Product,Constructor,Bridge=S.ProductModule,S.ProductConstructor,S.ProductModuleBridge
local function eq(a,b,label) if a~=b then error((label or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function sequence(actual,expected,label)
    eq(#actual,#expected,label.." count")
    for i,value in ipairs(expected) do eq(actual[i],value,label.." #"..i) end
end
local logs,calls={},{}
local function log(...) logs[#logs+1]=table.pack(...) end
local function reset() logs={};calls={} end
local download,skin,shipping,part_result={},nil,false,false
local pkg={}
function pkg:GetDownloadCategary(id)
    eq(self,pkg,"LitePackage GetDownloadCategary SELF")
    calls[#calls+1]="category:"..tostring(id)
    if id==nil then return nil end
    return "cat:"..tostring(id)
end
function pkg:IsDownloadedByModuleName(category)
    eq(self,pkg,"LitePackage IsDownloadedByModuleName SELF")
    calls[#calls+1]="download:"..tostring(category)
    if category==nil then return false end
    return download[category]
end
local runtime_key="runtime-part"
function pkg:GetRuntimeWeaponPartModuleKey()
    eq(self,pkg,"LitePackage runtime SELF")
    calls[#calls+1]="runtime"
    return runtime_key
end
local expansion={}
expansion.GetWeaponPartItemResDownloaded=function(self)
    eq(self,expansion,"ExpansionPackCoordinator SELF")
    calls[#calls+1]="part"
    return part_result
end
local item_base={GetWeaponSkinIDFromPropInfo=function(...)
    local args=table.pack(...)
    eq(args.n,1,"ItemBase plain/static ABI")
    calls[#calls+1]="skin:"..tostring(args[1].id)
    return args[1].skin_id
end}
local version={IsShipping=function(...)
    eq(select("#",...),0,"VersionUtil plain/static ABI")
    calls[#calls+1]="shipping"
    return shipping
end}
local unique,main_type,sub_type=false,"normal","normal"
local helper={
    GetMainTypeById=function(...)
        local args=table.pack(...);eq(args.n,1,"GetMainTypeById plain ABI")
        calls[#calls+1]="main:"..tostring(args[1]); return main_type
    end,
    GetSubTypeById=function(...)
        local args=table.pack(...);eq(args.n,1,"GetSubTypeById plain ABI")
        calls[#calls+1]="sub:"..tostring(args[1]); return sub_type
    end,
    IsArmedForceUniquePropByItem=function(...)
        local args=table.pack(...);eq(args.n,1,"IsArmedForceUniquePropByItem plain ABI")
        calls[#calls+1]="unique:"..tostring(args[1].id); return unique
    end,
}
local env={Module={LitePackage=pkg,ExpansionPackCoordinator=expansion},ItemBase=item_base,
    VersionUtil=version,ipairs=ipairs,EItemType={WeaponSkin="weapon-skin"},
    ItemConfig={EWeaponItemType={HeroProp="hero-prop"}},
    ESlotType={MainWeaponLeft=1,MainWeaponRight=2,Pistrol=3,BreastPlate=4,Helmet=5,ChestHanging=6,Bag=7,
        ChestHangingContainer=8,Pocket=9,BagContainer=10,SafeBoxContainer=11},
}
local function create()
    local ctx={product={},item_helper=helper,info_logger=log,globals=env}
    return Constructor.create(ctx,env),ctx
end
local a,ctx=create()
local b=create()
eq(a,ctx.product,"constructor R3 identity")
eq(a~=b,true,"independent product tables")
for name,path in pairs({
    _CheckPropinfoDownloadWithLog="0.24",_CheckItemWithCompsDownloaded="0.25",
    _CheckItemIdDownloaded="0.26",_CheckAllWeaponPartDownloaded="0.27",
    GetNeedDownloadCategaryKey="0.28"}) do eq(Product.PROTOTYPES[name],path,name.." prototype") end

-- P0.24: zero results for nil/false category, one result for every truthy category.
reset();eq(table.pack(a._CheckPropinfoDownloadWithLog(nil,7,"k")).n,0,"P0.24 nil arity")
eq(table.pack(a._CheckPropinfoDownloadWithLog(false,7,"k")).n,0,"P0.24 false arity")
eq(#calls,0);eq(#logs,0)
reset();download.x=true
local ok=table.pack(a._CheckPropinfoDownloadWithLog("x",37,"k"))
eq(ok.n,1);eq(ok[1],true);sequence(calls,{"download:x"},"P0.24 true SELF")
eq(#logs,0)
reset();download.x=false
ok=table.pack(a._CheckPropinfoDownloadWithLog("x",37,nil))
eq(ok.n,1);eq(ok[1],false);eq(#logs,0,"nil dedupe key not logged")
a._CheckPropinfoDownloadWithLog("x",37,false)
eq(#logs,0,"false dedupe key not logged")
reset();a._CheckPropinfoDownloadWithLog("x",37,"same")
eq(#logs,1);eq(logs[1].n,3,"P0.24 logger arity")
eq(logs[1][1],"[ DownloadCheck MA1 ] CheckEquipLogic._CheckItemWithCompsDownloaded(item) 当前道具包含道具/配件/皮肤资源尚未下载")
eq(logs[1][2],37);eq(logs[1][3],"same")
a._CheckPropinfoDownloadWithLog("another",38,"same")
eq(#logs,1,"P0.24 R12 shared across method calls, key not category")
a._CheckPropinfoDownloadWithLog("x",37,"different")
eq(#logs,2,"new P0.24 key logs")
b._CheckPropinfoDownloadWithLog("x",37,"same")
eq(#logs,3,"P0.24 R12 per-root lifetime")
-- Equal keys in R12 and R13 must not collide.
reset();download["cat:same"]=false
a._CheckItemIdDownloaded("same")
eq(#logs,1,"P0.26 R13 independent of R12")
eq(logs[1].n,2);eq(logs[1][1],"[ DownloadCheck SHE1 ] CheckEquipLogic._CheckItemIdDownloaded(itemId) 当前道具id对应资源尚未下载")
eq(logs[1][2],"same")
reset();a._CheckItemIdDownloaded("same");eq(#logs,0,"P0.26 R13 repeat dedupes")
a._CheckItemIdDownloaded("new");eq(#logs,1,"P0.26 different ID logs")
b._CheckItemIdDownloaded("same");eq(#logs,2,"P0.26 R13 per-root lifetime")
reset();download["cat:yes"]=true
local idok=table.pack(a._CheckItemIdDownloaded("yes"))
eq(idok.n,1);eq(idok[1],true);eq(#logs,0)
reset(); -- nil lookup is legal; both SELF calls must happen
local idnil=table.pack(a._CheckItemIdDownloaded(nil))
eq(idnil.n,1);eq(idnil[1],false)
sequence(calls,{"category:nil","download:nil"},"P0.26 nil ID still calls both")
eq(#logs,0)
reset();part_result=false
a._CheckAllWeaponPartDownloaded();a._CheckAllWeaponPartDownloaded()
sequence(calls,{"part","part"},"P0.27 every failure SELF")
eq(#logs,2);eq(logs[1].n,2);eq(logs[1][1],"[ DownloadCheck SHE1 ] CheckEquipLogic._CheckAllWeaponPartDownloaded() 武器大小包资源尚未下载")
eq(logs[1][2],false)
reset();part_result=true
ok=table.pack(a._CheckAllWeaponPartDownloaded())
eq(ok.n,1);eq(ok[1],true);eq(#logs,0)

-- P0.25 no raw: nil is the only early item gate. R3 helper is dynamic/plain.
reset();eq(a._CheckItemWithCompsDownloaded(nil),true)
eq(table.pack(a._CheckItemWithCompsDownloaded(nil)).n,1);eq(#calls,0)
reset();eq(a._CheckItemWithCompsDownloaded({}),true);eq(#calls,0)
-- P0.25 must reach the SAME captured R12 as direct calls of P0.24.
reset();download["cat:integrated"]=false
local fallback_item={id="integrated"}
eq(a._CheckItemWithCompsDownloaded(fallback_item),false)
eq(a._CheckItemWithCompsDownloaded(fallback_item),false)
eq(#logs,1,"P0.25 reuses P0.24 root log set")
a._CheckPropinfoDownloadWithLog("cat:integrated",91,"integrated")
eq(#logs,1,"direct P0.24 shares P0.25 dedupe key")
b._CheckItemWithCompsDownloaded(fallback_item)
eq(#logs,2,"other product P0.25 gets independent R12")
local original=a._CheckPropinfoDownloadWithLog
local helper_args={}
a._CheckPropinfoDownloadWithLog=function(...)
    local args=table.pack(...);helper_args[#helper_args+1]=args
    calls[#calls+1]="helper:"..tostring(args[1])
    return args[1]~="cat:fail" and true or false
end
reset();eq(a._CheckItemWithCompsDownloaded({id="fail"}),false,"P0.25 no raw fallback")
sequence(calls,{"category:fail","helper:cat:fail"},"P0.25 R3 dynamic helper order")
eq(helper_args[1].n,3);eq(helper_args[1][1],"cat:fail")
eq(helper_args[1][2],"fail");eq(helper_args[1][3],"fail")
-- Traversal queries item before skin, skin before shipping; skin check before item.
local function prop(id,skin_id,components)
    return {id=id,skin_id=skin_id,components=components or {}}
end
local child=prop("child","childskin")
local parent=prop("parent","parentskin",{{prop_data=child}})
reset();helper_args={};shipping=true
local raw=table.pack(a._CheckItemWithCompsDownloaded({rawPropInfo=parent}))
eq(raw.n,1);eq(raw[1],true)
sequence(calls,{"category:parent","skin:parent","category:parentskin","shipping","helper:cat:parentskin","helper:cat:parent",
    "category:child","skin:child","category:childskin","shipping","helper:cat:childskin","helper:cat:child"},"P0.25 shipping full recursion")
eq(helper_args[1][2],"parent");eq(helper_args[1][3],"parentskin")
eq(helper_args[2][3],"parent")
-- Shipping failures continue checking item and nested components, while
-- accumulated false remains false even when a later helper returns true.
reset();helper_args={};parent=prop("parent","fail",{{prop_data=child}})
eq(a._CheckItemWithCompsDownloaded({rawPropInfo=parent}),false)
sequence(calls,{"category:parent","skin:parent","category:fail","shipping","helper:cat:fail","helper:cat:parent",
    "category:child","skin:child","category:childskin","shipping","helper:cat:childskin","helper:cat:child"},"shipping fail still visits components")
reset();shipping=false
local result=table.pack(a._CheckItemWithCompsDownloaded({rawPropInfo=parent}))
eq(result.n,1);eq(result[1],false)
sequence(calls,{"category:parent","skin:parent","category:fail","shipping","helper:cat:fail"},"nonshipping skin fail stops before item/components")
reset();parent=prop("fail","good",{{prop_data=child}})
eq(a._CheckItemWithCompsDownloaded({rawPropInfo=parent}),false)
sequence(calls,{"category:fail","skin:fail","category:good","shipping","helper:cat:good","helper:cat:fail"},"nonshipping item fail stops components")
reset();parent=prop("parent","good",{{prop_data=child}})
eq(a._CheckItemWithCompsDownloaded({rawPropInfo=parent}),true)
eq(#helper_args>0,true)
sequence(calls,{"category:parent","skin:parent","category:good","shipping","helper:cat:good","helper:cat:parent",
    "category:child","skin:child","category:childskin","shipping","helper:cat:childskin","helper:cat:child"},"nonshipping both pass recurse")
-- Non-shipping child failure returns from that child, not from the parent:
-- the parent still processes the next sibling while accumulated state stays false.
reset();parent=prop("parent","good",{{prop_data=prop("fail","good")},{prop_data=child}})
eq(a._CheckItemWithCompsDownloaded({rawPropInfo=parent}),false)
sequence(calls,{"category:parent","skin:parent","category:good","shipping","helper:cat:good","helper:cat:parent",
    "category:fail","skin:fail","category:good","shipping","helper:cat:good","helper:cat:fail",
    "category:child","skin:child","category:childskin","shipping","helper:cat:childskin","helper:cat:child"},
    "nonshipping child failure does not suppress sibling")
-- A nil helper result is preserved, not coerced to false; and false
-- accumulated in shipping mode never becomes true again.
local regular_helper=a._CheckPropinfoDownloadWithLog
a._CheckPropinfoDownloadWithLog=function(...) calls[#calls+1]="nil-helper";return nil end
reset();eq(a._CheckItemWithCompsDownloaded({id="nil-result"}),nil,"P0.25 nil helper result")
shipping=true;reset();eq(a._CheckItemWithCompsDownloaded({rawPropInfo=prop("anything","skin")}),nil,
    "P0.25 shipping nil result remains nil")
shipping=false;a._CheckPropinfoDownloadWithLog=regular_helper
-- No additional guards for false/non-table items (Lua table indexing errors).
local bad_item=pcall(a._CheckItemWithCompsDownloaded,false)
eq(bad_item,false,"P0.25 false item is not nil-gated")
a._CheckPropinfoDownloadWithLog=original
-- nil components is not silently guarded.
local no_components=prop("z","s");no_components.components=nil
download["cat:z"]=true;download["cat:s"]=true
local ok_bad=pcall(a._CheckItemWithCompsDownloaded,{rawPropInfo=no_components})
eq(ok_bad,false,"P0.25 nil components raises via ipairs")

-- P0.28 parent: unique OR (WeaponSkin AND HeroProp), three static calls in
-- order before gate. The child forwards only its FIRST component's result.
reset();unique=false;main_type="other";sub_type="other"
local r=table.pack(a.GetNeedDownloadCategaryKey(nil))
eq(r.n,1);eq(r[1],runtime_key);sequence(calls,{"runtime"},"P0.28 nil item")
reset();local regular={id="ordinary",GetRawPropInfo=function() error("non-special raw read") end}
r=table.pack(a.GetNeedDownloadCategaryKey(regular))
eq(r.n,1);eq(r[1],runtime_key)
sequence(calls,{"main:ordinary","sub:ordinary","unique:ordinary","runtime"},"P0.28 non-special order")
reset();unique=true;local missing={id="missing"};missing.GetRawPropInfo=function(self)
    eq(self,missing,"GetRawPropInfo SELF")
    calls[#calls+1]="raw";return nil,"ignored"
end
r=table.pack(a.GetNeedDownloadCategaryKey(missing))
eq(r.n,1);eq(r[1],"cat:missing")
sequence(calls,{"main:missing","sub:missing","unique:missing","raw","category:missing"},"P0.28 missing raw ordering")
eq(#logs,1);eq(logs[1].n,3)
eq(logs[1][1],"[ DownloadCheck UHE1 ] CheckEquipLogic.GetNeedDownloadCategaryKey(item) 道具缺少propInfo，直接返回道具下载分类key")
eq(logs[1][2],"missing");eq(logs[1][3],"cat:missing")
reset();unique=false;main_type="weapon-skin";sub_type="hero-prop"
local first=prop("one","one-skin");local second=prop("two","two-skin")
local top=prop("top","top-skin",{{prop_data=first},{prop_data=second}})
local special={id="special"};special.GetRawPropInfo=function(self)
    eq(self,special,"P0.28 GetRawPropInfo SELF")
    calls[#calls+1]="raw";return top,"extra"
end
download["cat:top-skin"]=true;download["cat:top"]=true
r=table.pack(a.GetNeedDownloadCategaryKey(special))
eq(r.n,1);eq(r[1],"cat:one-skin","P0.28 first missing skin")
sequence(calls,{"main:special","sub:special","unique:special","raw","category:top","skin:top",
    "category:top-skin","download:cat:top-skin","download:cat:top","category:one","skin:one",
    "category:one-skin","download:cat:one-skin"},"P0.28 first child tailcall; second sibling skipped")
reset();download["cat:one-skin"]=true;download["cat:one"]=false
r=table.pack(a.GetNeedDownloadCategaryKey(special));eq(r.n,1);eq(r[1],"cat:one","P0.28 item missing after skin downloaded")
reset();download["cat:one"]=true
r=table.pack(a.GetNeedDownloadCategaryKey(special));eq(r.n,1);eq(r[1],nil,"P0.28 parent one nil when child tailcall has zero returns")
eq(#calls>0,true)
for _,call in ipairs(calls) do eq(call~="category:two",true,"P0.28 never visits second sibling") end
reset();local empty=prop("empty","empty-skin",{})
local special_empty={id="special",GetRawPropInfo=function() return empty end}
download["cat:empty"]=true;download["cat:empty-skin"]=true
r=table.pack(a.GetNeedDownloadCategaryKey(special_empty));eq(r.n,1);eq(r[1],nil,"P0.28 parent clamps empty walker zero returns")
reset();download["cat:empty-skin"]=false
r=table.pack(a.GetNeedDownloadCategaryKey(special_empty));eq(r[1],"cat:empty-skin","P0.28 skin category priority")
reset();download["cat:empty-skin"]=true;download["cat:empty"]=false
r=table.pack(a.GetNeedDownloadCategaryKey(special_empty));eq(r[1],"cat:empty","P0.28 item category priority")
reset();unique=true;main_type="other";sub_type="other"
r=table.pack(a.GetNeedDownloadCategaryKey(special_empty));eq(r[1],"cat:empty","P0.28 unique gate independent of types")
reset();unique=false;main_type="weapon-skin";sub_type="other"
r=table.pack(a.GetNeedDownloadCategaryKey(regular));eq(r[1],runtime_key,"P0.28 both type conditions needed")
-- Even when both categories are absent, the walker calls ipairs directly.
reset();unique=true
local no_category=prop(nil,nil,{})
local no_category_item={GetRawPropInfo=function() return no_category end}
r=table.pack(a.GetNeedDownloadCategaryKey(no_category_item));eq(r.n,1);eq(r[1],nil)
sequence(calls,{"main:nil","sub:nil","unique:nil","category:nil","skin:nil","category:nil"},
    "P0.28 no categories skips download checks")
no_category.components=nil
local category_error=pcall(a.GetNeedDownloadCategaryKey,no_category_item)
eq(category_error,false,"P0.28 nil components is not guarded")

-- Transactional bridge: all 29 methods roll back after a failed replacement,
-- no saved payload method is retried after source failure, and sets persist per
-- install but reset on a separate installed target.
Bridge.restore_original()
local payload_calls,originals={},{}
local target={}
for _,name in ipairs(Bridge.METHODS) do
    target[name]=function(...) payload_calls[#payload_calls+1]=name; return "payload:"..name end
    originals[name]=target[name]
end
eq(#Bridge.METHODS,29);eq(Bridge.ROOT_METHOD_COUNT,29)
local bridge_context={globals=env,product={},debug_logger=log,info_logger=log,error_logger=log,
    item_helper=helper,item_config_tool={},weapon_assembly_tool={},weapon_helper_tool={},item_base_tool={},
    armed_force_expired_logic={},ammo_data_manager_module={},ammo_data_manager={}}
local ok_install=Bridge.install(target,{context=bridge_context,environment=env,
    set_method=function(t,name,value)
        rawset(t,name,value)
        if name=="GetNeedDownloadCategaryKey" then error("simulated final method install failure") end
    end})
eq(ok_install,false,"bridge final method failure")
for _,name in ipairs(Bridge.METHODS) do eq(target[name],originals[name],"atomic rollback "..name) end
eq(Bridge.status().installed,false)
assert(Bridge.install(target,{context=bridge_context,environment=env}))
eq(Bridge.status().source_owned_root_methods,29)
reset();target._CheckPropinfoDownloadWithLog("x",37,"bridge")
target._CheckPropinfoDownloadWithLog("x",37,"bridge")
eq(#logs,1,"bridge R12 dedupe per install")
reset();download["cat:bridge"]=false
target._CheckItemIdDownloaded("bridge");target._CheckItemIdDownloaded("bridge")
eq(#logs,1,"bridge R13 dedupe per install and R12/R13 independence")
reset();unique=true;main_type="other";sub_type="other"
local bridge_category=table.pack(target.GetNeedDownloadCategaryKey(missing))
eq(bridge_category.n,1);eq(bridge_category[1],"cat:missing")
eq(#logs,1,"bridge P0.28 source logger")
sequence(calls,{"main:missing","sub:missing","unique:missing","raw","category:missing"},
    "bridge P0.28 forwards one item and R4 helper")
reset();part_result=false
target._CheckAllWeaponPartDownloaded();target._CheckAllWeaponPartDownloaded()
eq(#logs,2,"bridge P0.27 no dedupe")
reset();local old_bridge=target._CheckPropinfoDownloadWithLog
target._CheckPropinfoDownloadWithLog=function(...)
    eq(select("#",...),3,"P0.25 bridge dynamic target lookup")
    return "dynamic"
end
eq(target._CheckItemWithCompsDownloaded({id="anything"}),"dynamic")
target._CheckPropinfoDownloadWithLog=old_bridge
local result_error=pcall(target._CheckItemWithCompsDownloaded,{rawPropInfo=no_components})
eq(result_error,false,"bridge propagates source failure")
eq(#payload_calls,0,"bridge never retries original after source throws")
Bridge.restore_original()
for _,name in ipairs(Bridge.METHODS) do eq(target[name],originals[name],"bridge restore "..name) end
local target_b={}
for _,name in ipairs(Bridge.METHODS) do target_b[name]=function() error("original must not run") end end
assert(Bridge.install(target_b,{context=bridge_context,environment=env}))
reset();target_b._CheckPropinfoDownloadWithLog("x",37,"bridge")
eq(#logs,1,"bridge separate root R12 resets")
Bridge.restore_original()
print("product-downloads: ok")

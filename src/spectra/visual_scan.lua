local S = ...
assert(type(S) == "table", "spectra module table required")
local M = {}
S.VisualScan = M

-- Reconstructed from payload prototypes P0.29.78..98. Names are semantic unless
-- they are literal engine/global names present in bytecode.
M.PROTOTYPES = {
    array_each="0.29.78", add_unique="0.29.79", collect_array="0.29.80",
    is_mesh_component="0.29.81", add_unique_mesh="0.29.82", collect_mesh_value="0.29.83",
    collect_character_meshes="0.29.84", is_ai_actor="0.29.85", actor_class_cache="0.29.86",
    collect_character_actors="0.29.87", make_linear_color="0.29.88", make_name="0.29.89",
    set_vector_parameter="0.29.90", load_xray_material="0.29.91", restore_mesh_snapshot="0.29.92",
    apply_xray_mesh="0.29.93", apply_normal_color="0.29.94", restore_mesh_category="0.29.95",
    reset_scan_state="0.29.96", rescan_character_colors="0.29.97", scan_character_batch="0.29.98",
    install_fashion_refresh_hook="0.29.104", fallback_scan_loop="0.29.106", install_tick="0.29.107",
}

M.COLORS = { red={1,0,0,1}, green={0,1,0,1} }
M.XRAY_MATERIAL_PATHS = {
    red="/Game/MaterialLib/Materials/Character/ArmsEffect/MI_XrayOutLine_03_LQ_Red.MI_XrayOutLine_03_LQ_Red",
    green="/Game/MaterialLib/Materials/Character/ArmsEffect/MI_Simple_XrayOutLine_Scout_Green.MI_Simple_XrayOutLine_Scout_Green",
}
M.COLOR_PARAMETERS = {
    "BaseColor","SkinColor","2UDyeColor","DyeColor","Color","TintColor","BaseColorTint","BaseColorAdd",
    "RootColor","TipColor","HighlightColor","MainColor","PrimaryColor","BodyColor","CharacterColor","ColorTint",
    "EmissiveColor","RimColor","FresnelColor","OutlineColor",
}
M.SNAPSHOT_REFRESH_ATTEMPTS = 4
M.MESH_REFRESH_ATTEMPTS = 2
M.XRAY_RETRY_ATTEMPTS = 2
M.NORMAL_RETRY_ATTEMPTS = 4
M.SCAN_BATCH = 8

local COMPONENT_FIELDS = {
    "CharacterFashionComponent","DFMCharacterAppearanceTPP","DFMCharacterAppearanceFPP","CharacterAppearanceTPP",
    "CharacterAppearanceFPP","AppearanceTPP","AppearanceFPP","CharacterEquipComponent","SOLCharacterEquipComponent",
    "CharacterAvatarComponent",
}
local COMPONENT_GETTERS = {
    "GetCharacterFashionComponent","GetCharacterAppearanceTPP","GetCharacterAppearanceFPP","GetAppearanceTPP",
    "GetAppearanceFPP","GetCharacterEquipComponent",
}
local MESH_FIELDS = {
    "Mesh","SkeletalMesh","CharacterMesh","Mesh3P","TPPMesh","ThirdPersonMesh","MainMesh","CharacterSkeletalMesh",
    "MeshComponent","SkeletalMeshComponent","CharacterMeshComponent","StaticMeshComponent","BodyMesh","TargetMesh",
    "DummyMesh","DFMSkeletalMeshComponent","HeadMesh","FaceMesh","HairMesh","HelmetMesh","UpperBodyMesh",
    "LowerBodyMesh","TorsoMesh","LegMesh","HandsMesh","FootMesh","OutfitMesh","FashionMesh","AvatarMesh",
    "SkinMesh","CapeMesh","BackpackMesh","AccessoryMesh","EquipMesh","PreviewCharacterSKM",
}
local MESH_ARRAY_FIELDS = {
    "Meshes","MeshComponents","SkeletalMeshComponents","StaticMeshComponents","AllMeshComponents",
    "CharacterMeshComponents","BodyMeshComponents","AvatarMeshComponents","FashionMeshComponents","SkinMeshComponents",
    "PartMeshComponents","EquipMeshComponents","LoadedMeshComponents","DynamicMeshComponents","MeshComponentMap","MeshMap",
    "PartMeshes","CharacterMeshes","BodyMeshes","FashionMeshes","AvatarMeshes",
}
local MESH_GETTERS = {
    "GetMesh","GetMesh3P","GetThirdPersonMesh","GetCharacterMesh","GetSkeletalMesh","GetCharacterSkeletalMesh",
    "GetMeshComponent","GetSkeletalMeshComponent","GetCharacterMeshComponent","GetStaticMeshComponent","GetBodyMesh",
    "GetTargetMesh","GetHeadMesh","GetFaceMesh","GetHairMesh","GetUpperBodyMesh","GetLowerBodyMesh","GetOutfitMesh",
    "GetFashionMesh","GetAvatarMesh","GetSkinMesh","GetAllMeshComponents","GetMeshComponents",
    "GetCharacterMeshComponents","GetSkeletalMeshComponents","GetFashionMeshComponents","GetAvatarMeshComponents",
}
local MESH_CLASSES = {
    "DFMSkeletalMeshComponent","SkeletalMeshComponent","USkeletalMeshComponent","SkinnedMeshComponent","USkinnedMeshComponent",
    "PoseableMeshComponent","UPoseableMeshComponent","StaticMeshComponent","UStaticMeshComponent","GPCharacterMeshComponent",
    "DFMCharacterMeshComponent","CharacterMeshComponent","MeshComponent","UMeshComponent",
}
local CHILD_FIELDS = {"ChildActor","AttachedActors","Children","ChildActors"}
local ACTOR_CLASSES = {"DFMCharacter","DFMPlayerCharacter","GPCharacter","SOLCharacter","Character","Pawn"}
local AI_NAME_MARKERS = {
    "rangetarget","range_target","targetcharacter","trainingtarget","practice","dummy","dfmaicharacter",
    "dfmcharacter_ai","_ai_","aicharacter","characterai","bot","npc","soldier","minion",
}
local PLAYER_NAME_MARKERS = {"bp_dfmcharacter_c","nc_bp_dfmcharacter_c","dfmplayercharacter","playercharacter"}
local AI_FIELDS = {"bIsAI","IsAI","bAI","bIsBot","IsBot","bIsNPC","IsNPC"}
local AI_METHODS = {"IsAI","IsBot","IsAICharacter","IsNPC"}
local actor_class_cache
local name_cache = {}

local function safe_get(obj,key)
    if obj==nil then return nil end
    local ok,v=pcall(function() return obj[key] end)
    if ok then return v end
end
local function method(obj,name,...)
    local fn=safe_get(obj,name)
    if type(fn)~="function" then return false,nil,nil end
    local ok,a,b=pcall(fn,obj,...)
    if ok then return true,a,b end
    ok,a,b=pcall(fn,...)
    if ok then return true,a,b end
    return false,nil,nil
end
local function is_valid(obj)
    if obj==nil then return false end
    local fn=rawget(_G,"isvalid")
    if type(fn)~="function" then return true end
    local ok,v=pcall(fn,obj)
    return ok and v==true
end
local function object_name(obj)
    if obj==nil then return "" end
    for _,n in ipairs({"GetFullName","GetName"}) do
        local ok,v=method(obj,n)
        if ok and v~=nil then return tostring(v) end
    end
    return tostring(obj)
end
local function import_class(name)
    local direct=rawget(_G,name)
    if direct~=nil then return direct end
    local fn=rawget(_G,"import")
    if type(fn)=="function" then local ok,v=pcall(fn,name); if ok then return v end end
end

function M.array_each(value, callback, limit)
    if value==nil or type(callback)~="function" then return false end
    local any=false
    if type(value)=="table" then
        local count=0
        for _,v in pairs(value) do
            count=count+1; if limit and count>limit then break end
            if v~=nil then any=true; callback(v,count) end
        end
        return any
    end
    local ok,n=method(value,"Num")
    if not ok or type(n)~="number" then
        local h=rawget(_G,"ULuaArrayHelper")
        local fn=safe_get(h,"Num")
        if type(fn)=="function" then
            local a,b=pcall(fn,value); if a then n=b else a,b=pcall(fn,h,value); if a then n=b end end
        end
    end
    if type(n)~="number" or n<=0 then return false end
    local stop=limit and math.min(n,tonumber(limit) or n) or n
    for i=0,stop-1 do
        local gok,v=method(value,"Get",i)
        if gok and v~=nil then any=true; callback(v,i+1) end
    end
    return any
end

function M.add_unique(list,seen,value)
    if value==nil then return end
    local t=type(value); if t~="userdata" and t~="table" then return end
    if seen[value] then return end
    seen[value]=true; list[#list+1]=value
end

function M.is_mesh_component(value)
    if not is_valid(value) then return false end
    local ok=method(value,"GetNumMaterials")
    if not ok then return false end
    local setm=safe_get(value,"SetMaterial"); if type(setm)~="function" then return false end
    return type(safe_get(value,"SetOverlayMaterial"))=="function"
end

function M.collect_mesh_value(list,seen,value)
    if value==nil then return end
    if M.is_mesh_component(value) then M.add_unique(list,seen,value); return end
    M.array_each(value,function(v) if M.is_mesh_component(v) then M.add_unique(list,seen,v) end end,256)
    if type(value)=="table" then
        local count=0
        pcall(function() for _,v in pairs(value) do count=count+1; if count>256 then break end; if M.is_mesh_component(v) then M.add_unique(list,seen,v) end end end)
    end
end

local function enqueue(queue,seen,obj)
    if obj==nil then return end
    local t=type(obj); if t~="table" and t~="userdata" then return end
    if seen[obj] then return end
    seen[obj]=true; queue[#queue+1]=obj
end
local function enqueue_value(queue,seen,value)
    if value==nil then return end
    if M.array_each(value,function(v) enqueue(queue,seen,v) end,64) then return end
    if type(value)=="table" then
        local count=0; pcall(function() for _,v in pairs(value) do count=count+1; if count>64 then break end; enqueue(queue,seen,v) end end)
    else enqueue(queue,seen,value) end
end

function M.collect_character_meshes(actor)
    local meshes,mesh_seen,queue,queue_seen={},{},{},{}
    enqueue(queue,queue_seen,actor)
    for _,field in ipairs(COMPONENT_FIELDS) do enqueue(queue,queue_seen,safe_get(actor,field)) end
    for _,getter in ipairs(COMPONENT_GETTERS) do local ok,v=method(actor,getter); if ok then enqueue(queue,queue_seen,v) end end
    local cursor=1
    while cursor<=#queue and cursor<=32 do
        local obj=queue[cursor]; cursor=cursor+1
        M.add_unique(meshes,mesh_seen,obj)
        for _,field in ipairs(MESH_FIELDS) do M.add_unique(meshes,mesh_seen,safe_get(obj,field)) end
        for _,field in ipairs(MESH_ARRAY_FIELDS) do M.collect_mesh_value(meshes,mesh_seen,safe_get(obj,field)) end
        for _,getter in ipairs(MESH_GETTERS) do local ok,v=method(obj,getter); if ok then M.collect_mesh_value(meshes,mesh_seen,v) end end
        for _,class_name in ipairs(MESH_CLASSES) do
            local cls=import_class(class_name) or class_name
            local ok,v=method(obj,"GetComponentByClass",cls); if ok then M.add_unique(meshes,mesh_seen,v) end
            local ok2,arr=method(obj,"GetComponentsByClass",cls); if ok2 then M.collect_mesh_value(meshes,mesh_seen,arr) end
        end
        local attached={}; local ok,a=method(obj,"GetAttachedActors",attached,true,true); if ok then enqueue_value(queue,queue_seen,a or attached) end
        local children={}; local ok2,c=method(obj,"GetAllChildActors",children,true); if ok2 then enqueue_value(queue,queue_seen,c or children) end
        for _,field in ipairs(CHILD_FIELDS) do enqueue_value(queue,queue_seen,safe_get(obj,field)) end
    end
    local filtered={}; for _,m in ipairs(meshes) do if M.is_mesh_component(m) then filtered[#filtered+1]=m end end
    return filtered
end

function M.is_ai_actor(actor)
    local n=string.lower(object_name(actor))
    for _,m in ipairs(AI_NAME_MARKERS) do if string.find(n,m,1,true) then return true end end
    for _,m in ipairs(PLAYER_NAME_MARKERS) do if string.find(n,m,1,true) then return false end end
    for _,f in ipairs(AI_FIELDS) do if safe_get(actor,f)==true then return true end end
    for _,fn in ipairs(AI_METHODS) do local ok,v=method(actor,fn); if ok and v==true then return true end end
    return false
end

function M.get_actor_classes()
    if actor_class_cache then return actor_class_cache end
    actor_class_cache={}
    for _,name in ipairs(ACTOR_CLASSES) do
        local cls=import_class(name); local vals={}
        local seen={}
        local function add(v) if v~=nil and not seen[v] then seen[v]=true; vals[#vals+1]=v end end
        add(cls)
        if cls~=nil then for _,fn in ipairs({"StaticClass","GetClass"}) do local ok,v=method(cls,fn); if ok then add(v) end end end
        actor_class_cache[#actor_class_cache+1]={name=name,values=vals}
    end
    return actor_class_cache
end

function M.collect_character_actors(local_character, game_flow)
    local out,seen={},{}
    local world
    local gw=rawget(_G,"GetWorld"); if type(gw)=="function" then local ok,v=pcall(gw); if ok then world=v end end
    if world==nil then local ok,v=method(game_flow,"GetWorld"); if ok then world=v end end
    if world==nil then local ok,v=method(local_character,"GetWorld"); if ok then world=v end end
    local gps=import_class("UGameplayStatics")
    if world==nil or gps==nil then return out end
    local function add(actor,class_name)
        if actor==nil or actor==local_character or seen[actor] then return end
        if class_name=="Pawn" then
            local low=string.lower(object_name(actor))
            if not (string.find(low,"character",1,true) or string.find(low,"rangetarget",1,true) or string.find(low,"operator",1,true) or string.find(low,"hero",1,true)) then
                local mesh=safe_get(actor,"Mesh"); if not M.is_mesh_component(mesh) then local ok,v=method(actor,"GetMesh"); if not(ok and M.is_mesh_component(v)) then return end end
            end
        end
        seen[actor]=true; out[#out+1]={object=actor}
    end
    for _,entry in ipairs(M.get_actor_classes()) do
        for _,cls in ipairs(entry.values) do
            local arr={}
            local ok,result=method(gps,"GetAllActorsOfClass",world,cls,arr)
            if ok then M.array_each(result or arr,function(actor) add(actor,entry.name) end) end
        end
    end
    return out
end

function M.make_linear_color(key)
    local v=M.COLORS[key] or M.COLORS.red
    for _,name in ipairs({"FLinearColor","LinearColor","Vector4"}) do
        local fn=rawget(_G,name)
        if type(fn)=="function" then local ok,c=pcall(fn,v[1],v[2],v[3],v[4]); if ok and c~=nil then return c end end
    end
    return {R=v[1],G=v[2],B=v[3],A=v[4]}
end
function M.make_name(value)
    if name_cache[value]~=nil then return name_cache[value] end
    for _,name in ipairs({"FName","Name","MakeLiteralName","StringToName","Conv_StringToName"}) do
        local fn=rawget(_G,name)
        if type(fn)=="function" then local ok,v=pcall(fn,value); if ok and v~=nil then name_cache[value]=v; return v end end
    end
    name_cache[value]=value; return value
end
function M.set_vector_parameter(material,param,color)
    local ok=method(material,"SetVectorParameterValue",param,color); if ok then return true end
    ok=method(material,"SetVectorParameterValue",M.make_name(param),color); return ok
end
function M.load_xray_material(state,key)
    key=key=="green" and "green" or "red"
    state.custom_character_xray_materials=type(state.custom_character_xray_materials)=="table" and state.custom_character_xray_materials or {}
    local cached=state.custom_character_xray_materials[key]; if cached~=nil and is_valid(cached) then return cached end
    local path=M.XRAY_MATERIAL_PATHS[key]
    local slua=rawget(_G,"slua"); local fn=safe_get(slua,"dontCallLoadObject")
    if type(fn)=="function" then
        local ok,v=pcall(fn,path); if not ok then ok,v=pcall(fn,slua,path) end
        if ok and v~=nil then state.custom_character_xray_materials[key]=v; return v end
    end
    for _,name in ipairs({"LoadObject","StaticLoadObject","FindObject","LoadAsset"}) do
        local f=rawget(_G,name); if type(f)=="function" then local ok,v=pcall(f,path); if ok and v~=nil then state.custom_character_xray_materials[key]=v; return v end end
    end
    local imp=rawget(_G,"import"); if type(imp)=="function" then local ok,v=pcall(imp,path); if ok and v~=nil then state.custom_character_xray_materials[key]=v; return v end end
end

function M.restore_mesh_snapshot(mesh,snapshot)
    if mesh==nil or type(snapshot)~="table" then return end
    if type(snapshot.materials)=="table" then for i,m in pairs(snapshot.materials) do method(mesh,"SetMaterial",i,m) end end
    method(mesh,"SetOverlayMaterial",nil); method(mesh,"SetRenderCustomDepth",false); method(mesh,"SetCustomDepthStencilValue",0)
end

function M.apply_xray_mesh(state,mesh,attempt,color_key,category)
    if not is_valid(mesh) or state.custom_character_xray_enabled~=true then return end
    color_key=color_key=="green" and "green" or "red"
    state.custom_character_xray_meshes=state.custom_character_xray_meshes or setmetatable({}, {__mode="k"})
    local snap=state.custom_character_xray_meshes[mesh]
    if type(snap)~="table" then snap={materials={},saved={},last_attempt=-M.XRAY_RETRY_ATTEMPTS}; state.custom_character_xray_meshes[mesh]=snap end
    local mat=M.load_xray_material(state,color_key); if mat==nil then return end
    local a=tonumber(attempt) or 0; local last=tonumber(snap.last_attempt) or 0
    local retry=(a-last)>=M.XRAY_RETRY_ATTEMPTS
    local ok,n=method(mesh,"GetNumMaterials"); n=ok and tonumber(n) or 0; if n<=0 then n=1 end
    local unchanged=snap.color==color_key and snap.material_count==n
    if unchanged and not retry then
        method(mesh,"SetOverlayMaterial",mat); method(mesh,"SetRenderCustomDepth",true); method(mesh,"SetCustomDepthStencilValue",20); snap.category=category; return
    end
    method(mesh,"SetOverlayMaterial",mat); method(mesh,"SetRenderCustomDepth",true); method(mesh,"SetCustomDepthStencilValue",20)
    snap.material_count=n
    for i=0,n-1 do
        if snap.saved[i]~=true then local gok,old=method(mesh,"GetMaterial",i); if gok then snap.saved[i]=true; snap.materials[i]=old end end
        local gok,current=method(mesh,"GetMaterial",i); if gok and current~=mat then method(mesh,"SetMaterial",i,mat) end
    end
    snap.color=color_key; snap.category=category; snap.last_attempt=a
end

function M.apply_normal_color(state,mesh,attempt,color_key)
    if not is_valid(mesh) or state.custom_character_xray_enabled==true then return end
    color_key=color_key=="green" and "green" or "red"
    state.custom_character_normal_seen=state.custom_character_normal_seen or setmetatable({}, {__mode="k"})
    local rec=state.custom_character_normal_seen[mesh] or {}; state.custom_character_normal_seen[mesh]=rec
    local a=tonumber(attempt) or 0; local ok,n=method(mesh,"GetNumMaterials"); n=ok and tonumber(n) or 0
    local last=tonumber(rec.last_attempt); if last==nil then last=-M.NORMAL_RETRY_ATTEMPTS end
    if rec.key==color_key and rec.material_count==n and (a-last)<M.NORMAL_RETRY_ATTEMPTS then return end
    rec.key=color_key; rec.last_attempt=a; rec.material_count=n
    for i=0,n-1 do
        local made=method(mesh,"CreateAndSetMaterialInstanceDynamic",i)
        if not made then method(mesh,"CreateDynamicMaterialInstance",i) end
    end
    local c=M.make_linear_color(color_key)
    if type(safe_get(mesh,"SetVectorParameterValueOnMaterials"))=="function" then
        for _,p in ipairs(M.COLOR_PARAMETERS) do method(mesh,"SetVectorParameterValueOnMaterials",M.make_name(p),c) end
    end
    for i=0,n-1 do local gok,mat=method(mesh,"GetMaterial",i); if gok and mat~=nil then for _,p in ipairs(M.COLOR_PARAMETERS) do M.set_vector_parameter(mat,p,c) end end end
    method(mesh,"SetOverlayMaterial",nil); method(mesh,"SetRenderCustomDepth",false); method(mesh,"SetCustomDepthStencilValue",0)
end

function M.restore_mesh_category(state,category)
    local meshes=state.custom_character_xray_meshes or {}
    for mesh,snap in pairs(meshes) do if type(snap)=="table" and snap.category==category then M.restore_mesh_snapshot(mesh,snap); meshes[mesh]=nil end end
end
function M.reset_scan_state(state)
    state.custom_character_scan_actor_snapshot=nil; state.custom_character_scan_actor_cursor=1
    state.custom_character_scan_actor_snapshot_attempt=-1; state.custom_character_scan_actor_snapshot_character=nil
end

function M.scan_character_batch(state,attempt)
    attempt=tonumber(attempt) or 0
    local facade=rawget(_G,"Facade"); local gfm=safe_get(facade,"GameFlowManager")
    local ok,character=method(gfm,"GetCharacter"); if not ok or character==nil then return end
    local list=state.custom_character_scan_actor_snapshot; local cursor=tonumber(state.custom_character_scan_actor_cursor) or 1
    local snap_attempt=tonumber(state.custom_character_scan_actor_snapshot_attempt) or -1
    local snap_character=state.custom_character_scan_actor_snapshot_character
    local count=type(list)=="table" and #list or 0
    if type(list)~="table" or snap_character~=character or count<cursor or (attempt-snap_attempt)>=M.SNAPSHOT_REFRESH_ATTEMPTS then
        list=M.collect_character_actors(character,gfm); cursor=1; snap_attempt=attempt
        state.custom_character_scan_actor_snapshot=list; state.custom_character_scan_actor_snapshot_attempt=attempt
        state.custom_character_scan_actor_snapshot_character=character
    end
    local stop=math.min(#list,cursor+M.SCAN_BATCH-1)
    for i=cursor,stop do
        local entry=list[i]; local actor=type(entry)=="table" and entry.object or nil
        if is_valid(actor) then
            if entry.is_local_proxy==nil then entry.is_local_proxy=string.find(string.lower(object_name(actor)),"selfproxy",1,true)~=nil end
            if not entry.is_local_proxy then
                if entry.is_ai==nil then entry.is_ai=M.is_ai_actor(actor) end
                if not (entry.is_ai and state.custom_ai_color_enabled~=true) then
                    local category=entry.is_ai and "ai" or "real"
                    local key=entry.is_ai and state.custom_ai_color_key or state.custom_real_color_key
                    key=key=="green" and "green" or "red"
                    local mr=tonumber(entry.mesh_refresh_attempt) or -1
                    if type(entry.meshes)~="table" or (attempt-mr)>=M.MESH_REFRESH_ATTEMPTS then entry.meshes=M.collect_character_meshes(actor); entry.mesh_refresh_attempt=attempt end
                    for _,mesh in ipairs(entry.meshes or {}) do
                        if state.custom_character_xray_enabled==true then M.apply_xray_mesh(state,mesh,attempt,key,category)
                        else M.apply_normal_color(state,mesh,attempt,key) end
                    end
                end
            end
        end
    end
    state.custom_character_scan_actor_cursor=stop+1
end

function M.rescan_character_colors(state,delay)
    state.custom_character_color_rescan_revision=(tonumber(state.custom_character_color_rescan_revision) or 0)+1
    local revision=state.custom_character_color_rescan_revision
    state.custom_character_normal_seen=setmetatable({}, {__mode="k"}); M.reset_scan_state(state)
    for _,seconds in ipairs({0.0,0.08,0.24,0.6,1.2}) do
        delay(seconds,function()
            if revision~=state.custom_character_color_rescan_revision then return end
            state.custom_character_scan_actor_snapshot=nil; state.custom_character_scan_actor_cursor=1
            pcall(M.scan_character_batch,state,state.custom_character_color_attempt or 0)
        end)
    end
end


function M.install_fashion_refresh_hook(state, delay)
    local old=state.custom_character_fashion_refresh_hook
    if type(old)=="table" and old.delegate~=nil and old.callback~=nil then
        method(old.delegate,"Remove",old.callback,old.owner)
        method(old.delegate,"Remove",old.callback)
    end
    local cls=import_class("DFMCharacterItemFashionManager")
    local instance
    if cls~=nil then local ok,v=method(cls,"Get"); if ok then instance=v end end
    if instance==nil then return false end
    local delegate=safe_get(instance,"OnSetMatTaskComplete")
    if delegate==nil then return false end
    local owner={}
    owner.OnRefresh=function() M.rescan_character_colors(state,delay) end
    local ok,handle=method(delegate,"Add",owner.OnRefresh,owner)
    if not ok then ok,handle=method(delegate,"Add",owner.OnRefresh) end
    if not ok then return false end
    state.custom_character_fashion_refresh_hook={delegate=delegate,callback=owner.OnRefresh,owner=owner,handle=handle}
    return true
end

function M.fallback_scan_loop(state, delay, attempt)
    attempt=tonumber(attempt) or 0
    if attempt>=10 then
        M.reset_scan_state(state)
        attempt=0
    end
    state.custom_character_color_attempt=attempt
    pcall(M.scan_character_batch,state,attempt)
    delay(0.25,function()
        local next_attempt = attempt>=600 and 0 or attempt+1
        M.fallback_scan_loop(state,delay,next_attempt)
    end)
end

function M.install_tick(state)
    local controller_class=rawget(_G,"LuaTickController")
    local ok,controller=method(controller_class,"Get")
    if not ok or controller==nil then return false end
    local old=rawget(_G,"__AUTHOR_XRAY_UI_TICK")
    if old~=nil then method(controller,"UnregisterTick",old) end
    local callback=function(delta)
        local elapsed=state.custom_character_xray_tick_elapsed or 0
        elapsed=elapsed+(tonumber(delta) or 0.016)
        state.custom_character_xray_tick_elapsed=elapsed
        if elapsed<0.25 then return end
        state.custom_character_xray_tick_elapsed=0
        local attempt=(state.custom_character_color_attempt or 0)+1
        state.custom_character_color_attempt=attempt
        pcall(M.scan_character_batch,state,attempt)
    end
    rawset(_G,"__AUTHOR_XRAY_UI_TICK",callback)
    local registered=method(controller,"RegisterTick",callback)
    return registered==true
end

function M.get_catalog() return {prototypes=M.PROTOTYPES} end
return M

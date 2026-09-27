local root=assert(arg[1])
local S={}
assert(loadfile(root.."/src/spectra/product_context.lua"))(S)
assert(loadfile(root.."/src/spectra/product_module.lua"))(S)
assert(loadfile(root.."/src/spectra/product_constructor.lua"))(S)
local Context=S.ProductContext
local Constructor=S.ProductConstructor
local table_factory=Constructor.new_product_table
local product_tables_created=0
Constructor.new_product_table=function()
    product_tables_created=product_tables_created+1
    return table_factory()
end
local function eq(a,b,m) if a~=b then error((m or "value")..": expected "..tostring(b)..", got "..tostring(a),2) end end
local function truth(v,m) if not v then error(m or "expected truthy",2) end end

local calls={}
local debug_logger=function() end
local info_logger=function() end
local error_logger=function() end
local modules={}
for i,path in ipairs(Context.REQUIRE_PATHS) do
    modules[path]={name="module-"..i}
end
modules[Context.REQUIRE_PATHS[1]].GetSubTypeById=function() end
local ammo={kind="ammo-singleton"}
local ammo_module={Get=function(...)
    eq(select("#",...),0,"AmmoDataManager.Get static call arity")
    calls[#calls+1]="ammo-get"
    return ammo
end}
local globals={
    ELuaLogCategory={LuaMArmedForce="armed-force-category"},
    GenLocalLogFunc=function(category)
        eq(category,"armed-force-category","logger category")
        calls[#calls+1]="loggers"
        return debug_logger,info_logger,error_logger
    end,
    require=function(path)
        calls[#calls+1]="require:"..path
        return assert(modules[path],"unexpected require: "..tostring(path))
    end,
    import=function(name)
        eq(name,"AmmoDataManager","import name")
        calls[#calls+1]="import:"..name
        return ammo_module
    end,
}

local context=Context.create(globals)
eq(context.globals,globals)
eq(context.debug_logger,debug_logger,"R0 debug logger")
eq(context.info_logger,info_logger,"R1 info logger")
eq(context.error_logger,error_logger,"R2 error logger")
truth(type(context.product)=="table","R3 product table")
eq(product_tables_created,1,"R3 allocated by source ProductConstructor")
truth(context.product~=ammo,"R3 is not AmmoDataManager.Get() result")
eq(context.item_helper,modules[Context.REQUIRE_PATHS[1]],"R4 ItemHelperTool")
eq(context.item_config_tool,modules[Context.REQUIRE_PATHS[2]],"R5 ItemConfigTool")
eq(context.weapon_assembly_tool,modules[Context.REQUIRE_PATHS[3]],"R6 WeaponAssemblyTool")
eq(context.weapon_helper_tool,modules[Context.REQUIRE_PATHS[4]],"R7 WeaponHelperTool")
eq(context.item_base_tool,modules[Context.REQUIRE_PATHS[5]],"R8 ItemBaseTool")
eq(context.armed_force_expired_logic,modules[Context.REQUIRE_PATHS[6]],"R9 ArmedForceExpiredLogic")
eq(context.ammo_data_manager_module,ammo_module,"R10 import result")
eq(context.ammo_data_manager,ammo,"R11 AmmoDataManager.Get result")
truth(Context.validate(context),"context validates")

local expected={"loggers"}
for _,path in ipairs(Context.REQUIRE_PATHS) do expected[#expected+1]="require:"..path end
expected[#expected+1]="import:AmmoDataManager"
expected[#expected+1]="ammo-get"
eq(table.concat(calls,"\n"),table.concat(expected,"\n"),"root context call order")
print("product-context: ok")

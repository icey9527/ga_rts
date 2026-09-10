-- 机体类型行为统一入口：只认 battle/unit/types/<type>.lua，不再回退旧模块。
-- 新文件存在但加载失败或接口不合法时直接抛错，避免静默退回旧行为。
local Loader = {}
local cache = {}

local function exists(name)
    if package.preload[name] or package.loaded[name] then return true end
    local path=name:gsub("%.","/")..".lua"
    return love.filesystem.getInfo(path)~=nil
end

function Loader.load(unit_type)
    if type(unit_type) ~= "string" or unit_type == "" then return nil end
    if cache[unit_type] ~= nil then return cache[unit_type] or nil end
    assert(unit_type:match("^[%w_]+$"),"Invalid unit type: "..unit_type)
    local name="battle.unit.types."..unit_type
    if not exists(name) then cache[unit_type]=false;return nil end
    local ok,behavior=xpcall(function() return require(name) end,debug.traceback)
    if not ok then error("Unit behavior failed to load: "..name.."\n"..tostring(behavior),0) end
    assert(type(behavior)=="table" and type(behavior.update)=="function","Invalid unit behavior (update required): "..name)
    if behavior.fly~=nil then assert(type(behavior.fly)=="function","Invalid fly handler: "..name) end
    cache[unit_type]=behavior
    return behavior
end

return Loader

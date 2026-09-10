-- 机体类型行为统一入口。
-- 迁移期间保留旧 units/<type>/logic.lua 的实现，调用方不再直接拼接 require 路径。
local Loader = {}
local cache = {}

function Loader.load(unit_type)
    if type(unit_type) ~= "string" or unit_type == "" then return nil end
    if cache[unit_type] ~= nil then return cache[unit_type] or nil end
    local path = "units." .. unit_type .. ".logic"
    local ok, behavior = pcall(require, path)
    if ok and type(behavior) == "table" then
        cache[unit_type] = behavior
        return behavior
    end
    cache[unit_type] = false
    return nil
end

return Loader

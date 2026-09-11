-- 出击编队：player/enemy 两侧各自记忆——同一队伍被敌我双方同时选用时
-- 上阵名单互不共享。存档 saves/loadout.tbl：
--   [player.队伍ID] / [enemy.队伍ID]
--   members = {编号, 编号}     —— 只列上阵者，机型不在此记录（走角色配置）
-- 默认补齐按角色编号升序（编号靠前的优先上阵）。上限 config/gameplay.deploy_limit。
local Loadout = {}
local LIMIT = require("config.gameplay").deploy_limit or 7

local cache

-- 花名册（不含指挥官），按编号升序返回。
local function roster_ids(team_id)
    local ids = {}
    local cfg = require("systems.pack_registry").load(team_id).team or {}
    local commander = tonumber(cfg.commander)
    for _, cid in ipairs(cfg.chara or {}) do
        cid = tonumber(cid)
        if cid and cid ~= commander then ids[#ids + 1] = cid end
    end
    table.sort(ids)
    return ids
end

local function load_file()
    if cache then return cache end
    cache = {}
    local data = require("core.tbl").parse_file("saves/loadout.tbl")
    for key, section in pairs(data or {}) do
        if type(section) == "table" and type(section.members) == "table" then
            local entries = {}
            for _, v in ipairs(section.members) do
                local id = tonumber(v)
                if id then entries[#entries + 1] = { id = id } end
            end
            cache[key] = entries
        end
    end
    return cache
end

local function key_for(side, team_id)
    return tostring(side) .. "." .. tostring(team_id)
end

-- 返回该侧该队按顺序的上阵名单 { {id=} }：
-- 存档过滤已离队角色，不足上限按编号升序补齐。
function Loadout.for_side(side, team_id)
    if not team_id or team_id == "random" or team_id == "default" then return {} end
    local roster = roster_ids(team_id)
    local in_roster = {}
    for _, id in ipairs(roster) do in_roster[id] = true end
    local picked, seen = {}, {}
    for _, entry in ipairs(load_file()[key_for(side, team_id)] or {}) do
        if in_roster[entry.id] and not seen[entry.id] and #picked < LIMIT then
            seen[entry.id] = true
            picked[#picked + 1] = entry
        end
    end
    for _, id in ipairs(roster) do
        if #picked >= LIMIT then break end
        if not seen[id] then
            seen[id] = true
            picked[#picked + 1] = { id = id }
        end
    end
    return picked
end

-- 保存该侧整队名单（立即写盘）。ids 为编号列表。
function Loadout.set_side(side, team_id, ids)
    if not team_id or team_id == "random" or team_id == "default" then return false end
    local entries = {}
    for _, id in ipairs(ids or {}) do
        id = tonumber(id)
        if id then entries[#entries + 1] = { id = id } end
    end
    load_file()[key_for(side, team_id)] = entries
    local lines = { "# 出击编队存档：[player.队伍]/[enemy.队伍]，members 只列上阵编号" }
    for key, list in pairs(cache) do
        local vals = {}
        for _, e in ipairs(list) do vals[#vals + 1] = tostring(e.id) end
        lines[#lines + 1] = "[" .. key .. "]"
        lines[#lines + 1] = "members = {" .. table.concat(vals, ", ") .. "}"
    end
    love.filesystem.createDirectory("saves")
    return love.filesystem.write("saves/loadout.tbl", table.concat(lines, "\n") .. "\n")
end

function Loadout.limit() return LIMIT end

return Loadout

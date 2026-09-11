-- 出击编队：每队最多 deploy_limit 名作战成员（指挥官母舰不占名额），
-- 未上阵的同阵营角色构成增援池。编队存档 saves/loadout.tbl，键为 team_id。
-- 条目格式 "角色ID:机型"，机型可省略（部署时按角色配置/默认序列决定）。
local Loadout = {}
local LIMIT = require("config.gameplay").deploy_limit or 7

local cache

local function roster_ids(team_id)
    local ids = {}
    local cfg = require("systems.pack_registry").load(team_id).team or {}
    local commander = tonumber(cfg.commander)
    for _, cid in ipairs(cfg.chara or {}) do
        cid = tonumber(cid)
        if cid and cid ~= commander then ids[#ids + 1] = cid end
    end
    return ids
end

local function load_file()
    if cache then return cache end
    cache = {}
    local data = require("core.tbl").parse_file("saves/loadout.tbl")
    for team_id, section in pairs(data or {}) do
        if type(section) == "table" then
            local entries = {}
            for _, entry in ipairs(type(section.members) == "table" and section.members or {}) do
                local id, ship = tostring(entry):match("^(%d+):(%w+)$")
                if not id then id = tostring(entry):match("^(%d+)$") end
                if id then entries[#entries + 1] = { id = tonumber(id), ship = ship } end
            end
            cache[team_id] = entries
        end
    end
    return cache
end

-- 返回该队按顺序的上阵名单 { {id=, ship=} }：
-- 存档名单过滤掉已不在队伍的角色，不足上限时按队伍花名册顺序补齐。
function Loadout.for_team(team_id)
    if not team_id or team_id == "random" or team_id == "default" then return {} end
    local roster = roster_ids(team_id)
    local in_roster = {}
    for _, id in ipairs(roster) do in_roster[id] = true end
    local picked, seen = {}, {}
    for _, entry in ipairs(load_file()[team_id] or {}) do
        if in_roster[entry.id] and not seen[entry.id] and #picked < LIMIT then
            seen[entry.id] = true
            picked[#picked + 1] = { id = entry.id, ship = entry.ship }
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

-- 保存整队名单（立即写盘）。entries 为 { {id=, ship=} } 或 id 列表。
function Loadout.set_team(team_id, entries)
    if not team_id or team_id == "random" or team_id == "default" then return false end
    load_file()[team_id] = entries or {}
    local lines = { "# 出击编队存档：每行 \"角色ID:机型\"，机型可省略" }
    for tid, list in pairs(cache) do
        local vals = {}
        for _, e in ipairs(list) do
            vals[#vals + 1] = e.ship and (e.id .. ":" .. e.ship) or tostring(e.id)
        end
        lines[#lines + 1] = "[" .. tid .. "]"
        lines[#lines + 1] = "members = {" .. table.concat(vals, ", ") .. "}"
    end
    love.filesystem.createDirectory("saves")
    return love.filesystem.write("saves/loadout.tbl", table.concat(lines, "\n") .. "\n")
end

function Loadout.limit() return LIMIT end

return Loadout

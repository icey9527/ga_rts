local TBL=require("core.tbl")
local R={cache={},active=nil}
local DEFAULT_TEAM="default"
local function read(path) return TBL.parse_file(path) or {} end
function R.load(id)
  id=id or R.default_player(); local hit=R.cache[id]; if hit then R.active=hit; return hit end
  local root="teams/"..id; local t=read(root.."/team.tbl")
  if not t.team then return {} end  -- team.tbl 不存在：不缓存，免得错误队名占住别名
  t.id=t.team.id or id; t.root=root; t.dir=id
  R.cache[id]=t
  if t.id~=id then R.cache[t.id]=t end  -- team.tbl 的 id 与目录名不一致（如含空格）时，按 id 也能取到同一包
  R.active=t; return t
end
-- 把队名规范化为磁盘目录名：team.tbl 的 id 与目录名不一致时，文件路径必须按目录名拼。
function R.dir(id)
  local t=R.load(id)
  return t.dir or tostring(id)
end
function R.list()
  local out={}
  for _,id in ipairs(love.filesystem.getDirectoryItems("teams")) do
    if love.filesystem.getInfo("teams/"..id.."/team.tbl") then out[#out+1]=R.load(id) end
  end
  if #out==0 then for _,id in ipairs({"rune","moon",DEFAULT_TEAM}) do
    if love.filesystem.getInfo("teams/"..id.."/team.tbl") then out[#out+1]=R.load(id) end
  end end
  return out
end
function R.ids()
  local ids={}
  for _,t in ipairs(R.list()) do ids[#ids+1]=t.id end
  return ids
end
-- 实战可选队伍：排除混池 default 与"随机"虚拟选项；任何队伍均可作我方或敌方。
function R.playable_ids()
  local out={}
  for _,id in ipairs(R.ids()) do
    if id~=DEFAULT_TEAM and id~="random" then out[#out+1]=id end
  end
  return out
end
-- 兜底：仅当 teams 目录扫描不到实战队伍时生效；本文件是全项目唯一允许出现队名字面量的地方。
local FALLBACK_PLAYER,FALLBACK_ENEMY="rune","moon"
function R.default_player() local ids=R.playable_ids(); return ids[1] or FALLBACK_PLAYER end
function R.default_enemy() local ids=R.playable_ids(); return ids[2] or ids[1] or FALLBACK_ENEMY end
function R.team(pack,team) if team then return R.load(team) end; return type(pack)=="table" and pack or R.load(pack) end
local function pad(id) if type(id)=="number" then return string.format("%03d",id) end return tostring(id) end
function R.character(pack,team,id) local t=R.team(pack,team); local path=t and t.root.."/chara/"..pad(id).."/chara.tbl"; return path and love.filesystem.getInfo(path) and read(path).chara end
function R.asset(pack,team,id,name) local c=R.character(pack,team,id); local t=R.team(pack,team); return c and c[name] and t.root.."/chara/"..pad(id).."/"..c[name] end
function R.bgm(pack,team,state) local t=R.team(pack,team); return t and t.team and (t.team[state.."_bgm"] or t.team.bgm or t.team["曲"]) end
return R

local TBL=require("core.tbl")
local R={cache={},active=nil}
local DEFAULT_TEAM="default"
local function read(path) return TBL.parse_file(path) or {} end
function R.load(id)
  id=id or "moon"; if R.cache[id] then R.active=R.cache[id]; return R.active end
  local root="teams/"..id; local t=read(root.."/team.tbl"); t.id=t.team and t.team.id or id; t.root=root
  R.cache[id]=t; R.active=t; return t
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
function R.team(pack,team) if team then return R.load(team) end; return type(pack)=="table" and pack or R.load(pack) end
local function pad(id) if type(id)=="number" then return string.format("%03d",id) end return tostring(id) end
function R.character(pack,team,id) local t=R.team(pack,team); local path=t and t.root.."/chara/"..pad(id).."/chara.tbl"; return path and love.filesystem.getInfo(path) and read(path).chara end
function R.asset(pack,team,id,name) local c=R.character(pack,team,id); local t=R.team(pack,team); return c and c[name] and t.root.."/chara/"..pad(id).."/"..c[name] end
function R.bgm(pack,team,state) local t=R.team(pack,team); return t and t.team and (t.team[state.."_bgm"] or t.team.bgm or t.team["曲"]) end
return R

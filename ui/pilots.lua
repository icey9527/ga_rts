local Pilots = {}
local TBL=require("core.tbl")
local images={}
local chara_cache={}
local dialogue_cache={}

local DEFAULT_TEAM="default"
local FACE_WANTED=({hit="0008",lost="0008",failed="0008",attack="0001",skill="0001",idle="0002",praise="0002"})

local function team_id(unit)
    if unit and unit.team_id then return unit.team_id end
    if unit and unit.game and unit.game.player_team_id then return unit.game.player_team_id end
    if unit and unit.game and unit.game.team_id then return unit.game.team_id end
    return DEFAULT_TEAM
end

-- teams/<队>/chara/<编号>/chara.tbl 解析（带缓存）。
local function chara_info(team,id)
    team=tostring(team)
    if type(id)=="number" then id=string.format("%03d",id) end
    id=tostring(id)
    local key=team..":"..id
    if chara_cache[key]~=nil then return chara_cache[key] end
    local root="teams/"..team.."/chara/"..id
    local info=false
    local parsed=TBL.parse_file(root.."/chara.tbl")
    if parsed and parsed.chara then
        local face_dir=root.."/"..(parsed.chara.face or "face")
        local faces={}
        for _,f in ipairs(love.filesystem.getDirectoryItems(face_dir)) do
            if f:sub(-4)==".png" then faces[#faces+1]=f end
        end
        table.sort(faces)
        info={root=root,cfg=parsed.chara,name=parsed.chara.name or "",faces=faces,face_dir=face_dir}
    end
    chara_cache[key]=info
    return info
end
Pilots.info=chara_info

function Pilots.image(path)
    if images[path]==nil then
        local ok,img=pcall(love.graphics.newImage,path)
        images[path]=ok and img or false
    end
    return images[path]
end

-- 汇总若干队伍的角色编号；用于随机分配池。
function Pilots.team_pool(team_ids)
    local ids={}
    local seen={}
    for _,team in ipairs(team_ids) do
        local root="teams/"..tostring(team).."/chara"
        for _,dir in ipairs(love.filesystem.getDirectoryItems(root)) do
            local id=tonumber(dir)
            if id and not seen[id] and chara_info(team,dir) then
                seen[id]=true
                ids[#ids+1]=id
            end
        end
    end
    table.sort(ids)
    return ids
end

function Pilots.available()
    if not Pilots._available then
        local list={}
        local ok,registry=pcall(require,"systems.pack_registry")
        local teams=ok and registry.ids() or nil
        teams=teams and #teams>0 and teams or {"rune","moon",DEFAULT_TEAM}
        for _,id in ipairs(Pilots.team_pool(teams)) do list[id]=true end
        Pilots._available=list
    end
    return Pilots._available
end

-- 随机分配：从本单位所属队伍与混池中选人，同一地图内已上场角色不重复。
function Pilots.assign(unit)
    if unit.character_id~=nil and chara_info(team_id(unit),unit.character_id) then return end
    local g=unit.game
    local pool=Pilots.team_pool({team_id(unit),DEFAULT_TEAM})
    local used={}
    if g then
        for _,other in ipairs(g.units) do
            if other~=unit and other.alive and other.character_id then used[other.character_id]=true end
        end
    end
    local candidates={}
    for _,id in ipairs(pool) do
        if not used[id] then candidates[#candidates+1]=id end
    end
    if #candidates==0 then candidates=pool end
    assert(#candidates>0,"No character directory available for assignment")
    unit.character_id=candidates[((unit.id or 1)-1)%#candidates+1]
end

function Pilots.profile(unit)
    local team=team_id(unit)
    local id=unit.character_id or 0
    local info=chara_info(team,id) or chara_info(DEFAULT_TEAM,id)
    return {name=(info and info.name) or tostring(id),face=id,team=info and team or nil}
end

local function face_img_path(unit,kind)
    local info=chara_info(team_id(unit),unit.character_id) or chara_info(DEFAULT_TEAM,unit.character_id)
    if not info or #info.faces==0 then return nil end
    local wanted=FACE_WANTED[kind or ""] or "0000"
    for _,f in ipairs(info.faces) do
        if f:find("_"..wanted,1,true) then return info.face_dir.."/"..f end
    end
    return info.face_dir.."/"..info.faces[1]
end

function Pilots.draw(unit,x,y,size,kind,shape)
    local path=face_img_path(unit,kind)
    local img=path and Pilots.image(path)
    if img then
        love.graphics.push("all")
        local alpha=select(4,love.graphics.getColor())
        local g=love.graphics
        local circular=shape=="circle"
        if shape~="bare" then
        local enemy = unit.game and unit.team ~= unit.game.player_team
        if circular then g.setColor(enemy and 0.92 or 0.94,enemy and 0.28 or 0.75,enemy and 0.24 or 0.2,alpha)
        elseif enemy then g.setColor(0.92,0.28,0.24,alpha) else g.setColor(0.95,0.97,0.98,alpha) end
        if circular then g.circle("fill",x+size/2,y+size/2,size/2+2) else g.rectangle("fill",x-2,y-2,size+4,size+4,8,8) end
        love.graphics.setColor(0.12,0.17,0.2,alpha)
        love.graphics.setLineWidth(1)
        if circular then
            g.setColor(enemy and 0.92 or 0.94,enemy and 0.28 or 0.75,enemy and 0.24 or 0.2,alpha)
            g.circle("line",x+size/2,y+size/2,size/2+2)
        else
            if enemy then g.setColor(0.92,0.28,0.24,alpha) end
            g.rectangle("line",x-2,y-2,size+4,size+4,8,8)
        end
        end
        g.stencil(function()
            if circular then g.circle("fill",x+size/2,y+size/2,size/2) else g.rectangle("fill",x,y,size,size,6,6) end
        end,"replace",1)
        g.setStencilTest("equal",1)
        love.graphics.setColor(1,1,1,alpha)
        love.graphics.draw(img,x,y,0,size/img:getWidth(),size/img:getHeight())
        g.setStencilTest()
        if unit.game and unit.team==unit.game.player_team and unit.sp and unit.sp>=unit.max_sp then
            local pulse=0.45+0.35*math.sin(unit.game.level_time*4)
            g.setColor(1,0.85,0.3,pulse);g.setLineWidth(2)
            if circular then g.circle("line",x+size/2,y+size/2,size/2+2) else g.rectangle("line",x-2,y-2,size+4,size+4,8,8) end
        end
        g.pop()
    end
end

function Pilots.standing(unit)
    local info=chara_info(team_id(unit),unit.character_id) or chara_info(DEFAULT_TEAM,unit.character_id)
    if not info then return nil end
    local path=info.root.."/chara.png"
    if love.filesystem.getInfo(path) then return Pilots.image(path) end
    return nil
end

-- 队伍对白解析：兼容字符串列表与 {text="",face=""} 对象列表。
local function load_team_dialogue(team,id)
    if type(id)=="number" then id=string.format("%03d",id) end
    local key=tostring(team)..":"..id
    if dialogue_cache[key]~=nil then return dialogue_cache[key] end
    local path="teams/"..tostring(team).."/chara/"..id.."/dialogue.lua"
    local parsed=false
    if love.filesystem.getInfo(path) then
        local source=love.filesystem.read(path)
        local chunk=source and loadstring(source)
        local ok,data=pcall(chunk and chunk or function() return nil end)
        if ok and type(data)=="table" then parsed=data end
    end
    dialogue_cache[key]=parsed
    return parsed
end

local function normalize(entry)
    if type(entry)=="string" then return {text=entry,face=""} end
    if type(entry)=="table" then return {text=entry.text or "",face=entry.face or ""} end
    return nil
end

function Pilots.line(unit,kind,fallback)
    local team=team_id(unit)
    local dialogue=load_team_dialogue(team,unit.character_id)
    local side=(unit.game and unit.team~=unit.game.player_team) and "enemy" or "friendly"
    if kind=="ready" or kind=="interaction" or kind=="follow" or kind=="follow_reply" then
        if side=="enemy" then return nil end
        local personal=dialogue and dialogue.friendly and dialogue.friendly[kind]
        if personal and #personal>0 then
            unit.dialogue_index=unit.dialogue_index or {}
            local i=(unit.dialogue_index[kind] or 0)+1;unit.dialogue_index[kind]=i
            local entry=normalize(personal[(i-1)%#personal+1])
            return entry and entry.text~="" and entry.text or nil
        end
        return ({ready="特殊装备已就绪，等待指令。",interaction="航向又变了吗？请留一点时间完成机动。",follow="已经跟上。这段航路一起走吧。",follow_reply="收到，我会留出安全间距。"})[kind]
    end
    local list=dialogue and dialogue[side] and dialogue[side][kind]
    if not list and side=="friendly" and love.filesystem.getInfo("units/"..unit.unit_type.."/dialogue.lua") then
        list=require("units."..unit.unit_type..".dialogue")[kind]
    end
    if side=="enemy" and not list then return nil end
    if not list then
        local defaults={command="指令确认，正在执行。",attack="目标确认，开始攻击。",hit="机体受损，请求支援。",lost="通讯中断……",failed="目标无效，请重新指定。",skill="特殊装备启动。",idle="正在监视周边空域。",praise="目标已击破，保持警戒。"}
        return defaults[kind] or fallback
    end
    unit.dialogue_index=unit.dialogue_index or {}
    unit.dialogue_index[kind]=(unit.dialogue_index[kind] or 0)+1
    local entry=normalize(list[(unit.dialogue_index[kind]-1+(unit.id or 0))%#list+1])
    return entry and entry.text or fallback, entry and entry.face or ""
end
return Pilots

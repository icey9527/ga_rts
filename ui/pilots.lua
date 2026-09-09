local Pilots = {}
local TBL=require("core.tbl")
local Registry=require("systems.pack_registry")
local images={}
local chara_cache={}
local dialogue_cache={}

local DEFAULT_TEAM="default"
local FACE_WANTED=({hit="0008",lost="0008",failed="0008",attack="0001",skill="0001",idle="0002",praise="0002"})
local FACE_GROUP=({hit="hit",lost="hit",failed="hit",attack="attack",skill="attack",idle="idle",praise="idle"})

local function team_id(unit)
    if unit and unit.team_id then return unit.team_id end
    if unit and unit.game and unit.game.player_team_id then return unit.game.player_team_id end
    if unit and unit.game and unit.game.team_id then return unit.game.team_id end
    return DEFAULT_TEAM
end

-- teams/<队>/chara/<编号>/chara.tbl 解析（带缓存）。
local function chara_info(team,id,skin_override)
    team=Registry.dir(tostring(team))
    if type(id)=="number" then id=string.format("%03d",id) end
    id=tostring(id)
    -- 皮肤：preferences 的 skin_<队伍> 指向 teams/<队伍>/skins/<名字>/，仅覆盖头像/立绘，
    -- 台词与角色数据仍读本体；缓存键含皮肤名，切换即时生效。
    local skin
    local ok,pref=pcall(require,"systems.preferences")
    if ok and team~="default" then
        local scope="player"
        if unit and unit.game and unit.team~=unit.game.player_team then scope="enemy" end
        local s=skin_override or pref.get("skin_"..scope.."."..team,"default")
        if type(s)=="string" and s~="" and s~="default" then skin=s end
    end
    -- 动画翻牌会同时请求旧皮肤和新皮肤，缓存键必须包含显式覆盖值。
    local cache_skin = skin_override == "default" and "default" or (skin or "")
    local key=team..":"..id..":"..cache_skin
    if chara_cache[key]~=nil then return chara_cache[key] end
    local base_root="teams/"..team.."/chara/"..id
    local root=base_root
    local info=false
    local parsed=TBL.parse_file(base_root.."/chara.tbl")
    if parsed and parsed.chara then
        local cfg=parsed.chara
        local face_dir=root.."/"..(cfg.face or "face")
        if skin then
            local sroot="teams/"..team.."/skins/"..skin.."/chara/"..id
            -- getInfo 对目录首返回值为 nil，目录判定必须用 getDirectoryItems。
            if #(love.filesystem.getDirectoryItems(sroot.."/face"))>0 then
                root=sroot
                face_dir=sroot.."/face"
                local sparsed=TBL.parse_file(sroot.."/chara.tbl")
                if sparsed and sparsed.chara then
                    local merged={}; for k,v in pairs(cfg) do merged[k]=v end
                    for k,v in pairs(sparsed.chara) do merged[k]=v end
                    cfg=merged
                end
            end
        end
        local faces={}
        for _,f in ipairs(love.filesystem.getDirectoryItems(face_dir)) do
            if f:sub(-4)==".png" then faces[#faces+1]=f end
        end
        table.sort(faces)
        info={root=root,cfg=cfg,base_root=base_root,name=parsed.chara.name or "",faces=faces,face_dir=face_dir}
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
        local root="teams/"..Registry.dir(tostring(team)).."/chara"
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
        teams=teams and #teams>0 and teams or {DEFAULT_TEAM}
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
    local info=chara_info(team_id(unit),unit.character_id,unit.skin) or chara_info(DEFAULT_TEAM,unit.character_id)
    if not info or #info.faces==0 then return nil end
    -- chara.tbl 可显式指定表情文件（相对角色目录）：face_hit/face_attack/face_idle/face_normal，
    -- 都没写时回退到旧的"文件名含语义码"子串匹配，再回退第一张。
    local group=FACE_GROUP[kind or ""] or "normal"
    local explicit=info.cfg["face_"..group]
    if explicit then
        -- 表情文件名相对 face 目录解析（兼容写在角色根目录的情况）
        for _,base in ipairs({info.face_dir,info.root}) do
            local p=base.."/"..explicit
            if love.filesystem.getInfo(p) then return p end
        end
    end
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
    local info=chara_info(team_id(unit),unit.character_id,unit.skin) or chara_info(DEFAULT_TEAM,unit.character_id)
    if not info then return nil end
    -- 皮肤根目录优先，缺立绘时回落本体。
    local path=info.root.."/chara.png"
    if not love.filesystem.getInfo(path) and info.base_root then
        path=info.base_root.."/chara.png"
    end
    if love.filesystem.getInfo(path) then return Pilots.image(path) end
    return nil
end

-- 队伍对白解析：兼容字符串列表与 {text="",face=""} 对象列表。
local function load_team_dialogue(team,id)
    if id==nil then return false end
    if type(id)=="number" then id=string.format("%03d",id) end
    team=Registry.dir(tostring(team))
    local key=team..":"..id
    if dialogue_cache[key]~=nil then return dialogue_cache[key] end
    local path="teams/"..team.."/chara/"..id.."/dialogue.lua"
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

-- 单位台词表访问器：供其他系统（如经济播报）读取角色 dialogue.lua 的自定义段落。
function Pilots.dialogue(unit)
    local d=load_team_dialogue(team_id(unit),unit.character_id or 0)
    return d and d or nil
end

function Pilots.line(unit,kind,fallback)
    local team=team_id(unit)
    local dialogue=load_team_dialogue(team,unit.character_id)
    local side=(unit.game and unit.team~=unit.game.player_team) and "enemy" or "friendly"
    if kind=="panel" then
        local list=dialogue and dialogue.panel
        if not list or #list==0 then return fallback end
        unit.dialogue_index=unit.dialogue_index or {}
        unit.dialogue_index.panel=(unit.dialogue_index.panel or 0)+1
        local entry=normalize(list[(unit.dialogue_index.panel-1)%#list+1])
        return entry and entry.text~="" and entry.text or fallback
    end
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
        local out=defaults[kind] or fallback
        return out
    end
    unit.dialogue_index=unit.dialogue_index or {}
    unit.dialogue_index[kind]=(unit.dialogue_index[kind] or 0)+1
    local entry=normalize(list[(unit.dialogue_index[kind]-1+(unit.id or 0))%#list+1])
    local text=entry and entry.text or fallback
    -- 占位符由实际对战双方决定称呼对象：敌方台词指向我方指挥官，反之亦然。
    if type(text)=="string" and unit.game then
        local Registry=require("systems.pack_registry")
        local target=(unit.team~=unit.game.player_team) and unit.game.player_team_id or unit.game.enemy_team_id
        local cfg=Registry.load(target).team or {}
        local cid=tonumber(cfg.commander)
        local name=cid and Pilots.profile({character_id=cid,team_id=target}).name or "指挥官"
        text=text:gsub("{commander}",name)
    end
    return text, entry and entry.face or ""
end
return Pilots

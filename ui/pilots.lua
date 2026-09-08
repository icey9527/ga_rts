local Pilots = {}
local profiles=require("config.pilots")
local catalog=require("config.characters")
local images={}
local faces={}
local available
function Pilots.available()
    if not available then
        available={}
        for _,file in ipairs(love.filesystem.getDirectoryItems("assets/portraits")) do
            local id=tonumber(file:match("^fac(%d+)_"))
            if id and catalog.names[id] then available[id]=true end
        end
    end
    return available
end
function Pilots.assign(unit)
    if unit.character_id~=nil and Pilots.available()[unit.character_id] then return end
    local pool=profiles[unit.unit_type] or profiles.fighter
    local candidates={}
    for _,id in ipairs(pool) do if Pilots.available()[id] then candidates[#candidates+1]=id end end
    assert(#candidates>0,"No local portrait for ship role")
    unit.character_id=candidates[((unit.id or 1)-1)%#candidates+1]
end
function Pilots.profile(unit)
    Pilots.assign(unit)
    local id=unit.character_id
    return {name=catalog.names[id],face=id,standing=id,lines=catalog.lines[id] or {},rules=catalog.rules[id] or "自然口语。"}
end
function Pilots.image(path)
    if images[path]==nil then
        local ok,img=pcall(love.graphics.newImage,path)
        images[path]=ok and img or false
    end
    return images[path]
end
local function face_path(id,kind)
    if not faces[id] then
        faces[id]={}
        local prefix=string.format("fac%03d_",id)
        for _,f in ipairs(love.filesystem.getDirectoryItems("assets/portraits")) do
            if f:sub(1,#prefix)==prefix then faces[id][#faces[id]+1]=f end
        end
        table.sort(faces[id])
    end
    local wanted=({hit="0008",lost="0008",failed="0008",attack="0001",skill="0001",idle="0002",praise="0002"})[kind] or "0000"
    for _,f in ipairs(faces[id]) do
        if f:find("_"..wanted,1,true) then return "assets/portraits/"..f end
    end
    return faces[id][1] and "assets/portraits/"..faces[id][1]
end
function Pilots.draw(unit,x,y,size,kind,shape)
    local profile=Pilots.profile(unit)
    local path=face_path(profile.face,kind)
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
    local p=Pilots.profile(unit)
    local name=require("config.character_assets")[p.face]
    return name and Pilots.image("assets/characters/"..name..".png") or nil
end
function Pilots.line(unit,kind,fallback)
    local p=Pilots.profile(unit)
    local path=string.format("dialogue/characters/%03d.lua",p.face)
    local dialogue=love.filesystem.getInfo(path) and require(string.format("dialogue.characters.%03d",p.face))
    local side=(unit.game and unit.team~=unit.game.player_team) and "enemy" or "friendly"
    if kind=="ready" or kind=="interaction" or kind=="follow" or kind=="follow_reply" then
        if side=="enemy" then return nil end
        local personal=dialogue and dialogue.friendly and dialogue.friendly[kind]
        if personal and #personal>0 then
            unit.dialogue_index=unit.dialogue_index or {}
            local i=(unit.dialogue_index[kind] or 0)+1;unit.dialogue_index[kind]=i
            return personal[(i-1)%#personal+1]
        end
        return ({ready="特殊装备已就绪，等待指令。",interaction="航向又变了吗？请留一点时间完成机动。",follow="已经跟上。这段航路一起走吧。",follow_reply="收到，我会留出安全间距。"})[kind]
    end
    local list=dialogue and dialogue[side] and dialogue[side][kind] or p.lines[kind]
    if not list and side=="friendly" and love.filesystem.getInfo("units/"..unit.unit_type.."/dialogue.lua") then
        list=require("units."..unit.unit_type..".dialogue")[kind]
    end
    if side=="enemy" and not list then return nil end
    if not list then
        local defaults={command="指令确认，正在执行。",attack="目标确认，开始攻击。",hit="机体受损，请求支援。",lost="通讯中断……",failed="目标无效，请重新指定。",skill="特殊装备启动。",idle="正在监视周边空域。",praise="目标已击破，保持警戒。"}
        if p.face==3 then return ({command="出发啦！",attack="开始攻击哦！",hit="受到攻击啦！",failed="目标不对哦！",idle="一切正常的说！",skill="准备好啦！",lost="通讯断开了……"})[kind] or "保持警戒哦！" end
        return defaults[kind] or fallback
    end
    unit.dialogue_index=unit.dialogue_index or {}
    unit.dialogue_index[kind]=(unit.dialogue_index[kind] or 0)+1
    return list[(unit.dialogue_index[kind]-1+(unit.id or 0))%#list+1]
end
return Pilots

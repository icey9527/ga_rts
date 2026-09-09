local Mission={}
local scene_cache={}
local Registry=require("systems.pack_registry")

-- 左右手角色编号动态解析：战斗中优先用编制(apply_squad)，
-- 战前小剧场阶段编制未建，回退读双方队伍表。任何队伍通用，不写死编号。
-- 返回 set(四个频道的手下编号) 与 teams(每个频道对应的队伍名)。
local function hand_slots(game)
    if game.advisor_set and game.advisor_teams then
        return game.advisor_set, game.advisor_teams
    end
    local pt=Registry.load(game.player_team_id).team or {}
    local et=Registry.load(game.enemy_team_id).team or {}
    return {tactical=tonumber(pt.left),logistics=tonumber(pt.right),critic=tonumber(et.left),cheer=tonumber(et.right)},
           {tactical=game.player_team_id,logistics=game.player_team_id,critic=game.enemy_team_id,cheer=game.enemy_team_id}
end

-- 小剧场台词槽位：说话人是任一队左右手→立绘位；其余→电台小头像。
-- 用"角色id+队伍名"双条件匹配，兼容 25/22 频道协议与各队字面编号两种写法。
local function line_slot(game,line,unit)
    if line.slot then return line.slot end
    local uid=unit and unit.character_id
    if uid==nil then return "radio" end
    local set,teams=hand_slots(game)
    local tid=unit.team_id
    for _,chan in ipairs({"tactical","logistics","critic","cheer"}) do
        local hid=set[chan]
        if hid~=nil and uid==hid and tid==teams[chan] then
            if chan=="logistics" and tid==game.player_team_id then return "noah" end
            return "advisor"
        end
    end
    return "radio"
end

function Mission.start(game,filename)
    local id=assert(filename:match("level_(%d+)"),"Invalid mission filename")
    local path="levels/scripts/level_"..id..".lua"
    local script=love.filesystem.getInfo(path) and require("levels.scripts.level_"..id) or {}
    game.mission={script=script,shown={},queue={},actors={},age=0,display_text={}}
    -- 战前小剧场由双方队伍对白文件提供，关卡脚本不再承载对白。
    local Advisor=require("systems.advisor")
    local scene_key=tostring(game.player_team_id)..":"..tostring(game.enemy_team_id)
    local tutorial=game.level_data and game.level_data.meta and game.level_data.meta.tutorial
    if tutorial then
        -- 教学关无战前小剧场，且不得写入缓存，避免把同队伍组合的小剧场清空。
        return
    end
    scene_cache[scene_key]=scene_cache[scene_key] or Advisor.opening_scene(game)
    for _,line in ipairs(scene_cache[scene_key] or {}) do Mission.say(game,line) end
end
function Mission.say(game,line)
    local m=game.mission
    if m and line and line.text then m.queue[#m.queue+1]=line end
end
function Mission.advance(game,skip)
    local m=game.mission
    if not m then return end
    m.current=nil; m.age=0
    if skip then m.queue={} end
end
function Mission.update(game,dt)
    local m=game.mission
    if not m then return end
    if not m.current then m.current=table.remove(m.queue,1); m.age=0
    else
        m.age=m.age+dt
        local duration=m.current.duration or math.max(5.5,require("utf8").len(m.current.text)/9+1)
        if m.age>=duration then Mission.advance(game) end
    end
end
function Mission.triggered(game,event)
    local c=event.when
    if not c then return game.level_time>=(event.time or 0) end
    if c.type=="losses" then return (game.losses or 0)>=(c.count or 1) end
    if c.type=="enemy_remaining" then return #game:get_enemy_units(game.player_team)<=(c.count or 3) end
    if c.type=="flag" then return game.advisor and game.advisor.flags[c.flag] end
    if c.type=="escort_progress" then return game.objective and (game.objective.progress or 0)>=(c.value or 0.5) end
    return false
end
function Mission.tick(game)
    local m=game.mission
    if not m or m.finished then return end
    -- 关卡脚本不再触发对白；战斗中的状态提示由 Advisor/Slots 独立处理。
end
function Mission.current(game)
    local m=game.mission
    if not m or not m.current then return nil end
    m.display_text=m.display_text or {}
    local line=m.current
    -- 剧情里 id=25/22 代表战术/后勤频道，由所选队伍的左右手出演。
    local set=game.advisor_set or {}
    local hs=hand_slots(game)
    local channel=(line.channel) or ((line.id==hs.tactical and hs.tactical~=nil) and "tactical") or ((line.id==hs.logistics and hs.logistics~=nil) and "logistics") or nil
    local id=(channel and set[channel]) or line.id or 25
    local text=m.display_text[line]
    if not text then
        text=line.text or ""
        if m.script.intro and line==m.script.intro[1] and channel then
            -- 开场第一句使用 teams/<我方>/advisor/dialogue.lua 的关卡开场词。
            local pid=game.player_team_id or Registry.default_player()
            local path="teams/"..Registry.dir(pid).."/advisor/dialogue.lua"
            local ok,data=pcall(function()
                local src=love.filesystem.getInfo(path) and love.filesystem.read(path)
                local chunk=src and loadstring(src)
                return chunk and chunk()
            end)
            if ok and type(data)=="table" and data.intro then
                local key=game.level_name and game.level_name:match("(%d+)") or "default"
                text=data.intro[key] or data.intro.default or text
            end
        end
        m.display_text[line]=text
    end
    local unit
    local speaker_team=line.team or game.player_team
    for _,u in ipairs(game.units) do
        if u.character_id==id and u.team==speaker_team then unit=u; break end
    end
    if not unit then
        -- 临时演员也必须携带真实队伍和阵营，否则会从我方目录取头像。
        local team_for=line.team_id or (channel and game.advisor_teams and game.advisor_teams[channel]) or game.player_team_id or Registry.default_player()
        local key=tostring(id)..":"..tostring(speaker_team)
        local actor=require("systems.advisor").speaker(game,id,team_for,speaker_team,line.role or channel)
        actor.unit_type=(channel=="logistics") and "researcher" or "instructor"
        m.actors[key]=m.actors[key] or actor
        unit=m.actors[key]
    end
    return line,unit,m.age,text
end
function Mission.finish(game,result)
    local m=game.mission
    if not m or m.finished then return end
    m.finished=result; m.queue={}; m.current=nil
    -- 结算画面不再读取关卡内嵌对白。
end

function Mission.contains(game,x,y)
    local line,unit=Mission.current(game)
    if not line then return false end
    local slot=line_slot(game,line,unit)
    if slot=="noah" or slot=="advisor" or slot=="coco" then return x>=270 and y>=love.graphics.getHeight()-210 end
    local w=love.graphics.getWidth()
    local left=w-408
    if game.economy and game.economy.open then left=w-math.min(390,w-550)-282 end
    return x>=left and y>=66 and y<220
end
function Mission.busy(game)
    local m=game.mission
    return m and (m.current~=nil or #m.queue>0)
end
function Mission.draw(game)
    local line,unit,age,text=Mission.current(game)
    if not line then return end
    local g=love.graphics
    local w,h=g.getDimensions()
    local slot=line_slot(game,line,unit)
    if slot~="noah" and slot~="advisor" and slot~="coco" and slot~="radio" then slot="radio" end
    local width=math.min(390,w-290)
    local x,y=w-width-18,66
    if slot=="radio" and game.economy and game.economy.open then width=math.min(width,w-550); x=w-width-282 end
    if slot=="coco" or slot=="advisor" or slot=="noah" then
        width=math.min(310,w-440)
        -- 敌方小剧场统一放右侧；旧逻辑只把诺阿(id=22)放右侧，
        -- 导致敌方阿尔茉(id=26)被错误地画到我方左侧。
        local right_side=(line.screen_side=="right") or (not line.screen_side and ((line.team==1) or slot=="noah"))
        x=right_side and w-width-150 or 395
        y=h-170
        local img=require("ui.pilots").standing(unit)
        if img then
            local s=160/img:getHeight()
            local px=right_side and w-72 or 343
            g.push("all");g.setColor(1,1,1,math.min(1,age*4))
            g.draw(img,px,h-30,math.sin(age*1.2)*0.01,s,s,img:getWidth()/2,img:getHeight());g.pop()
        end
    end
    require("ui.comms").bubble(unit,text or line.text,line.kind or "idle",x,y,width,age,10,56)
end
return Mission

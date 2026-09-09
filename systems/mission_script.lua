local Mission={}

function Mission.start(game,filename)
    local id=assert(filename:match("level_(%d+)"),"Invalid mission filename")
    local path="levels/scripts/level_"..id..".lua"
    local script=love.filesystem.getInfo(path) and require("levels.scripts.level_"..id) or {}
    game.mission={script=script,shown={},queue={},actors={},age=0,display_text={}}
    for _,line in ipairs(script.intro or {}) do Mission.say(game,line) end
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
    for i,event in ipairs(m.script.interludes or {}) do
        if not m.shown[i] and Mission.triggered(game,event) then
            m.shown[i]=true
            if event.lines then for _,line in ipairs(event.lines) do Mission.say(game,line) end else Mission.say(game,event) end
        end
    end
end
function Mission.current(game)
    local m=game.mission
    if not m or not m.current then return nil end
    m.display_text=m.display_text or {}
    local line=m.current
    -- 剧情里 id=25/22 代表战术/后勤频道，由所选队伍的左右手出演。
    local set=game.advisor_set or {}
    local channel=(line.id==25 and "tactical") or (line.id==22 and "logistics") or nil
    local id=(channel and set[channel]) or line.id or 25
    local text=m.display_text[line]
    if not text then
        text=line.text or ""
        if line==m.script.intro[1] and channel then
            -- 开场第一句使用 teams/<我方>/advisor/dialogue.lua 的关卡开场词。
            local pid=game.player_team_id or "rune"
            local path="teams/"..pid.."/advisor/dialogue.lua"
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
    for _,u in ipairs(game.units) do if u.character_id==id and u.team~=1 then unit=u; break end end
    if not unit then
        -- 通讯演员需要 game 引用与阵营：头像红边和台词侧别都按此判定。
        local team_for=(channel and game.advisor_teams and game.advisor_teams[channel]) or game.player_team_id or "rune"
        m.actors[id]=m.actors[id] or {character_id=id,team_id=team_for,unit_type=(id==22 or id==74) and "researcher" or "instructor",team=id==74 and 1 or game.player_team,game=game}
        unit=m.actors[id]
    end
    return line,unit,m.age,text
end
function Mission.finish(game,result)
    local m=game.mission
    if not m or m.finished then return end
    m.finished=result; m.queue={}; m.current=nil
    for _,line in ipairs(m.script[result] or {}) do Mission.say(game,line) end
end

function Mission.contains(game,x,y)
    local line=Mission.current(game)
    if not line then return false end
    if line.id==22 or line.id==25 or line.id==21 or line.id==26 or line.slot=="noah" or line.slot=="coco" or line.slot=="advisor" then return x>=270 and y>=love.graphics.getHeight()-210 end
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
    local slot=line.slot or ((line.id==22) and "noah" or ((line.id==25 or line.id==21 or line.id==26) and "advisor" or "radio"))
    if slot~="noah" and slot~="advisor" and slot~="coco" and slot~="radio" then slot="radio" end
    local width=math.min(390,w-290)
    local x,y=w-width-18,66
    if slot=="radio" and game.economy and game.economy.open then width=math.min(width,w-550); x=w-width-282 end
    if slot=="coco" or slot=="advisor" or slot=="noah" then
        width=math.min(390,w-440)
        x=slot=="noah" and w-width-150 or 395
        y=h-170
        local img=require("ui.pilots").standing(unit)
        if img then
            local s=160/img:getHeight()
            local px=slot=="noah" and w-72 or 320
            g.push("all");g.setColor(1,1,1,math.min(1,age*4))
            g.draw(img,px,h-30,math.sin(age*1.2)*0.01,s,s,img:getWidth()/2,img:getHeight());g.pop()
        end
    end
    require("ui.comms").bubble(unit,text or line.text,line.kind or "idle",x,y,width,age,10,56)
end
return Mission

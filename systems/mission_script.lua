local Mission={}

function Mission.start(game,filename)
    local id=assert(filename:match("level_(%d+)"),"Invalid mission filename")
    local path="levels/scripts/level_"..id..".lua"
    local script=love.filesystem.getInfo(path) and require("levels.scripts.level_"..id) or {}
    game.mission={script=script,shown={},queue={},actors={},age=0}
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
    local line=m.current
    local id=line.id or 25
    local unit
    for _,u in ipairs(game.units) do if u.character_id==id then unit=u; break end end
    if not unit then
        m.actors[id]=m.actors[id] or {character_id=id,unit_type=id==22 and "researcher" or "instructor",team=game.player_team,game=game}
        unit=m.actors[id]
    end
    return line,unit,m.age
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
    if line.id==22 or line.id==25 or line.slot=="noah" or line.slot=="coco" then return x>=270 and y>=love.graphics.getHeight()-210 end
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
    local line,unit,age=Mission.current(game)
    if not line then return end
    local g=love.graphics
    local w,h=g.getDimensions()
    local slot=line.slot or (line.id==22 and "noah" or (line.id==25 and "coco" or "radio"))
    local width=math.min(390,w-290)
    local x,y=w-width-18,66
    if slot=="radio" and game.economy and game.economy.open then width=math.min(width,w-550); x=w-width-282 end
    if slot=="coco" or slot=="noah" then
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
    require("ui.comms").bubble(unit,line.text,line.kind or "idle",x,y,width,age,10,56)
end
return Mission

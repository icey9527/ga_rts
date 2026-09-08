local Advisor={}
local steps=require("levels.scripts.level_00").training
function Advisor.start(game)
    game.advisor={unit={unit_type="instructor",callsign="COMMAND"},age=0,life=10,text="我是可可。卡兹亚君，先展开队形，别急着把大家送进火线。",kind="idle",clock=0,step=1,flags={},losses=0,kills=0}
    if game.level_data.meta and game.level_data.meta.tutorial then
        game.advisor.tutorial=true
        game.advisor.text=steps[1].text
        game.economy.credits=1800
        game.tutorial_hold=true
        for _,u in ipairs(game:get_units_by_team(game.player_team)) do
            u.sp=u.max_sp
            if u.unit_type=="fighter" then u.skill_data={type="shield",shield_amount=250,duration=8} end
        end
    end
    game.advisor.enemy_count=#game:get_enemy_units(game.player_team)
end
function Advisor.event(game,event)
    if game.advisor then game.advisor.flags[event]=true end
end
function Advisor.say(game,text,kind)
    local a=game.advisor
    if not a then return end
    a.text,a.kind,a.age,a.life=text,kind or "idle",0,8
end
function Advisor.update(game,dt)
    if game.researcher then game.researcher.age=game.researcher.age+dt; game.researcher.life=game.researcher.life-dt end
    local a=game.advisor
    if not a then return end
    a.age,a.life,a.clock=a.age+dt,a.life-dt,a.clock+dt
    if a.tutorial then
        a.life=10
        local passed=(a.step==1 and #game.selected_units>0) or (a.step==2 and a.flags.pan and a.flags.zoom) or (a.step==3 and a.flags.move) or (a.step==4 and a.flags.attack) or (a.step==5 and a.flags.skill) or (a.step==6 and a.flags.economy) or (a.step==7 and a.flags.collect) or (a.step==8 and a.flags.recruit) or (a.step==9 and a.flags.research)
        if passed then
            a.step=a.step+1; Advisor.say(game,steps[a.step].text,"praise")
            if steps[a.step].id==22 then
                -- 后勤教学只进入诺阿槽位，避免与可可重复占用同一提示。
                Advisor.say(game,"", "idle")
                require("systems.economy").say_logistics(game,"player",steps[a.step].text,"idle")
            end
            if a.step==5 then
                for _,u in ipairs(game:get_units_by_team(game.player_team)) do
                    if u.unit_type=="fighter" then u.sp=u.max_sp; game:select_unit(u); break end
                end
            end
            if a.step==10 then game.tutorial_complete=true;game.tutorial_hold=false;game.opening_grace=0 end
        end
        if steps[a.step].id==22 and game.researcher and game.researcher.life<=0 then
            require("systems.economy").say_logistics(game,"player",steps[a.step].text)
        end
        return
    end
    if a.life>0 or game:is_paused() or require("systems.mission_script").busy(game) then return end
    local Pilots=require("ui.pilots")
    if (game.losses or 0)>a.losses then
        a.losses=game.losses
        Advisor.say(game,Pilots.line(a.unit,"lost",""),"lost")
        require("systems.economy").say(game,"卡兹亚，设备不是拿来硬吃火力的。先拉开距离，再重新组织队形。","failed")
        return
    end
    for _,u in ipairs(game:get_units_by_team(game.player_team)) do
        if u.hp/u.max_hp<0.3 and (not u.advisor_warn or game.level_time-u.advisor_warn>25) then
            u.advisor_warn=game.level_time
            Advisor.say(game,"卡兹亚君，"..u.name.." 装甲不足三成！先撤退，再安排维修。","hit")
            return
        end
    end
    local n=#game:get_enemy_units(game.player_team)
    if n<a.enemy_count then
        a.enemy_count=n
        Advisor.say(game,Pilots.line(a.unit,"praise",""),"praise")
        if game.economy then require("systems.economy").say(game,"判断尚可。看来这套设备没有白给你。","praise") end
        return
    end
    if a.clock>90 then
        a.clock=0
        local all=game:get_units_by_team(game.player_team)
        if #all>0 then
            local u=all[math.random(#all)]
            game:report_event(u,"idle","保持警戒。")
        end
        Advisor.say(game,Pilots.line(a.unit,"idle",""),"idle")
    end
end
local function draw_researcher(game)
    local r=game.researcher
    if not r or r.life<=0 then return end
    local g=love.graphics
    local Pilots=require("ui.pilots")
    local img=Pilots.standing(r.unit)
    local x=g.getWidth()-440
    if img then
        local s=155/img:getHeight()
        local slide=(1-math.min(1,r.age*3,r.life))*110
        g.push("all")
        g.setColor(1,1,1,math.min(1,r.age*3,r.life))
        g.draw(img,g.getWidth()-70+slide,g.getHeight()-30,-math.sin(r.age*1.4)*0.01,s,s,img:getWidth()/2,img:getHeight())
        g.pop()
    end
    require("ui.comms").bubble(r.unit,r.text,r.kind,x,g.getHeight()-166,310,r.age,r.life,48)
end
function Advisor.draw(game)
    local research=game.researcher and game.researcher.life>0
    if research then draw_researcher(game) end
    if research and love.graphics.getWidth()<1250 then return end
    local a=game.advisor
    if not a or a.life<=0 then return end
    local g=love.graphics
    local Pilots=require("ui.pilots")
    local img=Pilots.standing(a.unit)
    local x=265
    local w=math.min(450,g.getWidth()-x-18)
    local y=g.getHeight()-166
    if img then
        local height=a.tutorial and 238 or 146
        local s=height/img:getHeight()
        g.push("all")
        g.setColor(1,1,1,math.min(1,a.age*3,a.life))
        local sway=math.sin(a.clock*1.6)*0.012
        local slide=(1-math.min(1,a.age*3,a.life))*110
        g.draw(img,x+78-slide,g.getHeight()-30,sway,s,s,img:getWidth()/2,img:getHeight())
        g.pop()
    end
    local offset=145
    require("ui.comms").bubble(a.unit,a.text,a.kind,x+offset,y,w-offset,a.age,a.life,48)
end
function Advisor.contains(game,mx,my)
    if game.researcher and game.researcher.life>0 and mx>=love.graphics.getWidth()-440 and my>=love.graphics.getHeight()-230 then return true end
    local a=game.advisor
    return a and a.life>0 and mx>=265 and mx<=715 and my>=love.graphics.getHeight()-(a.tutorial and 268 or 166) and my<=love.graphics.getHeight()-25
end
return Advisor

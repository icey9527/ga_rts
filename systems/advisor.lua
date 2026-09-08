local Advisor={}
local steps=require("levels.scripts.level_00").training
local Slots=require("systems.comms_slots")

-- 按所选舰队切换顾问：卡兹亚队=可可+诺阿，塔克特队=雷斯特+阿尔茉。
-- 侧翼频道角色随之互换；台词按角色性格各自成文。
local SQUAD_ADVISORS={
    [1]={tactical=25,logistics=22,critic=21,cheer=26},
    [2]={tactical=21,logistics=26,critic=25,cheer=22},
}
local warn_text={
    [25]="卡兹亚君，%s 装甲不足三成！先撤退，再安排维修。",
    [21]="卡兹亚，%s 装甲告警。先脱离火线，再安排维修。",
}
local loss_text={
    [21]="队形散了才会被抓住破绽。行动结束后逐条复盘。",
    [25]="卡兹亚君，队形散了才会被抓住破绽。复盘时逐条分析。",
}
local cheer_text={
    [26]="漂亮——！刚才的配合我全程记下来了！",
    [22]="目标击破。战斗数据已记录，保持这个节奏。",
}
local progress_text={
    [26]="过半啦过半——！大家咬住节奏，胜利就在前面！",
    [22]="目标过半。按当前节奏，判定对我们有利。保持。",
}

function Advisor.apply_squad(game)
    local set=SQUAD_ADVISORS[game.chosen_squad] or SQUAD_ADVISORS[1]
    game.advisor_set=set
    if game.advisor and game.advisor.tutorial then return end
    if game.advisor then
        game.advisor.unit.character_id=set.tactical
        game.advisor.text=""
        game.advisor.life=0
        game.advisor.queue={}
    end
    if game.researcher then
        game.researcher.unit.character_id=set.logistics
        game.researcher.text=""
        game.researcher.life=0
        game.researcher.queue={}
    end
    if game.logistics then
        for name,id in pairs({tact=set.critic,almo=set.cheer}) do
            local slot=game.logistics[name]
            if slot then
                slot.unit.character_id=id
                slot.text=""
                slot.life=0
                slot.queue={}
            end
        end
    end
end

local function squad_set(game)
    return game.advisor_set or SQUAD_ADVISORS[game.chosen_squad] or SQUAD_ADVISORS[1]
end

local function step_speaker(a)
    local s=steps[a.step]
    return s and s.id or 25
end

function Advisor.start(game)
    -- 可可不再开场自我介绍：空闲槽位保持空文本，只有事件触发时才显示。
    game.advisor={unit={unit_type="instructor",callsign="COMMAND"},age=0,life=0,text="",kind="idle",clock=0,step=1,flags={},losses=0,kills=0,queue={}}
    if game.level_data.meta and game.level_data.meta.tutorial then
        game.advisor.tutorial=true
        Advisor.say(game,steps[1].text,"idle")
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
function Advisor.say(game,text,kind,life)
    local a=game.advisor
    if not a then return end
    if a.tutorial then
        -- 教学步骤必须立刻替换，不能排队，否则指引滞后于操作。
        Slots.replace(a,text,kind,life or 10)
    else
        Slots.say(a,text,kind,life)
    end
end
function Advisor.update(game,dt)
    for _,slot in pairs(game.logistics or {}) do Slots.update(slot,dt) end
    local a=game.advisor
    if not a then return end
    Slots.update(a,dt)
    a.clock=a.clock+dt
    if a.tutorial then
        a.life=10
        local speaker=step_speaker(a)
        local passed=(a.step==1 and #game.selected_units>0) or (a.step==2 and a.flags.pan and a.flags.zoom) or (a.step==3 and a.flags.move) or (a.step==4 and a.flags.attack) or (a.step==5 and a.flags.skill) or (a.step==6 and a.flags.economy) or (a.step==7 and a.flags.collect) or (a.step==8 and a.flags.recruit) or (a.step==9 and a.flags.research)
        if passed then
            a.step=a.step+1
            if step_speaker(a)==22 then
                -- 后勤教学进入诺阿槽位，可可面板完全让位，避免重复显示。
                Slots.clear(a)
                if game.researcher then
                    Slots.replace(game.researcher,steps[a.step].text,"idle",6)
                end
            else
                Advisor.say(game,steps[a.step].text,"praise")
                if game.researcher then
                    game.researcher.queue={}
                    game.researcher.life=math.min(game.researcher.life,1.2)
                end
            end
            if a.step==5 then
                for _,u in ipairs(game:get_units_by_team(game.player_team)) do
                    if u.unit_type=="fighter" then u.sp=u.max_sp; game:select_unit(u); break end
                end
            end
            if a.step==10 then game.tutorial_complete=true;game.tutorial_hold=false;game.opening_grace=0 end
        end
        if speaker==22 and game.researcher then
            -- 当前步骤仍由诺阿讲解：指引保持可见。托底必须大于 1 秒，
            -- 否则退场滑动动画（寿命<1 时右移）会让立绘停在半退场位置。
            game.researcher.life=math.max(game.researcher.life,1.2)
        end
        return
    end
    if a.life>0 or game:is_paused() or require("systems.mission_script").busy(game) then return end
    local Pilots=require("ui.pilots")
    local logistics=game.logistics or {}
    if not a.opened and (game.level_time or 0)>2 then
        -- 开局正式指导：雷斯特每关播报一次作战要点。
        a.opened=true
        if logistics.tact then
            Slots.say(logistics.tact,Pilots.line(logistics.tact.unit,"command",""),"command")
        end
        return
    end
    local objective=game.objective
    if not a.progress_cheer and objective and objective.spec and (objective.spec.type=="escort" or objective.spec.type=="survive") and (objective.progress or 0)>=0.5 then
        -- 护送/生存过半：侧翼频道代表塔克特队鼓励一次。
        a.progress_cheer=true
        if logistics.almo then
            Slots.say(logistics.almo,progress_text[logistics.almo.unit.character_id] or progress_text[26],"praise")
        end
        return
    end
    if (game.losses or 0)>a.losses then
        a.losses=game.losses
        Advisor.say(game,Pilots.line(a.unit,"lost",""),"lost")
        -- 正式的队形批评走侧翼频道，诺阿/阿尔茉不再复读同一事件。
        if logistics.tact then
            Slots.say(logistics.tact,loss_text[logistics.tact.unit.character_id] or loss_text[21],"failed")
        end
        local enemy=logistics.enemy
        if enemy and (enemy.cool_until or 0)<game.level_time then
            enemy.cool_until=game.level_time+40
            Slots.say(enemy,Pilots.line(enemy.unit,"attack",""),"attack")
        end
        return
    end
    for _,u in ipairs(game:get_units_by_team(game.player_team)) do
        if u.hp/u.max_hp<0.3 and (not u.advisor_warn or game.level_time-u.advisor_warn>25) then
            u.advisor_warn=game.level_time
            require("systems.audio").play("warning")
            Advisor.say(game,string.format(warn_text[a.unit.character_id] or warn_text[25],u.name),"hit")
            return
        end
    end
    local n=#game:get_enemy_units(game.player_team)
    if n<a.enemy_count then
        local kills=a.enemy_count-n
        a.enemy_count=n
        Advisor.say(game,Pilots.line(a.unit,"praise",""),"praise")
        -- 击杀欢呼走侧翼频道；索尔贝按战损阈值做出反应。
        if logistics.almo and (logistics.almo.cool_until or 0)<game.level_time then
            logistics.almo.cool_until=game.level_time+30
            Slots.say(logistics.almo,cheer_text[logistics.almo.unit.character_id] or cheer_text[26],"praise")
        end
        local enemy=logistics.enemy
        if enemy then
            enemy.lost_count=(enemy.lost_count or 0)+kills
            if enemy.lost_count==1 or enemy.lost_count%3==0 then
                Slots.say(enemy,Pilots.line(enemy.unit,"hit",""),"hit")
            end
            if n<=3 and not enemy.desperate then
                enemy.desperate=true
                Slots.say(enemy,Pilots.line(enemy.unit,"lost",""),"lost")
            end
        end
        return
    end
    if a.clock>90 then
        a.clock=0
        -- 周期播报轮换：可可→雷斯特→阿尔茉，各走各的槽位。
        a.rotate=((a.rotate or 0)+1)%3
        if a.rotate==1 then
            local all=game:get_units_by_team(game.player_team)
            if #all>0 then
                local u=all[math.random(#all)]
                game:report_event(u,"idle","保持警戒。")
            end
            Advisor.say(game,Pilots.line(a.unit,"idle",""),"idle")
        elseif a.rotate==2 and logistics.tact then
            Slots.say(logistics.tact,Pilots.line(logistics.tact.unit,"idle",""),"idle")
        elseif logistics.almo then
            Slots.say(logistics.almo,Pilots.line(logistics.almo.unit,"idle",""),"idle")
        end
    end
end
local function draw_researcher(game)
    local r=game.researcher
    if not r or r.life<=0 or r.text=="" then return end
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
    local research=game.researcher and game.researcher.life>0 and game.researcher.text~=""
    if research then draw_researcher(game) end
    if research and love.graphics.getWidth()<1250 then return end
    local a=game.advisor
    if not a or a.life<=0 or a.text=="" then return end
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
    if game.researcher and game.researcher.life>0 and game.researcher.text~="" and mx>=love.graphics.getWidth()-440 and my>=love.graphics.getHeight()-230 then return true end
    local a=game.advisor
    return a and a.life>0 and a.text~="" and mx>=265 and mx<=715 and my>=love.graphics.getHeight()-(a.tutorial and 268 or 166) and my<=love.graphics.getHeight()-25
end
return Advisor

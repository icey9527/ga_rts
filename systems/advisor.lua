local Advisor={}
local steps=require("levels.scripts.level_00").training
local Slots=require("systems.comms_slots")
local Registry=require("systems.pack_registry")
local Preferences=require("systems.preferences")

-- 顾问编制完全来自 teams/<队>/team.tbl：我方 left/right 坐战术与后勤位，
-- 敌方队伍的 left/right 转任侧翼批评与鼓励频道。台词按角色性格各自成文。
-- teams/<队>/advisor/dialogue.lua：开场词与左右手频道台词（{text,face} 兼容纯字符串）。
local advisor_lines_cache={}
function Advisor.speaker(game,id,team_id,team,role)
    local side=team==game.player_team and "player" or "enemy"
    return {character_id=id,team_id=team_id,team=team,game=game,role=role,
        character_key=table.concat({side,tostring(team_id),tostring(id),tostring(role or "speaker")},"."),
        skin=require("systems.preferences").get("skin_"..side.."."..tostring(team_id),"default")}
end
local function advisor_lines(game,team_id)
    team_id=team_id or (game and game.player_team_id) or Registry.default_player()
    if advisor_lines_cache[team_id]~=nil then return advisor_lines_cache[team_id] end
    local path="teams/"..Registry.dir(team_id).."/advisor/dialogue.lua"
    local data={}
    if love.filesystem.getInfo(path) then
        local src=love.filesystem.read(path)
        local chunk=src and loadstring(src)
        local ok,dat=pcall(chunk and chunk or function() return nil end)
        if ok and type(dat)=="table" then data=dat end
    end
    advisor_lines_cache[team_id]=data
    return data
end

-- teams/<队>/advisor/dialogue.lua 的 groups：每队 4 组左右手对话，
-- 随机触发时两队共用同一组号，形成镜像对话。读取统一走 advisor_lines 的缓存。
local function team_data(team_id)
    return advisor_lines(nil,team_id) or {}
end
local function team_groups(game,team_id)
    local d=team_data(team_id)
    return (type(d.groups)=="table") and d or nil
end
local function say_latest(slot,text,kind,life)
    if not slot then return end
    slot.queue={}
    Slots.say(slot,text,kind,life)
end
-- 统一左右手发言入口：role 始终表示说话人的真实职位，screen_side 只由绘制层决定。
function Advisor.say_hand(game, side, role, text, kind, life, replace)
    if text==nil or tostring(text)=="" then return false end
    local slot
    if side=="player" then
        slot=(role=="right") and game.researcher or game.advisor
    else
        local l=game.logistics or {}
        slot=(role=="right") and l.almo or l.tact
    end
    if not slot then return false end
    if replace then Slots.replace(slot,tostring(text),kind,life) else say_latest(slot,tostring(text),kind,life) end
    return true
end
local function commander_name(team_id)
    local cfg=Registry.load(team_id).team or {}
    local id=tonumber(cfg.commander)
    if not id then return "指挥官" end
    local p=require("ui.pilots").profile({character_id=id,team_id=team_id})
    return p and p.name or "指挥官"
end
local function scene_text(text,game,side)
    local own=side=="enemy" and game.enemy_team_id or game.player_team_id
    local opponent=side=="enemy" and game.player_team_id or game.enemy_team_id
    return tostring(text)
        :gsub("{player_commander}",commander_name(game.player_team_id))
        :gsub("{enemy_commander}",commander_name(game.enemy_team_id))
        :gsub("{opponent_commander}",commander_name(opponent))
        :gsub("{commander}",commander_name(own))
end

function Advisor.opening_scene(game)
    local p=team_data(game.player_team_id); local e=team_data(game.enemy_team_id)
    local ps=p.scenes or p.opening_scenes or {}; local es=e.scenes or e.opening_scenes or {}
    if #ps==0 and #es==0 then return {} end
    -- 随机编队等情形可能一侧没有台词：各侧独立抽取，绝不能对空表 math.random。
    local a=(#ps>0 and ps[math.random(#ps)]) or {}
    local b=(#es>0 and es[math.random(#es)]) or {}
    local out={}; local n=math.max(#a,#b)
    local function add(line,side)
        if type(line)=="string" then line={text=line} end
        if type(line)~="table" or not line.text then return end
        local rendered_text=scene_text(line.text,game,side)
        local cfg=Registry.load(side=="enemy" and game.enemy_team_id or game.player_team_id).team or {}
        local left_id=tonumber(cfg.left)
        local right_id=tonumber(cfg.right)
        local id=line.id or ((side=="player" and game.advisor_set and game.advisor_set.tactical) or (game.advisor_set and game.advisor_set.critic))
        if not id then return end
        local screen_side
        if side=="enemy" then screen_side=(id==right_id) and "left" or "right"
        else screen_side=(id==right_id) and "right" or "left" end
        out[#out+1]={id=id,text=rendered_text,kind=line.kind or "idle",duration=line.duration,team=(side=="enemy") and 1 or 0,team_id=(side=="enemy") and game.enemy_team_id or game.player_team_id,screen_side=screen_side}
    end
    for i=1,n do add(a[i],"player"); add(b[i],"enemy") end
    return out
end

local warn_text={
    default="检测到%s装甲告警。先脱离火线，再安排维修。",
    [25]="%s装甲不足三成！卡兹亚君，先撤退，再安排维修。",
}
local loss_text={
    default="队形散了才会被抓住破绽。行动结束后逐条复盘。",
    [25]="卡兹亚君，队形散了才会被抓住破绽。复盘时逐条分析。",
}
local cheer_text={
    default="目标击破。干得漂亮，保持这个节奏。",
    [26]="漂亮——！刚才的配合我全程记下来了！",
    [22]="目标击破。战斗数据已记录，保持这个节奏。",
}
local progress_text={
    default="目标过半。按当前节奏，判定对我们有利。保持。",
    [26]="过半啦过半——！大家咬住节奏，胜利就在前面！",
    [22]="目标过半。按当前节奏，判定对我们有利。保持。",
}

function Advisor.apply_squad(game)
    -- 教学关同样按队伍表绑定：左右手来自 left/right 配置，角色固定不随机。
    local pid=game.player_team_id or Registry.default_player()
    local eid=game.enemy_team_id or Registry.default_enemy()
    local set=game.advisor_set
    local teams=game.advisor_teams
    if not set or not teams then
        local pt=Registry.load(pid).team or {}
        local et=Registry.load(eid).team or {}
        -- 左右手直接取队伍表的 left/right；引用不存在的角色目录时置空，绝不用别的队伍角色顶替。
        local function hand(team_id,id)
            return (id and Registry.character(nil,team_id,id)) and id or nil
        end
        set={
            tactical=hand(pid,tonumber(pt.left)),
            logistics=hand(pid,tonumber(pt.right)),
            critic=hand(eid,tonumber(et.left)),
            cheer=hand(eid,tonumber(et.right)),
        }
        teams={tactical=pid,logistics=pid,critic=eid,cheer=eid}
    end
    game.advisor_set=set
    game.advisor_teams=teams
    local function apply_skin(unit, side)
        if not unit then return end
        local tid=unit.team_id
        local scope=(side=="enemy") and "enemy" or "player"
        unit.skin=Preferences.get("skin_"..scope.."."..tostring(tid), "default")
    end
    local function apply_role(unit, side, role)
        if not unit then return end
        unit.role = role
        unit.character_key = table.concat({side, tostring(unit.team_id), tostring(unit.character_id), role}, ".")
    end
    -- 槽位绑定：阵营号(team)与队伍名(team_id)必须一起绑，
    -- 否则敌方左右手会沿用初始化时的我方阵营，被画成白色头像。
    if game.advisor and set.tactical then
        game.advisor.unit.team_id=teams.tactical or pid
        game.advisor.unit.team=game.player_team
        game.advisor.unit.character_id=set.tactical
        apply_role(game.advisor.unit, "player", "left")
        apply_skin(game.advisor.unit, "player")
        game.advisor.text=""
        game.advisor.life=0
        game.advisor.queue={}
    end
    if game.researcher and set.logistics then
        game.researcher.unit.team_id=teams.logistics or pid
        game.researcher.unit.team=game.player_team
        game.researcher.unit.character_id=set.logistics
        apply_role(game.researcher.unit, "player", "right")
        apply_skin(game.researcher.unit, "player")
        game.researcher.text=""
        game.researcher.life=0
        game.researcher.queue={}
    end
    if game.logistics then
        for name,bind in pairs({tact={team=teams.critic,id=set.critic},almo={team=teams.cheer,id=set.cheer}}) do
            local slot=game.logistics[name]
            if slot then
                if bind.id then
                    slot.unit.team_id=bind.team or eid
                    slot.unit.team=(bind.team==game.enemy_team_id) and 1 or game.player_team
                    slot.unit.character_id=bind.id
                    apply_role(slot.unit, "enemy", name=="tact" and "left" or "right")
                    apply_skin(slot.unit, "enemy")
                    slot.text=""
                    slot.life=0
                    slot.queue={}
                    slot.silenced=false
                else
                    -- 该队没有这只手：清空并静音槽位，保持沉默。
                    Slots.clear(slot)
                    slot.silenced=true
                end
            end
        end
        local eslot=game.logistics.enemy
        if eslot and game.enemy_team_id then
            eslot.unit.team_id=game.enemy_team_id
            eslot.unit.team=1
            apply_role(eslot.unit, "enemy", "logistics")
            apply_skin(eslot.unit, "enemy")
        end
    end
end

local function step_speaker(a)
    local s=steps[a.step]
    return s and s.id or 25
end

function Advisor.start(game)
    -- 可可不再开场自我介绍：空闲槽位保持空文本，只有事件触发时才显示。
    game.advisor={unit={unit_type="instructor",callsign="COMMAND",team=game.player_team,team_id=game.player_team_id},age=0,life=0,text="",kind="idle",clock=0,step=1,flags={},losses=0,kills=0,queue={}}
    game.advisor.unit.game=game
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
    game.advisor.clock=25  -- 开局约 20 秒就来第一轮左右手互动
end
function Advisor.event(game,event)
    if game.advisor then game.advisor.flags[event]=true end
end
function Advisor.say(game,text,kind,life)
    local a=game.advisor
    if not a then return end
    if a.panel_active then
        a.panel_active=false;a.panel_close_at=nil
        Slots.replace(a,text,kind,life)
        return
    end
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
    if a.panel_active and a.panel_close_at and (game.level_time or 0)>=a.panel_close_at then
        Slots.clear(a)
        a.panel_active=false
        a.panel_close_at=nil
    end
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
    if (a.life>0 and not a.panel_active) or game:is_paused() or require("systems.mission_script").busy(game) then return end
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
            Slots.say(logistics.almo,(advisor_lines(game,game.enemy_team_id).right and advisor_lines(game,game.enemy_team_id).right.progress)
            or progress_text[logistics.almo.unit.character_id] or progress_text.default,"praise")
        end
        return
    end
    if (game.losses or 0)>a.losses then
        a.losses=game.losses
        Advisor.say(game,Pilots.line(a.unit,"lost",""),"lost")
        -- 正式的队形批评走侧翼频道，诺阿/阿尔茉不再复读同一事件。
        if logistics.tact then
            Slots.say(logistics.tact,(advisor_lines(game,game.enemy_team_id).left and advisor_lines(game,game.enemy_team_id).left.loss)
            or loss_text[logistics.tact.unit.character_id] or loss_text.default,"failed")
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
            Advisor.say(game,string.format(
                (advisor_lines(game,game.player_team_id).left and advisor_lines(game,game.player_team_id).left.warn)
                or warn_text[a.unit.character_id] or warn_text.default,u.name),"hit")
            return
        end
        if u.max_energy and u.energy/u.max_energy<0.15 and (not u.energy_warn or game.level_time-u.energy_warn>25) then
            u.energy_warn=game.level_time
            local line=(advisor_lines(game,game.player_team_id).left and advisor_lines(game,game.player_team_id).left.energy)
                or "%s能量不足，建议暂时脱离火线。"
            Advisor.say(game,string.format(line,u.name or "当前机体"),"failed")
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
            Slots.say(logistics.almo,(advisor_lines(game,game.enemy_team_id).right and advisor_lines(game,game.enemy_team_id).right.cheer)
            or cheer_text[logistics.almo.unit.character_id] or cheer_text.default,"praise")
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
    if a.clock>45 then
        a.clock=0
        -- 左右手周期互动（45 秒一轮，开局约 20 秒先来一次）：
        -- 优先镜像对话，两队共用同一组号、各说各队的词；
        -- 某队缺组则只让有组的一侧发言；双方都没写组才退化成普通闲聊。
        local pg=team_groups(game,game.player_team_id)
        local eg=team_groups(game,game.enemy_team_id)
        local pgc=pg and #pg.groups or 0
        local egc=eg and #eg.groups or 0
        if pgc>0 or egc>0 then
            -- 每轮只允许一侧开口（我方约 65% 优先），避免镜像位上敌我立绘/气泡重叠。
            local player_round=(egc==0) or (pgc>0 and math.random()<0.65)
            if player_round and pgc>0 then
                local gp=pg.groups[math.random(pgc)]
                Advisor.say_hand(game,"player","left",gp.left,"idle")
                Advisor.say_hand(game,"player","right",gp.right,"idle")
            elseif egc>0 then
                local ge=eg.groups[math.random(egc)]
                Advisor.say_hand(game,"enemy","left",ge.left,"idle")
                Advisor.say_hand(game,"enemy","right",ge.right,"idle")
            end
        else
            local all=game:get_units_by_team(game.player_team)
            if #all>0 then
                local u=all[math.random(#all)]
                game:report_event(u,"idle","保持警戒。")
            end
            Advisor.say(game,Pilots.line(a.unit,"idle",""),"idle")
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
-- 敌方左右手镜像位：敌右手→我方左位，敌左手→我方右位。
-- 只有被触发（嘲讽/鼓励/批评）时才出现，出场频率低于我方。
local function draw_enemy_hand(slot,side)
    if not slot or slot.life<=0 or type(slot.text)~="string" or slot.text=="" then return end
    local g=love.graphics
    local Pilots=require("ui.pilots")
    local img=Pilots.standing(slot.unit)
    if not img then return end
    local s=155/img:getHeight()
    local fade=math.min(1,slot.age*3,slot.life)
    local slide=(1-math.min(1,slot.age*3,slot.life))*110
    g.push("all")
    g.setColor(1,1,1,fade)
    if side=="left" then
        g.draw(img,343-slide,g.getHeight()-30,0,s,s,img:getWidth()/2,img:getHeight())
        g.pop()
        require("ui.comms").bubble(slot.unit,slot.text,slot.kind,410,g.getHeight()-166,310,slot.age,slot.life,48,true)
    else
        g.draw(img,g.getWidth()-70+slide,g.getHeight()-30,0,s,s,img:getWidth()/2,img:getHeight())
        g.pop()
        require("ui.comms").bubble(slot.unit,slot.text,slot.kind,g.getWidth()-440,g.getHeight()-166,310,slot.age,slot.life,48,true)
    end
end
function Advisor.draw(game)
    local research=game.researcher and game.researcher.life>0 and game.researcher.text~=""
    if research then draw_researcher(game) end
    local logistics=game.logistics or {}
    -- 槽位共享时我方优先：对应我方角色正在说话，敌方同侧暂不绘制，避免重叠。
    local player_left_busy=game.advisor and game.advisor.life>0 and game.advisor.text~=""
    local player_right_busy=game.researcher and game.researcher.life>0 and game.researcher.text~=""
    if not player_left_busy then draw_enemy_hand(logistics.almo,"left") end   -- 敌方右手→左槽位
    if not player_right_busy then draw_enemy_hand(logistics.tact,"right") end  -- 敌方左手→右槽位
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
    if a.text=="" then return end
    local offset=145
    require("ui.comms").bubble(a.unit,a.text,a.kind,x+offset,y,w-offset,a.age,a.life,48)
end
function Advisor.contains(game,mx,my)
    if game.researcher and game.researcher.life>0 and game.researcher.text~="" and mx>=love.graphics.getWidth()-440 and my>=love.graphics.getHeight()-230 then return true end
    local a=game.advisor
    return a and a.life>0 and a.text~="" and mx>=265 and mx<=715 and my>=love.graphics.getHeight()-(a.tutorial and 268 or 166) and my<=love.graphics.getHeight()-25
end
return Advisor

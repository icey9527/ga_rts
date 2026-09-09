local Economy={}
local config=require("config.economy")
local Lines=require("config.economy_lines")
local Slots=require("systems.comms_slots")
local Registry=require("systems.pack_registry")
function Economy.start(game)
    game.economy={credits=config.starting_credits,queue={},armor=0,weapons=0,open=require("systems.preferences").get("dock_open",false)}
    game.logistics=game.logistics or {}
    game.researcher={unit={unit_type="researcher",character_id=22,callsign="R&D",team=game.player_team,team_id=game.player_team_id},age=0,life=0,text="",kind="idle",team=game.player_team,role="noah",queue={}}
    game.researcher.unit.game=game
    game.logistics.player=game.researcher
    game.logistics.enemy={unit={unit_type="researcher",character_id=74,callsign="ENEMY R&D",team=1,team_id=game.enemy_team_id or game.team_id or game.player_team_id},age=0,life=0,text="",kind="idle",team=1,role="enemy",queue={}}
    game.logistics.tact={unit={unit_type="advisor",character_id=21,callsign="TACT SQUAD",team=game.player_team,team_id=game.team_id},age=0,life=0,text="",kind="idle",team=game.player_team,role="lester",queue={}}
    game.logistics.almo={unit={unit_type="advisor",character_id=26,callsign="TACT SQUAD",team=game.player_team,team_id=game.team_id},age=0,life=0,text="",kind="idle",team=game.player_team,role="almo",queue={}}
    -- 槽位挂上 game 引用：头像边框与台词阵营都依赖 unit.game 判定。
    for _,slot in pairs(game.logistics) do slot.unit.game=game end
    require("systems.minerals").start(game)
end
function Economy.toggle(game)
    local e=game.economy
    e.open=not e.open
    require("systems.preferences").set("dock_open",e.open)
    if not e.open then
        local r=game.researcher
        if r then r.life=math.min(r.life,1) end
        return
    end
    local now=love.timer.getTime()
    e.opens=(e.last_open and now-e.last_open<5) and ((e.opens or 0)+1) or 1
    e.last_open=now
    if e.opens>=3 then Economy.say(game,"open_spam","failed")
    else Economy.say(game,"open") end
    require("systems.audio").play("open")
    require("systems.advisor").event(game,"economy")
end
-- 事务性反馈（点击后的回执）立即抢槽显示，不再排队等待；寿命按事件长短区分。
local ECON_LIFE={open=6,open_spam=5,halt=6,queued=3.5,cancel=3,done=3.5,
    no_mineral=4,queue_full=4,tech_max=4,no_credits=4,mineral_refund=4}
local ECON_INSTANT={queued=true,cancel=true,done=true,mineral_refund=true,
    no_mineral=true,queue_full=true,tech_max=true,no_credits=true}
-- key 取角色 dialogue.lua 的 economy 段或 config/economy_lines.lua 的事件名，按当前后勤角色的口吻播报。
-- 口吻解析顺序：角色 dialogue.lua 的 economy 段（队伍包自带）→ economy_lines 兜底 → 不播。
function Economy.say(game,key,kind,label)
    local r=game.researcher
    local u=r and r.unit
    local text
    if u then
        local dlg=require("ui.pilots").dialogue(u)
        text=dlg and dlg.economy and dlg.economy[key]
    end
    if not text then
        local id=(u and u.character_id) or 22
        local set=Lines[id] or Lines.default
        text=set and set[key]
    end
    if not text then return end
    -- 前缀直接相连且去掉行首空格：CJK 下带空格会让换行把"完成"整句挤到第二行。
    if label then text=label..(text:gsub("^%s+","")) end
    local life=ECON_LIFE[key] or 4
    if ECON_INSTANT[key] and r and (r.age>=1 or #(r.queue or {})>0) then
        Slots.replace(r,text,kind,life)
    else
        Slots.say(r,text,kind,life)
    end
end
function Economy.say_logistics(game,slot,text,kind)
    Slots.say(game.logistics and game.logistics[slot],text,kind)
end
function Economy.apply(game,u)
    local e=game.economy
    if not e or u.team~=game.player_team then return end
    local old=u.tech_armor or 0
    if old~=e.armor then
        local previous=u.max_hp
        u.max_hp=math.floor(u.max_hp/(1+old*0.2)*(1+e.armor*0.2))
        u.hp=math.min(u.max_hp,u.hp+(u.max_hp-previous))
        u.tech_armor=e.armor
    end
    local level=u.tech_weapons or 0
    if level~=e.weapons then
        u.base_attack_damage=u.base_attack_damage/(1+level*0.15)*(1+e.weapons*0.15)
        u.tech_weapons=e.weapons
        u:_recalc_stats()
    end
end
function Economy.enqueue(game,id)
    local e=game.economy
    if not e then return false end
    if not game:get_mothership(game.player_team) then Economy.say(game,"halt","failed"); return false end
    local action
    for _,a in ipairs(config.actions) do if a.id==id then action=a end end
    if not action then return false end
    if id=="collector" then
        local available=0
        for _,node in ipairs(game.minerals or {}) do if node.remaining>0 and (not node.station or not node.station.alive) then available=available+1 end end
        for _,job in ipairs(e.queue) do if job.action.id=="collector" then available=available-1 end end
        if available<=0 then Economy.say(game,"no_mineral","failed");return false end
    end
    if #e.queue>=config.max_queue then Economy.say(game,"queue_full","failed"); return false end
    local pending=0
    for _,job in ipairs(e.queue) do if job.action.id==id then pending=pending+1 end end
    if action.tech and e[id]+pending>=action.max then Economy.say(game,"tech_max","failed"); return false end
    if e.credits<action.cost then Economy.say(game,"no_credits","failed"); return false end
    e.credits=e.credits-action.cost
    e.queue[#e.queue+1]={action=action,remaining=action.time}
    require("systems.advisor").event(game,action.tech and "research" or (id=="collector" and "collect" or "recruit"))
    Economy.say(game,"queued",nil,action.label)
    return true
end
function Economy.cancel(game,index)
    local e=game.economy
    local job=e and e.queue[index]
    if not job then return false end
    e.credits=e.credits+job.action.cost
    table.remove(e.queue,index)
    Economy.say(game,"cancel")
    return true
end
function Economy.update(game,dt)
    local e=game.economy
    if not e then return end
    local ms=game:get_mothership(game.player_team)
    if not ms then
        if #e.queue>0 then
            for _,job in ipairs(e.queue) do e.credits=e.credits+job.action.cost end
            e.queue={}
            Economy.say(game,"halt","failed")
        end
        return
    end
    e.credits=e.credits+config.income*dt+require("systems.minerals").update(game,dt)
    local job=e.queue[1]
    if not job then return end
    job.remaining=job.remaining-dt
    if job.remaining>0 then return end
    local a=job.action
    if a.tech then
        e[a.id]=e[a.id]+1
        for _,u in ipairs(game.units) do Economy.apply(game,u) end
        require("systems.audio").play("build")
    else
        local kind=a.unit
        if kind=="random" then
            local pool={"light","sniper","artillery","tiger","fighter","repair"}
            kind=pool[math.random(#pool)]
        end
        local cfg=require("levels.manager").unit_config(kind)
        local angle=(game.next_unit_id or 0)*2.39996
        local x,y=game:find_clear_position(ms.x+math.cos(angle)*230,ms.y+math.sin(angle)*230,30)
        local node=kind=="collector" and require("systems.minerals").available(game) or nil
        if kind=="collector" and not node then
            e.credits=e.credits+a.cost;table.remove(e.queue,1);Economy.say(game,"mineral_refund","failed");return
        end
        if node then x,y=node.x,node.y end
        if game:is_position_blocked(x,y,30,0) then job.remaining=1; return end
        local u=require("entities.unit").new(x,y,game.player_team,cfg)
        -- 地图内同一角色只出现一次：优先从本单位阵营队伍与混池中选未上场驾驶员。
        local Pilots=require("ui.pilots")
        local pool=Pilots.team_pool({game.player_team_id or Registry.default_player(),"default"})
        local used={}
        for _,other in ipairs(game.units) do
            if other.alive and other~=u and other.character_id then used[other.character_id]=true end
        end
        local candidates,fallback={},{}
        for _,id in ipairs(pool) do
            if not used[id] then candidates[#candidates+1]=id else fallback[#fallback+1]=id end
        end
        if #candidates>0 then u.character_id=candidates[math.random(#candidates)]
        elseif #fallback>0 then u.character_id=fallback[math.random(#fallback)] end
        game:add_unit(u)
        if node then node.station=u;u.mineral_node=node end
        require("systems.audio").play("reinforce")
        require("systems.cinematic").reinforcement(game,u)
    end
    table.remove(e.queue,1)
    Economy.say(game,"done","praise",a.label)
end
return Economy

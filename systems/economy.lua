local Economy={}
local config=require("config.economy")
local Lines=require("config.economy_lines")
local Slots=require("systems.comms_slots")
function Economy.start(game)
    game.economy={credits=config.starting_credits,queue={},armor=0,weapons=0,open=require("systems.preferences").get("dock_open",false)}
    game.logistics=game.logistics or {}
    game.researcher={unit={unit_type="researcher",character_id=22,callsign="R&D",team=game.player_team},age=0,life=0,text="",kind="idle",team=game.player_team,role="noah",queue={}}
    game.researcher.unit.game=game
    game.logistics.player=game.researcher
    game.logistics.enemy={unit={unit_type="researcher",character_id=74,callsign="ENEMY R&D",team=1},age=0,life=0,text="",kind="idle",team=1,role="enemy",queue={}}
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
-- key 取 config/economy_lines.lua 的事件名，按当前后勤角色的口吻播报。
function Economy.say(game,key,kind,label)
    local id=(game.researcher and game.researcher.unit and game.researcher.unit.character_id) or 22
    local set=Lines[id] or Lines[22]
    local text=set[key] or key
    if label then text=label..text end
    Slots.say(game.researcher,text,kind)
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
        local pool=Pilots.team_pool({game.player_team_id or "rune","default"})
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
    end
    table.remove(e.queue,1)
    Economy.say(game,"done","praise",a.label)
end
return Economy

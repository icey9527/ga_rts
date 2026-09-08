local Economy={}
local config=require("config.economy")
function Economy.start(game)
    game.economy={credits=config.starting_credits,queue={},armor=0,weapons=0,open=require("systems.preferences").get("dock_open",false)}
    game.logistics=game.logistics or {}
    game.researcher={unit={unit_type="researcher",character_id=22,callsign="R&D"},age=0,life=0,text="",kind="idle",team=game.player_team,role="noah"}
    game.logistics.player=game.researcher
    game.logistics.enemy={unit={unit_type="researcher",character_id=74,callsign="ENEMY R&D"},age=0,life=0,text="",kind="idle",team=1,role="enemy"}
    game.logistics.tact={unit={unit_type="advisor",character_id=21,callsign="TACT SQUAD"},age=0,life=0,text="",kind="idle",team=game.player_team,role="lester"}
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
    if e.opens>=3 then Economy.say(game,"卡兹亚，你是在调配舰队，还是在测试面板的开合寿命？","failed")
    else Economy.say(game,"卡兹亚，这次要增援、采集站，还是改进火控？想好再把资源交给我。") end
    require("systems.audio").play("open")
    require("systems.advisor").event(game,"economy")
end
function Economy.say(game,text,kind)
    local r=game.researcher
    if r then r.text,r.kind,r.age,r.life=text,kind or "idle",0,8 end
end
function Economy.say_logistics(game,slot,text,kind)
    local r=game.logistics and game.logistics[slot]
    if r then r.text,r.kind,r.age,r.life=text,kind or "idle",0,8 end
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
    if not game:get_mothership(game.player_team) then Economy.say(game,"生产中心已失去联系。先保住母舰，再谈技术。","failed"); return false end
    local action
    for _,a in ipairs(config.actions) do if a.id==id then action=a end end
    if not action then return false end
    if id=="collector" then
        local available=0
        for _,node in ipairs(game.minerals or {}) do if node.remaining>0 and (not node.station or not node.station.alive) then available=available+1 end end
        for _,job in ipairs(e.queue) do if job.action.id=="collector" then available=available-1 end end
        if available<=0 then Economy.say(game,"没有空闲矿脉。先保护现有采集站。","failed");return false end
    end
    if #e.queue>=config.max_queue then Economy.say(game,"队列已经排满。先让现有项目完成。","failed"); return false end
    local pending=0
    for _,job in ipairs(e.queue) do if job.action.id==id then pending=pending+1 end end
    if action.tech and e[id]+pending>=action.max then Economy.say(game,"该项研究已经达到设计上限。","failed"); return false end
    if e.credits<action.cost then Economy.say(game,"资源不足。这种基础计算也需要我提醒？","failed"); return false end
    e.credits=e.credits-action.cost
    e.queue[#e.queue+1]={action=action,remaining=action.time}
    require("systems.advisor").event(game,action.tech and "research" or (id=="collector" and "collect" or "recruit"))
    Economy.say(game,action.label.." 已排期。资源不会白花，前提是你别乱指挥。")
    return true
end
function Economy.cancel(game,index)
    local e=game.economy
    local job=e and e.queue[index]
    if not job then return false end
    e.credits=e.credits+job.action.cost
    table.remove(e.queue,index)
    Economy.say(game,"项目取消，资源已退回。下次先想清楚。")
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
            Economy.say(game,"母舰失联。项目终止，未完成项目的资源已退回。","failed")
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
            e.credits=e.credits+a.cost;table.remove(e.queue,1);Economy.say(game,"矿脉已经占用，建设资源退回。","failed");return
        end
        if node then x,y=node.x,node.y end
        if game:is_position_blocked(x,y,30,0) then job.remaining=1; return end
        local u=require("entities.unit").new(x,y,game.player_team,cfg)
        local pool={26,27,28,29,30,32,33,34,35,36,37,38,39,42,43,45,46,50,51,52,53,54,55,56,57,75,76,87}
        local available=require("ui.pilots").available()
        local candidates={}
        for _,id in ipairs(pool) do if available[id] then candidates[#candidates+1]=id end end
        if #candidates>0 then u.character_id=candidates[math.random(#candidates)] end
        game:add_unit(u)
        if node then node.station=u;u.mineral_node=node end
    end
    table.remove(e.queue,1)
    Economy.say(game,a.label.." 完成。现在，让我看看你能发挥多少价值。","praise")
end
return Economy

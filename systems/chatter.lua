local Chatter={}
local exchanges=require("dialogue.exchanges")
local function broadcast(game,u,text)
    game.reports=game.reports or {}
    if #game.reports>=3 then table.remove(game.reports,1) end
    game.reports[#game.reports+1]={unit=u,kind="idle",text=text,age=0,life=6}
end
function Chatter.interact(game,u,action,target)
    if not u or not u.alive then return end
    local now=game.level_time
    local state=u.interaction or {count=0,last=-100,spoken=-100}
    u.interaction=state
    state.count=now-state.last<18 and state.count+1 or 1
    state.last=now
    if action=="follow" then u.chatter_partner=target end
    if state.count>=4 and now-state.spoken>60 and not require("systems.mission_script").busy(game) then
        state.spoken=now;state.count=0
        game:report_event(u,"interaction","")
    end
end
function Chatter.update(game,dt)
    if game:is_paused() or require("systems.mission_script").busy(game) or game.cinematic then return end
    game.chatter_time=(game.chatter_time or 0)+dt
    if game.chatter_reply then
        local r=game.chatter_reply;r.delay=r.delay-dt
        if r.delay<=0 then if r.unit.alive and r.text then broadcast(game,r.unit,r.text) end;game.chatter_reply=nil end
    end
    local pairs={}
    for _,u in ipairs(game.units) do
        if u.alive and u.follow_target and u.follow_target.alive then pairs[#pairs+1]={u,u.follow_target} end
    end
    if game.chatter_time<(#pairs>0 and 40 or 65) or #(game.reports or {})>1 then return end
    game.chatter_time=0
    game.exchange_times=game.exchange_times or {}
    local by_id={}
    for _,u in ipairs(game.units) do if u.alive and u.character_id then by_id[u.character_id]=u end end
    local options={}
    for i,e in ipairs(exchanges) do
        if by_id[e.from] and by_id[e.to] and game.level_time-(game.exchange_times[i] or -1000)>120 then
            local weight=1
            for _,pair in ipairs(pairs) do
                if (pair[1].character_id==e.from and pair[2].character_id==e.to) or (pair[1].character_id==e.to and pair[2].character_id==e.from) then weight=6 end
            end
            for _=1,weight do options[#options+1]={index=i,line=e} end
        end
    end
    if #options>0 then
        local option=options[math.random(#options)];local e=option.line
        game.exchange_times[option.index]=game.level_time
        broadcast(game,by_id[e.from],e.question)
        game.chatter_reply={unit=by_id[e.to],text=e.answer,delay=3.2}
    elseif #pairs>0 then
        local pair=pairs[math.random(#pairs)]
        game:report_event(pair[1],"follow","")
        game.chatter_reply={unit=pair[2],text=require("ui.pilots").line(pair[2],"follow_reply",""),delay=3.2}
    else
        local u=game.units[math.random(math.max(1,#game.units))]
        if u and u.alive then game:report_event(u,u.state=="moving" and "move" or "idle","保持警戒。") end
    end
end
return Chatter

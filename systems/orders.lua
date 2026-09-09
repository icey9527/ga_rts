local Orders = {}
function Orders.issue(game,units,action,target,x,y)
    local accepted=0
    local cols=math.ceil(math.sqrt(#units))
    local spacing=48
    for _,u in ipairs(units) do spacing=math.max(spacing,u.radius*2.5) end
    for i,u in ipairs(units) do
        local valid=u.alive and u.team==game.player_team and u.state~="disabled" and u.unit_type~="collector" and not u.objective_ship
        if action=="attack" then valid=valid and u.attack_damage>0 and (not target or target.team~=u.team)
        elseif action=="follow" then valid=valid and target and target.alive and target.team==u.team and target~=u
        elseif action=="repair" then valid=valid and target and target.alive and target.team==u.team and target~=u and target.hp<target.max_hp and (u.unit_type=="repair" or u.unit_type=="mothership")
        elseif action~="move" then valid=false end
        if valid then
            u.attack_target,u.follow_target,u.repair_target,u.target_pos,u.attack_move=nil,nil,nil,nil,nil
            u.burst_queue={}
            u.route=nil
            u.manual_order=true
            u.state_timer=0
            if action=="move" or (action=="attack" and not target) then
                local dx=((i-1)%cols-(cols-1)/2)*spacing
                local dy=(math.floor((i-1)/cols)-(math.ceil(#units/cols)-1)/2)*spacing
                u.target_pos={x+dx,y+dy}
                u.state="moving"
                if action=="attack" then u.attack_move={x+dx,y+dy} end
            elseif action=="attack" then u.attack_target=target; u.state="attacking"
            elseif action=="follow" then u.follow_target=target; u.state="following"
            elseif action=="repair" then u.repair_target=target; u.state="repairing" end
            accepted=accepted+1
        end
    end
    if units[1] then
        game:report_event(units[1],accepted>0 and "command" or "failed",accepted>0 and "收到指令，正在执行。" or "无法执行，请重新指定有效目标。")
    end
    if accepted>0 then
        require("systems.advisor").event(game,action)
        require("systems.audio").play("confirm")
        -- 指挥确认由左手播报（类比右手负责资源面板）；未绑定角色或槽位忙时静默防刷屏。
        if game.advisor and game.advisor.unit.character_id then
            local Pilots=require("ui.pilots")
            local line=Pilots.line(game.advisor.unit,"command","")
            if line and line~="" and (not game.advisor.life or game.advisor.life<=0 or game.advisor.text=="") then
                require("systems.comms_slots").say(game.advisor,line,"command",3.5)
            end
        end
    end
    if accepted==0 then
        game.bad_orders=(game.bad_orders or 0)+1
        require("systems.audio").play("error")
        if game.bad_orders%3==0 then
            -- 呼唤的是玩家指挥官（母舰角色），不是说话的左手自己。
            local Pilots=require("ui.pilots")
            local Registry=require("systems.pack_registry")
            local cid=tonumber((Registry.load(game.player_team_id).team or {}).commander)
            local name=(cid and Pilots.profile({character_id=cid,team_id=game.player_team_id}).name) or "指挥官"
            require("systems.advisor").say(game,"连续三次无效指令。"..name.."，先看清目标，别拿大家的命试按钮。","failed")
        end
    end
    return accepted
end
return Orders

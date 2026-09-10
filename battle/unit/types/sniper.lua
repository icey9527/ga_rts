-- Forward-flight passes use fixed, per-unit waypoints instead of mutually moving orbit centers.
local Sniper={}
function Sniper.update(unit,dt,game)
    if unit.state~="attacking" and unit.state~="circle_strafing" then
        unit.sniper_pass=nil;unit.sniper_home=nil;unit.sniper_escape=nil;unit._approach_speed_multiplier=nil
    end
end
function Sniper.fly(unit,dt,game)
    local target=unit.attack_target
    if not require("battle.unit.targeting").is_valid_enemy(unit,target) then return false end
    unit.state="attacking"
    local cfg=unit.behavior_config or {}
    local enter=cfg.retreat_distance or unit.attack_range*0.48
    local safe=math.max(enter+80,cfg.safe_distance or unit.attack_range*0.70)
    -- React to the nearest threat, even if a different distant enemy remains locked.
    local threat=unit:find_nearest_enemy(game,enter)
    if not threat and unit:distance_to(target)<enter then threat=target end
    local escape=unit.sniper_escape
    if threat and not escape then
        escape={threat=threat,time=0};unit.sniper_escape=escape
        unit.sniper_pass=nil;unit.route=nil
    end
    if escape then
        if threat and (not escape.threat.alive or unit:distance_to(threat)+80<unit:distance_to(escape.threat)) then
            escape.threat=threat;escape.time=0
        end
        local danger=escape.threat
        if not threat and (not danger.alive or unit:distance_to(danger)>=safe) then
            unit.sniper_escape=nil;unit.route=nil
        else
            escape.time=escape.time-dt
            if escape.time<=0 or not escape.x or unit:dist_to_pos(escape.x,escape.y)<50 then
                local dx,dy=unit.x-danger.x,unit.y-danger.y
                local distance=math.sqrt(dx*dx+dy*dy)
                if distance<1 then dx,dy=math.cos(unit.angle),math.sin(unit.angle);distance=1 end
                local reach=math.max(240,safe-distance+160)
                -- A little lateral offset avoids retracing the attack line, without strafing.
                escape.x=unit.x+(dx/distance-dy/distance*unit.circle_direction*0.25)*reach
                escape.y=unit.y+(dy/distance+dx/distance*unit.circle_direction*0.25)*reach
                escape.time=cfg.escape_replan_interval or 0.8
            end
            local boost=cfg.escape_speed_multiplier or 1.7
            unit._approach_speed_multiplier=boost
            unit:_move_towards(escape.x,escape.y,unit.speed*boost*dt,game)
            return true
        end
    end
    local home=unit.sniper_home
    if not home or home.target~=target then
        home={target=target,x=(unit.x+target.x)/2,y=(unit.y+target.y)/2}
        unit.sniper_home=home
    end
    -- Fixed engagement center prevents two avoidance maneuvers from translating forever.
    local radius=unit.attack_range*0.8
    if target:dist_to_pos(home.x,home.y)>unit.attack_range*2 then
        home.x,home.y=(unit.x+target.x)/2,(unit.y+target.y)/2
        home.returning=false
    end
    local from_home=unit:dist_to_pos(home.x,home.y)
    if from_home>radius then home.returning=true end
    if from_home<radius*0.55 then home.returning=false end
    local pass=unit.sniper_pass
    -- Finish the turn before the next shot is ready, instead of wandering through a firing window.
    local next_shot=math.huge
    for _,weapon in ipairs(unit.weapons) do next_shot=math.min(next_shot,weapon.cooldown_timer or 0) end
    if pass and next_shot<0.9 then pass=nil;unit.sniper_pass=nil end
    if pass and (pass.target~=target or pass.time<=0) then pass=nil;unit.sniper_pass=nil end
    local x,y=target.x,target.y
    if pass then
        pass.time=pass.time-dt;x,y=pass.x,pass.y
        if unit:dist_to_pos(x,y)<40 then unit.sniper_pass=nil end
    end
    if home.returning then x,y=home.x,home.y;unit.sniper_pass=nil end
    local far=unit:distance_to(target)>unit.attack_range
    unit._approach_speed_multiplier=far and 1.35 or nil
    unit:_move_towards(x,y,unit.speed*(far and 1.35 or 1)*dt,game)
    if unit:_try_attack(game) and not home.returning then
        local angle=unit.angle+unit.circle_direction*0.55
        local length=math.min(320,unit.attack_range*0.24)
        unit.sniper_pass={target=target,time=2,x=unit.x+math.cos(angle)*length,y=unit.y+math.sin(angle)*length}
    elseif not pass and next_shot>0.9 and not home.returning and unit:distance_to(target)<unit.attack_range*0.25 then
        local angle=unit.angle+unit.circle_direction
        unit.sniper_pass={target=target,time=1.5,x=unit.x+math.cos(angle)*220,y=unit.y+math.sin(angle)*220}
    end
    return true
end
return Sniper

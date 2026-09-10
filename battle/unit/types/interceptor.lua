-- High-speed intercept passes: commit to the fly-through before turning back.
local Interceptor={}
local Targeting=require("battle.unit.targeting")

function Interceptor.update(unit,dt,game)
    if (unit.state~="attacking" and unit.state~="circle_strafing")
       or not Targeting.is_valid_enemy(unit,unit.attack_target) then
        unit.intercept_pass=nil;unit._approach_speed_multiplier=nil
    end
end

function Interceptor.fly(unit,dt,game)
    local target=unit.attack_target
    if not Targeting.is_valid_enemy(unit,target) then return false end
    local cfg=unit.behavior_config
    unit.state="attacking"
    local pass=unit.intercept_pass
    if pass and (pass.target~=target or pass.time<=0 or unit:dist_to_pos(pass.x,pass.y)<35) then
        pass=nil;unit.intercept_pass=nil;unit.route=nil
    end
    local distance=unit:distance_to(target)
    local x,y=target.x,target.y
    local boost=distance>unit.attack_range and (cfg.approach_boost or 1.45) or 1
    if pass then
        pass.time=pass.time-dt;x,y=pass.x,pass.y
    else
        local lead=math.min(cfg.lead_time or 0.45,distance/math.max(unit.speed,1)*0.2)
        x=x+(target.vx or 0)*lead;y=y+(target.vy or 0)*lead
    end
    unit._approach_speed_multiplier=boost
    unit:_move_towards(x,y,unit.speed*boost*dt,game)
    local fired=unit:_try_attack(game)
    -- A successful burst or an imminent close pass establishes one fixed waypoint.
    -- Do not regenerate it on each projectile, which would prevent the return turn.
    if not pass and (fired or distance<(cfg.break_distance or 85)) then
        local length=cfg.pass_length or 270
        local angle=unit.angle+unit.circle_direction*(cfg.pass_angle or 0.25)
        unit.intercept_pass={target=target,time=cfg.pass_time or 1.0,
            x=unit.x+math.cos(angle)*length,y=unit.y+math.sin(angle)*length}
    end
    return true
end
return Interceptor

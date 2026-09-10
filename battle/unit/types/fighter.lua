-- Medium-range attack runs with bounded repositioning; no perpetual close orbit.
local Fighter={}
local Targeting=require("battle.unit.targeting")
local Weapons=require("battle.unit.weapons")

function Fighter.update(unit,dt,game)
    if unit.state~="attacking"
       or not Targeting.is_valid_enemy(unit,unit.attack_target) then
        unit.fighter_pass=nil;unit._approach_speed_multiplier=nil
    end
end

function Fighter.fly(unit,dt,game)
    local target=unit.attack_target
    if not Targeting.is_valid_enemy(unit,target) then return false end
    local cfg=unit.behavior_config
    local distance=unit:distance_to(target)
    unit.state="attacking"
    local pass=unit.fighter_pass
    if pass and (pass.target~=target or pass.time<=0 or unit:dist_to_pos(pass.x,pass.y)<25) then
        pass=nil;unit.fighter_pass=nil;unit.route=nil
    end
    local primary_ready=false
    for _,weapon in ipairs(unit.weapons) do
        if weapon.id=="main" and (weapon.cooldown_timer or 0)<0.35 and Weapons.can_fire(weapon) then primary_ready=true end
    end
    -- Finish a normal reposition as the main gun recovers, but finish a close escape first.
    if pass and not pass.escape and primary_ready then pass=nil;unit.fighter_pass=nil end
    local close=cfg.break_distance or 130
    if not pass and distance<close then
        local dx,dy=unit.x-target.x,unit.y-target.y
        local len=math.sqrt(dx*dx+dy*dy)
        if len<1 then dx,dy=math.cos(unit.angle),math.sin(unit.angle);len=1 end
        local reach=cfg.reposition_distance or 160
        pass={target=target,escape=true,time=cfg.escape_time or 1.3,
            x=unit.x+dx/len*reach-dy/len*reach*0.4*unit.circle_direction,
            y=unit.y+dy/len*reach+dx/len*reach*0.4*unit.circle_direction}
        unit.fighter_pass=pass
    end
    local x,y=target.x,target.y
    if pass then pass.time=pass.time-dt;x,y=pass.x,pass.y end
    local boost=distance>unit.attack_range and (cfg.approach_boost or 1.15) or 1
    unit._approach_speed_multiplier=boost
    unit:_move_towards(x,y,unit.speed*boost*dt,game)
    if unit:_try_attack(game) and not pass then
        local angle=unit.angle+unit.circle_direction*(cfg.reposition_angle or 0.8)
        local length=cfg.reposition_distance or 160
        unit.fighter_pass={target=target,time=cfg.reposition_time or 0.65,
            x=unit.x+math.cos(angle)*length,y=unit.y+math.sin(angle)*length}
    end
    return true
end
return Fighter

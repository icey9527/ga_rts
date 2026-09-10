local Projectile={}
local atan2=math.atan2 or function(y,x) return math.atan(y,x) end

function Projectile.spawn(unit,game,target,index,total,weapon)
    local P=require("entities.projectile")
    weapon=weapon or {}
    local range=weapon.range or unit.attack_range
    if target and unit:distance_to(target)<(weapon.min_range or 0) then return end
    if not unit.alive or not target or not target.alive or unit.state=="disabled" or target.team==unit.team or unit:distance_to(target)>range+20 then return end
    if weapon.arc and not require("battle.unit.targeting").in_weapon_arc(unit,weapon,target) then return end
    local visual=weapon.visual or unit.weapon_visual
    local speed=weapon.projectile_speed or unit.projectile_speed
    local kind=weapon.type or unit.attack_type
    unit.muzzle_time=game.level_time
    local sx,sy=unit.x,unit.y
    if visual=="interceptor_tracer" or visual=="tiger_cannon" then
        local side=((index%2)==0 and -1 or 1)*(unit.radius or 11)*0.75
        sx,sy=unit.x-math.sin(unit.angle)*side,unit.y+math.cos(unit.angle)*side
    end
    local angle_off=total>1 and (index-(total-1)/2)*(weapon.spread_angle or unit.spread_angle or 0.16) or 0
    local base=atan2(target.y-unit.y,target.x-unit.x)
    local dist=math.max(120,unit:distance_to(target));local pacing=require("config.pacing")
    local flight=math.min(1.8,dist/math.max(1,speed))*pacing.lead_fraction
    local spread=pacing.spread_pixels*(1-(unit.accuracy or 0.78))+(target.evasion or 0.12)*20
    local error_angle=math.random()*math.pi*2;local error_radius=math.random()*spread
    local tx=target.x+(target.vx or 0)*flight+math.cos(error_angle)*error_radius+math.cos(base+math.pi/2)*angle_off*(unit.target_spread or 120)
    local ty=target.y+(target.vy or 0)*flight+math.sin(error_angle)*error_radius+math.sin(base+math.pi/2)*angle_off*(unit.target_spread or 120)
    local dmg=math.max(1,math.floor((weapon.damage or unit.attack_damage)/math.max(1,total)))
    if kind=="beam" then
        target:take_damage(dmg,unit)
        game:add_effect(require("entities.effect").beam(unit.x,unit.y-(unit.z or 0)*0.22,target.x,target.y-(target.z or 0)*0.22))
    elseif kind=="missile" then
        game:add_projectile(P.missile(sx,sy,target,dmg,speed,unit.z or 0,visual,unit))
    elseif kind=="artillery" then
        game:add_projectile(P.artillery(sx,sy,tx,ty,dmg,weapon.splash_radius or unit.splash_radius,speed,unit.z or 0,unit.team,visual,unit))
    else
        game:add_projectile(P.basic(sx,sy,tx,ty,dmg,speed,target,unit.z or 0,visual,unit))
    end
    return true
end

return Projectile

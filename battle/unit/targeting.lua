local Targeting={}

function Targeting.is_valid_enemy(unit,target)
    return target and target.alive and target.state~="dead" and target.team~=unit.team
end

function Targeting.in_range(unit,target,extra)
    return Targeting.is_valid_enemy(unit,target)
        and unit:distance_to(target)<=unit.attack_range+(extra or 0)
end

function Targeting.relative_angle(unit,target)
    local a=math.atan2(target.y-unit.y,target.x-unit.x)
    return (a-(unit.angle or 0)+math.pi)%(math.pi*2)-math.pi
end

function Targeting.in_weapon_arc(unit,weapon,target)
    if not Targeting.is_valid_enemy(unit,target) then return false end
    if weapon.can_hit_rear or weapon.direction=="all" then return true end
    local arc=math.rad(weapon.arc or 90)
    local angle=Targeting.relative_angle(unit,target)
    if weapon.direction=="rear" then return math.abs(math.abs(angle)-math.pi)<=arc/2 end
    if weapon.direction=="side" then return math.abs(angle)>arc/2 and math.abs(angle)<math.pi-arc/2 end
    return math.abs(angle)<=arc/2
end

function Targeting.nearest_enemy(unit,game,max_range)
    local best,best_dist=nil,math.huge
    for _,enemy in ipairs(game:get_enemy_units(unit.team)) do
        local d=unit:distance_to(enemy)
        if Targeting.is_valid_enemy(unit,enemy) and (not max_range or d<=max_range) and d<best_dist then
            best,best_dist=enemy,d
        end
    end
    return best
end

return Targeting

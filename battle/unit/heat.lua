local Heat={}

function Heat.initialize(weapons)
    for _,weapon in ipairs(weapons or {}) do
        weapon.heat=weapon.heat or 0
        weapon.max_heat=weapon.max_heat or 0
        weapon.heat_per_shot=weapon.heat_per_shot or 0
        weapon.cool_rate=weapon.cool_rate or 0
        weapon.overheated=weapon.overheated or false
    end
end

function Heat.update(weapons,dt)
    for _,weapon in ipairs(weapons or {}) do
        if (weapon.cool_rate or 0)>0 then weapon.heat=math.max(0,(weapon.heat or 0)-weapon.cool_rate*dt) end
        if weapon.overheated and (weapon.heat or 0)<=math.max(0,(weapon.max_heat or 0)*0.35) then weapon.overheated=false end
    end
end

function Heat.can_fire(weapon)
    return not weapon.overheated and ((weapon.max_heat or 0)<=0 or (weapon.heat or 0)<weapon.max_heat)
end

function Heat.consume(weapon,shots)
    local gain=(weapon.heat_per_shot or 0)*(shots or 1)
    if (weapon.max_heat or 0)<=0 then return true end
    weapon.heat=math.min(weapon.max_heat,(weapon.heat or 0)+gain)
    if weapon.heat>=weapon.max_heat then weapon.overheated=true end
    return true
end

return Heat

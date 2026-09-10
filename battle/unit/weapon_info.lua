local Info={}

local names={
    main="主炮",cannon="主炮",machine_gun="机枪",secondary="副武器",
    sniper_rifle="狙击枪",missile="导弹",artillery="炮击",beam="光束",
}

function Info.list(unit)
    local result={}
    for _,weapon in ipairs(unit.weapons or {}) do
        result[#result+1]={
            id=weapon.id or "main",
            name=weapon.name or names[weapon.id or "main"] or "武器",
            type=weapon.type or "ranged",
            range=weapon.range or unit.attack_range,
            damage=weapon.damage or unit.attack_damage,
            count=weapon.count or weapon.projectile_count or unit.projectile_count,
            cooldown=weapon.cooldown or unit.attack_cooldown,
            heat=weapon.heat or 0,
            max_heat=weapon.max_heat or 0,
            heat_per_shot=weapon.heat_per_shot or 0,
            cool_rate=weapon.cool_rate or 0,
            arc=weapon.arc or 100,
            direction=weapon.direction or "front",
            visual=weapon.visual or weapon.id or "main_gun",
        }
    end
    return result
end

return Info

-- 轨道轰击：指定敌人周围的预定范围打击，命中按目标实际位置计算。
local Orbital = {}
local Pacing = require("config.pacing")

Orbital.orbital_bombardment = {
    label = "轨道轰击",
    target_mode = "enemy",
    can_execute = function(u, game)
        local sd = u.skill_data or {}
        local t = u.skill_target or u.attack_target
        return t and t.alive and t.team~=u.team and u:distance_to(t) <= (sd.range or 1500)
    end,
    execute = function(u, game)
        local sd = u.skill_data
        local t = u.skill_target or u.attack_target
        local x, y = t.x, t.y
        local radius = sd.radius or 300
        local damage = sd.damage or math.floor(350*Pacing.damage_multiplier)
        for _, enemy in ipairs(game:get_enemy_units(u.team)) do
            if (enemy.x-x)^2+(enemy.y-y)^2 <= radius^2 then enemy:take_damage(damage,u) end
        end
        game:add_effect(require("entities.effect").explosion(x, y-(t.z or 0)*0.22, radius))
        u.skill_target=nil
    end,
}

return Orbital

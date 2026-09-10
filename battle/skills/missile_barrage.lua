-- 导弹齐射：对射程内敌人轮番锁定发射追踪弹。
-- 技能弹药 no_sp，不参与伤害回充，防止必杀自充循环。
local Barrage = {}

Barrage.missile_barrage = {
    label = "导弹齐射",
    target_mode = "self",
    can_execute = function(u, game)
        local sd = u.skill_data or {}
        local range = sd.range or 900
        for _, enemy in ipairs(game.units) do
            if enemy.team ~= u.team and enemy.alive and enemy.state ~= "dead"
               and u:distance_to(enemy) <= range then
                return true
            end
        end
        return false
    end,
    execute = function(u, game)
        local sd = u.skill_data
        local Projectile = require("entities.projectile")
        local count = sd.count or 8
        local dmg = sd.damage or u.attack_damage
        local range = sd.range or 900
        local enemies = {}
        for _, enemy in ipairs(game.units) do
            if enemy.team ~= u.team and enemy.alive and enemy.state ~= "dead"
               and u:distance_to(enemy) <= range then
                enemies[#enemies+1] = enemy
            end
        end
        for i = 1, count do
            if #enemies == 0 then break end
            local target = enemies[((i - 1) % #enemies) + 1]
            local p = Projectile.missile(u.x, u.y, target, dmg, sd.projectile_speed or 260, u.z or 0, "missile", u)
            p.no_sp = true
            game:add_projectile(p)
        end
        game:add_effect(require("entities.effect").skill_flash(u.x, u.y, math.min(range, 420), {1, 0.55, 0.1}))
    end,
}

return Barrage

-- 蓄力贯穿狙击：蓄力时锁定方向，释放后沿整段直线结算；
-- 目标可以在蓄力期间移出火线（快照判定）。
local Beam = {}
local Registry = require("battle.skills.registry")
local Pacing = require("config.pacing")

Beam.charge_beam = {
    label = "贯穿狙击",
    target_mode = "enemy",
    can_execute = Registry.aimed_can_execute,
    prepare = Registry.aimed_prepare,
    execute = function(u, game)
        local sd = u.skill_data
        local aim = u.skill_aim
        if not aim then
            local t = u.skill_target or u.attack_target
            if not t then return end
            aim = {x=t.x, y=t.y, z=t.z or 0}
        end
        local dx, dy = aim.x-u.x, aim.y-u.y
        local d = math.max(1, math.sqrt(dx*dx+dy*dy))
        local range = sd.range or 1600
        local bx, by = u.x+dx/d*range, u.y+dy/d*range
        local damage = sd.damage or math.floor(650*Pacing.damage_multiplier)
        local width = (sd.width or 35)
        for _, enemy in ipairs(game:get_enemy_units(u.team)) do
            if Registry.distance(enemy.x, enemy.y, u.x, u.y, bx, by) <= width+enemy.radius then
                enemy:take_damage(damage, u)
            end
        end
        game:add_effect(require("entities.effect").charged_beam(
            u.x, u.y-(u.z or 0)*0.22, bx, by-aim.z*0.22))
        u.skill_target=nil; u.skill_aim=nil
    end,
}

return Beam

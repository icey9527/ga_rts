-- 旧配置技能的兼容实现：damage_aoe / heal_aoe / repair_all / disable / teleport。
-- 这些类型不在当前正式机体表里，仅保证旧关卡与验证脚本可运行；
-- 后续按需迁入正式模块或随关卡数据清理淘汰。
local Legacy = {}
local Pacing = require("config.pacing")
local Effect = require("entities.effect")

Legacy.damage_aoe = {
    label = "范围爆破",
    target_mode = "self",
    can_execute = function(u, game)
        local sd = u.skill_data or {}
        local radius = sd.range or sd.radius or 120
        for _, enemy in ipairs(game.units) do
            if enemy.team ~= u.team and enemy.alive and u:distance_to(enemy) <= radius then
                return true
            end
        end
        return false
    end,
    execute = function(u, game)
        local sd = u.skill_data
        local dmg = sd.damage or math.floor(50*Pacing.damage_multiplier)
        local radius = sd.radius or 120
        for _, enemy in ipairs(game.units) do
            if enemy.team ~= u.team and enemy.alive and enemy.state ~= "dead"
               and u:distance_to(enemy) <= radius then
                enemy:take_damage(dmg, u)
            end
        end
        game:add_effect(Effect.skill_flash(u.x, u.y, radius, {1, 0.3, 0.1}))
    end,
}

Legacy.heal_aoe = {
    label = "范围修复",
    target_mode = "self",
    can_execute = function(u, game)
        local sd = u.skill_data or {}
        local radius = sd.range or sd.radius or 180
        for _, ally in ipairs(game.units) do
            if ally.team == u.team and ally.alive and ally.hp < ally.max_hp
               and u:distance_to(ally) <= radius then
                return true
            end
        end
        return false
    end,
    execute = function(u, game)
        local sd = u.skill_data
        local amount = sd.heal_amount or 50
        local radius = sd.radius or 180
        for _, ally in ipairs(game.units) do
            if ally.team == u.team and ally.alive and ally.state ~= "dead"
               and u:distance_to(ally) <= radius then
                ally:heal(amount)
            end
        end
        game:add_effect(Effect.heal_pulse(u.x, u.y, radius))
    end,
}

Legacy.repair_all = {
    label = "群体抢修",
    target_mode = "self",
    can_execute = Legacy.heal_aoe.can_execute,
    execute = function(u, game)
        local sd = u.skill_data
        local amount = sd.heal_amount or 200
        local radius = sd.radius or 400
        for _, ally in ipairs(game.units) do
            if ally.team == u.team and ally.alive and ally.state ~= "dead"
               and u:distance_to(ally) <= radius then
                ally:heal(amount)
            end
        end
        game:add_effect(Effect.heal_pulse(u.x, u.y, radius))
    end,
}

Legacy.disable = {
    label = "瘫痪脉冲",
    target_mode = "self",
    can_execute = function(u, game)
        local sd = u.skill_data or {}
        local radius = sd.range or sd.radius or 150
        for _, enemy in ipairs(game.units) do
            if enemy.team ~= u.team and enemy.alive and u:distance_to(enemy) <= radius then
                return true
            end
        end
        return false
    end,
    execute = function(u, game)
        local sd = u.skill_data
        local radius = sd.range or 150
        for _, enemy in ipairs(game.units) do
            if enemy.team ~= u.team and enemy.alive and enemy.state ~= "dead"
               and u:distance_to(enemy) <= radius then
                enemy.state = "disabled"
                enemy:apply_buff("disable", 1, sd.duration or 3)
            end
        end
        game:add_effect(Effect.skill_flash(u.x, u.y, radius, {0.8, 0.2, 0.8}))
    end,
}

Legacy.teleport = {
    label = "短距折跃",
    target_mode = "self",
    can_execute = function(u, game)
        return u:find_nearest_enemy(game) ~= nil
    end,
    execute = function(u, game)
        local enemy = u:find_nearest_enemy(game)
        if enemy then
            local px, py = game:find_clear_position(enemy.x+u.attack_range*0.5, enemy.y, u.radius)
            if game:is_position_blocked(px, py, u.radius, u) then return end
            u.x, u.y = px, py
            u.route = nil
            game:add_effect(Effect.skill_flash(u.x, u.y, 60, {0.5, 0.3, 1}))
        end
    end,
}

return Legacy

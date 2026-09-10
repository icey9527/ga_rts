-- 强化类技能：机动强化、火力强化、速射压制。
local Buffs = {}
local Effect = require("entities.effect")

Buffs.buff_speed = {
    label = "机动强化",
    target_mode = "self",
    can_execute = function(u) return not u.buffs.speed end,
    execute = function(u, game)
        local sd = u.skill_data
        local mult = sd.speed_multiplier or 2.0
        local radius = sd.radius or 200
        for _, ally in ipairs(game.units) do
            if ally.team == u.team and ally.alive and ally.state ~= "dead" and u:distance_to(ally) <= radius then
                ally:apply_buff("speed", mult, sd.duration or 5)
            end
        end
        game:add_effect(Effect.skill_flash(u.x, u.y, radius, {0.2, 0.6, 1}))
    end,
}

Buffs.buff_attack = {
    label = "火力强化",
    target_mode = "self",
    can_execute = function(u) return not u.buffs.attack end,
    execute = function(u, game)
        local sd = u.skill_data
        local mult = sd.attack_multiplier or 2.0
        local radius = sd.radius or 200
        for _, ally in ipairs(game.units) do
            if ally.team == u.team and ally.alive and ally.state ~= "dead" and u:distance_to(ally) <= radius then
                ally:apply_buff("attack", mult, sd.duration or 5)
            end
        end
        game:add_effect(Effect.skill_flash(u.x, u.y, radius, {1, 0.4, 0.1}))
    end,
}

Buffs.rapid_fire = {
    label = "速射压制",
    target_mode = "self",
    can_execute = function(u)
        return not u.buffs.attack and u.attack_target and u.attack_target.alive
            and u:distance_to(u.attack_target) <= u.attack_range
    end,
    execute = function(u, game)
        local sd = u.skill_data
        u:apply_buff("attack", sd.attack_multiplier or 1.8, sd.duration or 6)
        u.attack_timer = 0
        game:add_effect(Effect.skill_flash(u.x, u.y, sd.radius or 180, {1, 0.85, 0.2}))
    end,
}

return Buffs

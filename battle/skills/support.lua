-- 防护与支援类技能：屏障、全舰修复、定点抢修。
local Support = {}
local Effect = require("entities.effect")

Support.shield = {
    label = "屏障展开",
    target_mode = "self",
    can_execute = function(u) return u.shield_time<=0 end,
    execute = function(u, game)
        local sd = u.skill_data
        u.shield = sd.shield_amount or 100
        u.shield_time = sd.duration or 5
        game:add_effect(Effect.shield_glow(u, u.shield_time))
    end,
}

Support.fleet_heal = {
    label = "全舰修复",
    target_mode = "self",
    can_execute = function(u, game)
        for _, ally in ipairs(game:get_units_by_team(u.team)) do
            if ally.hp < ally.max_hp then return true end
        end
        return false
    end,
    execute = function(u, game)
        for _, ally in ipairs(game:get_units_by_team(u.team)) do
            ally:heal(ally.max_hp*0.35)
            game:add_effect(Effect.heal_pulse(ally.x, ally.y-(ally.z or 0)*0.22, ally.radius*4))
        end
    end,
}

Support.repair_tool = {
    label = "定点抢修",
    target_mode = "ally",
    can_execute = function(u, game)
        local sd = u.skill_data or {}
        local t = u.repair_target
        return t and t~=u and t.alive and t.team==u.team
            and t.hp<t.max_hp and u:distance_to(t) <= (sd.range or 600)
    end,
    execute = function(u, game)
        local t = u.repair_target
        t:heal(t.max_hp*0.7)
        game:add_effect(Effect.beam(u.x, u.y-(u.z or 0)*0.22, t.x, t.y-(t.z or 0)*0.22))
        game:add_effect(Effect.heal_pulse(t.x, t.y-(t.z or 0)*0.22, 140))
    end,
}

return Support

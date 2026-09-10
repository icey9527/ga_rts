-- 侦察机：侧移掠袭的长射程变体（对应 GoK attackSideStep）。
-- 射程长、机体脆：换位更远更快，接近段带前置量，不与敌缠斗。
local Scout = {}
local Common = require("battle.unit.types.common")

function Scout.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_sidestep(unit) end
end

function Scout.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.break_distance = cfg.break_distance or 160
    cfg.reposition_distance = cfg.reposition_distance or 190
    cfg.reposition_angle = cfg.reposition_angle or 1.05
    cfg.reposition_time = cfg.reposition_time or 0.5
    cfg.approach_boost = cfg.approach_boost or 1.35
    cfg.lead_time = cfg.lead_time or 0.4
    return Common.fly_sidestep(unit, dt, game, cfg)
end

return Scout

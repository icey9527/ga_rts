-- 轻快型战机：侧移掠袭（对应 GoK attackSideStep / LightCorvette）。
-- 快换位、可被主炮就绪提前打断，保持高频射击航段。
local Light = {}
local Common = require("battle.unit.types.common")

function Light.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_sidestep(unit) end
end

function Light.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.break_distance = cfg.break_distance or 120
    cfg.reposition_distance = cfg.reposition_distance or 150
    cfg.reposition_angle = cfg.reposition_angle or 0.9
    cfg.reposition_time = cfg.reposition_time or 0.55
    cfg.approach_boost = cfg.approach_boost or 1.3
    return Common.fly_sidestep(unit, dt, game, cfg)
end

return Light

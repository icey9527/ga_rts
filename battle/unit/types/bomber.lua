-- 导弹轰炸机：远距齐射平台（对应 GoK attackStraightForward）。
-- 齐射后保持距离等待冷却，不贴近目标。
local Bomber = {}
local Common = require("battle.unit.types.common")

function Bomber.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_straight(unit) end
end

function Bomber.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.too_close = cfg.too_close or 500
    cfg.approach_boost = cfg.approach_boost or 1.05
    return Common.fly_straight(unit, dt, game, cfg)
end

return Bomber

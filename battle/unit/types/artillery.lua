-- 远程区域轰击机：固定阵位曲射（对应 GoK attackStraightForward 的极端射程形态）。
-- 全场最远射程，在最远刹车距离外架炮；自身慢速，依赖阵位而非机动。
local Artillery = {}
local Common = require("battle.unit.types.common")

function Artillery.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_straight(unit) end
end

function Artillery.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.too_close = cfg.too_close or 780
    cfg.approach_boost = cfg.approach_boost or 1.0
    return Common.fly_straight(unit, dt, game, cfg)
end

return Artillery

-- 散弹炮艇：直线压迫的中程变体（对应 GoK attackStraightForward）。
-- 散弹近程 + 导弹中程：突进到导弹射界后缓慢逼近，近身刹车齐射。
local Gunship = {}
local Common = require("battle.unit.types.common")

function Gunship.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_straight(unit) end
end

function Gunship.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.too_close = cfg.too_close or 260
    cfg.approach_boost = cfg.approach_boost or 1.15
    return Common.fly_straight(unit, dt, game, cfg)
end

return Gunship

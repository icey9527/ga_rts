-- 虎式重击机：直线压迫的双联重炮变体（对应 GoK attackStraightForward）。
-- 重炮 660 + 弹幕 420 双层火力，刹车距离远于弹幕射界，保持正面投影。
local Tiger = {}
local Common = require("battle.unit.types.common")

function Tiger.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_straight(unit) end
end

function Tiger.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.too_close = cfg.too_close or 350
    cfg.approach_boost = cfg.approach_boost or 1.1
    return Common.fly_straight(unit, dt, game, cfg)
end

return Tiger

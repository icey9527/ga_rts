-- 重型护卫舰：直线压迫（对应 GoK attackStraightForward / StandardFrigate）。
-- 慢速重甲，远程主炮压制，机炮补近；过近刹车原地射击，不做环绕。
local Heavy = {}
local Common = require("battle.unit.types.common")

function Heavy.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_straight(unit) end
end

function Heavy.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.too_close = cfg.too_close or 240
    cfg.approach_boost = cfg.approach_boost or 1.1
    return Common.fly_straight(unit, dt, game, cfg)
end

return Heavy

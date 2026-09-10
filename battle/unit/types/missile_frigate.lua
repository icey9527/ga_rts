-- 导弹护卫舰：远程导弹平台（对应 GoK attackStraightForward / MissileDestroyer）。
-- 超远距齐射，敌接近时保持刹车距离持续输出，绝不冲进缠斗。
local MissileFrigate = {}
local Common = require("battle.unit.types.common")

function MissileFrigate.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_straight(unit) end
end

function MissileFrigate.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.too_close = cfg.too_close or 580
    cfg.approach_boost = cfg.approach_boost or 1.05
    return Common.fly_straight(unit, dt, game, cfg)
end

return MissileFrigate

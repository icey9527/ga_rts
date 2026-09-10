-- 轻型航母：支援平台的保守站位（对应 GoK attackStraightForward / Carrier）。
-- 不主动接敌；被指派攻击时在远距刹住，靠随机体武器自卫，靠队友保护。
local Carrier = {}
local Common = require("battle.unit.types.common")

function Carrier.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_straight(unit) end
end

function Carrier.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.too_close = cfg.too_close or 540
    cfg.approach_boost = cfg.approach_boost or 1.0
    return Common.fly_straight(unit, dt, game, cfg)
end

return Carrier

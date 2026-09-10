-- 维修机：支援优先的自卫火力（对应 GoK attackStraightForward 的保守参数）。
-- 只在被迫交战时于射程边缘刹住开火，火力微弱，本体尽快回到支援流程。
local Repair = {}
local Common = require("battle.unit.types.common")

function Repair.update(unit, dt, game)
    if unit.state ~= "attacking" then Common.clear_straight(unit) end
end

function Repair.fly(unit, dt, game)
    local cfg = unit.behavior_config or {}
    cfg.too_close = cfg.too_close or 190
    cfg.approach_boost = cfg.approach_boost or 1.2
    return Common.fly_straight(unit, dt, game, cfg)
end

return Repair

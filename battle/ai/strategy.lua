-- 战略层：定期审查双方力量对比，产出当前战略（aggressive/defensive/balanced）
-- 与对应的动作权重修正。controller 持有 ai.current_strategy，评分层通过
-- mod() 读取。
local Strategy = {}
local Profiles = require("battle.ai.profiles")

-- 每 4 秒调用一次；my/enemy 为双方存活单位列表。
function Strategy.review(ai, my, enemy)
    local my_str = 0
    for _, u in ipairs(my) do my_str = my_str + u.hp + u.attack_damage * 2 end
    local en_str = 0
    for _, u in ipairs(enemy) do en_str = en_str + u.hp + u.attack_damage * 2 end
    local ratio = my_str / math.max(en_str, 1)

    if ratio > 1.3 then
        ai.current_strategy = "aggressive"
    elseif ratio < 0.7 then
        ai.current_strategy = "defensive"
    else
        ai.current_strategy = "balanced"
    end
end

-- kind: "attack" | "defend" | "retreat"
function Strategy.mod(ai, kind)
    return (Profiles.strategy_mods[ai.current_strategy] or Profiles.strategy_mods.balanced)[kind] or 1
end

return Strategy

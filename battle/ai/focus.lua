-- 集火层：为全舰队挑选并保持一个集火目标。
-- 滞回（hysteresis）保证等分目标之间不逐 tick 翻转，是舰队火力稳定的根基。
local Focus = {}

-- 目标价值：残血优先，母舰与维修单位额外加权。
function Focus.score(e)
    local score = e.hp - e.attack_damage * 0.5
    if e.unit_type == "mothership" then score = score - 500 end
    if e.unit_type == "repair" then score = score - 200 end
    return score
end

-- 每个 AI 决策 tick 调用；enemy 为敌方存活单位列表。
function Focus.update(ai, enemy_units)
    local best, best_score = nil, math.huge
    for _, e in ipairs(enemy_units) do
        local score = Focus.score(e)
        if score < best_score then
            best_score = score
            best = e
        end
    end
    -- 现目标仍存活且没有被明显超越（超过滞回阈值）时保持不变。
    local current = ai.focus_target
    if current and current.alive and current.state ~= "dead" then
        if not best or Focus.score(current) <= best_score + ai.focus_hysteresis then
            return
        end
    end
    ai.focus_target = best
end

return Focus

-- 执行层：单舰决策。对每艘舰艇为可能的动作打效用分，把最优动作通过
-- battle/commands.lua 下发为自动命令；不直接改写单位状态。
-- 评分 = 距离/处境基础分 × 人格权重 × 战略修正（集火另乘协同度）。
local Executor = {}
local Strategy = require("battle.ai.strategy")
local Gameplay = require("config.gameplay")

function Executor.nearest_enemy_anywhere(unit, enemies)
    local best, best_dist = nil, math.huge
    for _, e in ipairs(enemies) do
        local d = unit:distance_to(e)
        if d < best_dist then
            best, best_dist = e, d
        end
    end
    return best, best_dist
end

function Executor.command(ai, unit, my, enemy, game)
    local Commands = require("battle.commands")
    if unit.unit_type=="collector" or unit.objective_ship then return end
    if unit.state=="undocking" then return end
    if unit.state == "disabled" or unit.state == "dead" then return end
    if (unit.state=="returning" or unit.state=="supplying") and game:get_mothership(ai.team) then return end

    -- energy management
    if unit.energy < 15 and unit.state ~= "returning" and unit.state ~= "supplying"
       and game:get_mothership(ai.team) then
        Commands.issue(game,unit,"return")
        return
    end

    -- skill usage
    if unit.sp >= unit.max_sp and unit.skill_data and unit.skill_data.type then
        if Executor.should_use_skill(ai, unit, my, enemy) then
            unit:use_skill(game)
        end
    end

    -- repair units have their own logic
    if unit.unit_type == "repair" then
        if unit.attack_target and unit.attack_target.alive and unit.state=="attacking" then return end
        local threat=unit:find_nearest_enemy(game,unit.attack_range)
        if threat and unit.energy>20 then Commands.issue(game,unit,"attack",{target=threat}) return end
        Executor.command_repair(ai, unit, my, enemy, game)
        return
    end

    -- 任务护送目标优先截击
    local escort=game.objective and game.objective.unit
    if escort and escort.alive and escort.team~=unit.team and unit.hp>unit.max_hp*0.4
        and (unit.unit_type=="light" or unit.unit_type=="interceptor" or unit.unit_type=="sniper")
        and unit:distance_to(escort)<2200 then
        Commands.issue(game,unit,"attack",{target=escort})
        return
    end

    -- 已在有效接战中且状态尚可时不再改命令
    if unit.attack_target and unit.attack_target.alive
       and unit.state=="attacking"
       and unit.hp>unit.max_hp*0.3 then return end

    -- 效用评分取最优（最大值扫描，避免每单位每 tick 建表排序）
    local nearest, nearest_dist = Executor.nearest_enemy_anywhere(unit, enemy)
    local best_name, best_score = nil, 0
    local function consider(name, score)
        if score > best_score then best_name, best_score = name, score end
    end
    consider("focus_fire", Executor.score_focus_fire(ai, unit, enemy))
    consider("attack_nearest", Executor.score_attack_nearest(ai, unit, enemy))
    consider("flank", Executor.score_flank(ai, unit, enemy))
    consider("defend_ms", Executor.score_defend_ms(ai, unit, game))
    consider("retreat", Executor.score_retreat(ai, unit, enemy))
    consider("patrol_hunt", Executor.score_patrol_hunt(ai, unit, nearest, nearest_dist))

    if not best_name then
        -- idle: patrol near mothership
        local ms = game:get_mothership(ai.team)
        if ms and unit.state == "idle" then
            local angle = math.random() * math.pi * 2
            Commands.issue(game,unit,"move",{x=ms.x+math.cos(angle)*200,y=ms.y+math.sin(angle)*200})
        end
        return
    end

    -- execute best action
    if best_name == "focus_fire" and ai.focus_target then
        Commands.issue(game,unit,"attack",{target=ai.focus_target})
    elseif best_name == "attack_nearest" then
        local target = unit:find_nearest_enemy(game)
        if target then Commands.issue(game,unit,"attack",{target=target}) end
    elseif best_name == "flank" then
        Executor.execute_flank(ai, unit, enemy, game)
    elseif best_name == "defend_ms" then
        Executor.execute_defend(ai, unit, enemy, game)
    elseif best_name == "retreat" then
        if game:get_mothership(ai.team) then Commands.issue(game,unit,"return")
        elseif nearest then Commands.issue(game,unit,"attack",{target=nearest}) end
    elseif best_name == "patrol_hunt" and nearest then
        local hunt_x, hunt_y = nearest.x, nearest.y
        if nearest_dist > unit.attack_range * 0.9 then
            local angle = math.atan2 and math.atan2(nearest.y - unit.y, nearest.x - unit.x)
                or math.atan((nearest.y - unit.y), (nearest.x - unit.x))
            hunt_x = nearest.x + math.cos(angle + math.pi * 0.5) * math.min(180, nearest_dist * 0.25)
            hunt_y = nearest.y + math.sin(angle + math.pi * 0.5) * math.min(180, nearest_dist * 0.25)
        end
        -- 攻击移动：接近途中自动接战，到达后不驻留。
        Commands.issue(game,unit,"attack_move",{x=hunt_x,y=hunt_y,engage=nearest})
    end
end

function Executor.command_repair(ai, unit, my, enemy, game)
    local Commands = require("battle.commands")
    -- find damaged allies, prioritize by importance
    local damaged = {}
    for _, u in ipairs(my) do
        if u ~= unit and u.unit_type~="mothership" and u.hp < u.max_hp * 0.85 then
            local priority = (1 - u.hp/u.max_hp) * 100
            if u.unit_type == "heavy" then priority = priority + 100 end
            local dist = unit:distance_to(u)
            damaged[#damaged + 1] = {unit=u, priority=priority, dist=dist}
        end
    end

    if #damaged > 0 then
        table.sort(damaged, function(a, b)
            return (a.priority - a.dist * 0.1) > (b.priority - b.dist * 0.1)
        end)
        Commands.issue(game,unit,"repair",{target=damaged[1].unit})
    else
        local ms = game:get_mothership(ai.team)
        if ms then Commands.issue(game,unit,"follow",{target=ms}) end
    end
end

function Executor.command_mothership(ai, ms, enemy, game)
    local Commands = require("battle.commands")
    if ms.state == "dead" or ms.state == "disabled" then return end
    -- attack nearest enemy in range
    local nearest = ms:find_nearest_enemy(game,ms.attack_range)
    if nearest then
        Commands.issue(game,ms,"attack",{target=nearest})
    end
    -- use repair_all skill when allies are damaged
    if ms.sp >= ms.max_sp then
        local need_heal = false
        for _, u in ipairs(game:get_units_by_team(ai.team)) do
            if u.hp < u.max_hp * 0.5 then need_heal = true; break end
        end
        if need_heal then ms:use_skill(game) end
    end
end

-- ===== 效用评分 =====

function Executor.score_focus_fire(ai, unit, enemy)
    if not ai.focus_target or not ai.focus_target.alive then return 0 end
    local dist = unit:distance_to(ai.focus_target)
    local lock = Gameplay.ai_lock_range
    if dist > lock then return 0 end
    local dist_score = math.max(0, 100 - dist * 0.1)
    local hp_bonus = (1 - ai.focus_target.hp / ai.focus_target.max_hp) * 80
    -- coordination：难度决定舰队服从集火指令的程度，低难度各自为战。
    local compliance = 0.45 + ai.difficulty.coordination * 0.55
    return (dist_score + hp_bonus) * ai.profile.focus_fire_weight * compliance
        * Strategy.mod(ai, "attack")
end

function Executor.score_attack_nearest(ai, unit, enemy)
    if #enemy == 0 then return 0 end
    local nearest, dist = Executor.nearest_enemy_anywhere(unit, enemy)
    if not nearest then return 0 end
    local lock = Gameplay.ai_lock_range
    if dist > lock then return 0 end
    return math.max(15, 95 - dist * 0.025) * ai.profile.attack_weight * Strategy.mod(ai, "attack")
end

function Executor.score_flank(ai, unit, enemy)
    -- flanking: approach from a different angle than allies
    if #enemy < 2 then return 0 end
    -- higher score for fast units
    local speed_bonus = unit.speed / 200 * 30
    return (20 + speed_bonus) * ai.profile.flank_weight
end

function Executor.score_defend_ms(ai, unit, game)
    local ms = game:get_mothership(ai.team)
    if not ms then return 0 end
    local dist = unit:distance_to(ms)
    if dist < 150 then return 10 * ai.profile.defend_weight * Strategy.mod(ai, "defend") end
    -- check if mothership is under threat
    local enemies = game:get_enemy_units(ai.team)
    local under_threat = false
    for _, e in ipairs(enemies) do
        if ms:distance_to(e) < 300 then under_threat = true; break end
    end
    if under_threat then
        return (50 + math.min(dist, 500) * 0.1) * ai.profile.defend_weight * Strategy.mod(ai, "defend")
    end
    return 0
end

function Executor.score_retreat(ai, unit, enemy)
    local hp_ratio = unit.hp / unit.max_hp
    if hp_ratio > 0.35 then return 0 end
    -- also consider nearby enemies
    local nearby = 0
    for _, e in ipairs(enemy) do
        if unit:distance_to(e) < 250 then nearby = nearby + 1 end
    end
    return ((1 - hp_ratio) * 100 + nearby * 20) * ai.profile.retreat_weight * Strategy.mod(ai, "retreat")
end

function Executor.score_patrol_hunt(ai, unit, nearest, nearest_dist)
    if not nearest then return 0 end
    if unit.unit_type == "repair" then return 0 end
    local lock = Gameplay.ai_lock_range
    if nearest_dist < 80 then return 25 end
    if nearest_dist < lock then return 70 end
    return 20
end

-- ===== 动作执行 =====

function Executor.execute_flank(ai, unit, enemy, game)
    local Commands = require("battle.commands")
    if #enemy == 0 then return end
    if unit.state=="moving" and unit.flank_until and game.level_time<unit.flank_until then return end
    unit.flank_until=game.level_time+3
    -- 绕侧优先打集火目标，其次最近敌人；不随机选目标。
    local target = ai.focus_target
    if not (target and target.alive and target.state ~= "dead") then
        target = Executor.nearest_enemy_anywhere(unit, enemy)
    end
    if not target then return end
    local angle = math.random() * math.pi * 2
    local dist = unit.attack_range * 1.2
    Commands.issue(game,unit,"attack_move",{
        x=target.x+math.cos(angle)*dist, y=target.y+math.sin(angle)*dist, engage=target})
end

function Executor.execute_defend(ai, unit, enemy, game)
    local Commands = require("battle.commands")
    local ms = game:get_mothership(ai.team)
    if not ms then return end
    -- attack enemies near mothership
    local best_threat, best_dist = nil, math.huge
    for _, e in ipairs(enemy) do
        local d = ms:distance_to(e)
        if d < 300 and d < best_dist then
            best_threat, best_dist = e, d
        end
    end
    if best_threat then
        Commands.issue(game,unit,"attack",{target=best_threat})
    else
        Commands.issue(game,unit,"follow",{target=ms})
    end
end

function Executor.should_use_skill(ai, unit, my, enemy)
    local sd = unit.skill_data
    if not sd or not sd.type then return false end
    local smart = ai.difficulty.skill_smart

    if sd.type == "damage_aoe" then
        local count = 0
        local r = sd.radius or 120
        for _, e in ipairs(enemy) do
            if unit:distance_to(e) <= r then count = count + 1 end
        end
        return count >= (3 - smart * 1.5)
    elseif sd.type == "heal_aoe" then
        local count = 0
        local r = sd.radius or 180
        for _, u in ipairs(my) do
            if unit:distance_to(u) <= r and u.hp < u.max_hp * 0.6 then count = count + 1 end
        end
        return count >= 2
    elseif sd.type == "shield" then
        return unit.hp < unit.max_hp * (0.4 + smart * 0.2)
    elseif sd.type == "disable" then
        return #enemy >= 2
    end
    return math.random() < smart
end

return Executor

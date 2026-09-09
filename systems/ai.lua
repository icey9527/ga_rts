-- Utility-based AI system
-- Configurable difficulty via TBL profiles
local AI = {}

-- AI personality profiles (weight vectors for utility scoring)
local PROFILES = {
    aggressive = {
        attack_weight = 2.0,
        defend_weight = 0.5,
        retreat_weight = 0.3,
        repair_weight = 0.6,
        flank_weight = 1.5,
        focus_fire_weight = 1.5,
    },
    defensive = {
        attack_weight = 0.6,
        defend_weight = 2.0,
        retreat_weight = 1.5,
        repair_weight = 1.5,
        flank_weight = 0.4,
        focus_fire_weight = 0.8,
    },
    balanced = {
        attack_weight = 1.0,
        defend_weight = 1.0,
        retreat_weight = 0.8,
        repair_weight = 1.0,
        flank_weight = 1.0,
        focus_fire_weight = 1.2,
    },
    tricky = {
        attack_weight = 1.2,
        defend_weight = 0.8,
        retreat_weight = 1.2,
        repair_weight = 0.8,
        flank_weight = 2.0,
        focus_fire_weight = 1.0,
    },
}

function AI.new(team, difficulty, personality)
    difficulty = difficulty or "normal"
    personality = personality or "balanced"

    local diff_cfg = {
        easy   = { reaction = 0.8, coordination = 0.3, skill_smart = 0.4 },
        normal = { reaction = 0.3, coordination = 0.6, skill_smart = 0.7 },
        hard   = { reaction = 0.1, coordination = 0.85, skill_smart = 0.9 },
        insane = { reaction = 0.03, coordination = 0.95, skill_smart = 1.0 },
    }

    local self = {
        team = team,
        personality = personality,
        profile = PROFILES[personality] or PROFILES.balanced,
        difficulty = diff_cfg[difficulty] or diff_cfg.normal,
        timer = 0,
        strategy_timer = 0,
        current_strategy = "balanced",
        focus_target = nil,
    }
    setmetatable(self, {__index = AI})
    return self
end

function AI:update(dt, game)
    if game.tutorial_hold or game.level_time<(game.opening_grace or 0) then return end
    self.timer = self.timer + dt
    self.strategy_timer = self.strategy_timer + dt

    if self.timer < self.difficulty.reaction then return end
    self.timer = 0

    local my_units = game:get_units_by_team(self.team)
    local enemy_units = game:get_enemy_units(self.team)
    if #my_units == 0 then return end

    -- adjust high-level strategy every 4 seconds
    if self.strategy_timer > 4 then
        self:_adjust_strategy(my_units, enemy_units)
        self.strategy_timer = 0
    end

    -- choose focus fire target
    self:_update_focus_target(enemy_units)

    -- command each unit
    for _, unit in ipairs(my_units) do
        if unit.unit_type ~= "mothership" then
            self:_command_unit(unit, my_units, enemy_units, game)
        end
    end

    -- mothership AI
    local ms = game:get_mothership(self.team)
    if ms then self:_command_mothership(ms, enemy_units, game) end
end

function AI:_adjust_strategy(my, enemy)
    local my_str = 0
    for _, u in ipairs(my) do my_str = my_str + u.hp + u.attack_damage * 2 end
    local en_str = 0
    for _, u in ipairs(enemy) do en_str = en_str + u.hp + u.attack_damage * 2 end
    local ratio = my_str / math.max(en_str, 1)

    if ratio > 1.3 then
        self.current_strategy = "aggressive"
    elseif ratio < 0.7 then
        self.current_strategy = "defensive"
    else
        self.current_strategy = "balanced"
    end
end

function AI:_update_focus_target(enemy_units)
    self.focus_target = nil
    local best_score = math.huge
    for _, e in ipairs(enemy_units) do
        -- prefer lowest hp that's also high-value
        local score = e.hp - e.attack_damage * 0.5
        if e.unit_type == "mothership" then score = score - 500 end
        if e.unit_type == "repair" then score = score - 200 end
        if score < best_score then
            best_score = score
            self.focus_target = e
        end
    end
end

function AI:_nearest_enemy_anywhere(unit, enemies)
    local best, best_dist = nil, math.huge
    for _, e in ipairs(enemies) do
        local d = unit:distance_to(e)
        if d < best_dist then
            best, best_dist = e, d
        end
    end
    return best, best_dist
end

function AI:_command_unit(unit, my, enemy, game)
    if unit.state=="undocking" then return end
    if unit.state == "disabled" or unit.state == "dead" then return end
    if (unit.state=="returning" or unit.state=="supplying") and game:get_mothership(self.team) then return end

    -- energy management
    if unit.energy < 15 and unit.state ~= "returning" and unit.state ~= "supplying" and game:get_mothership(self.team) then
        unit.state = "returning"
        return
    end

    -- skill usage
    if unit.sp >= unit.max_sp and unit.skill_data and unit.skill_data.type then
        if self:_should_use_skill(unit, my, enemy) then
            unit:use_skill(game)
        end
    end

    -- repair units have their own logic
    if unit.unit_type == "repair" then
        if unit.attack_target and unit.attack_target.alive and unit.state=="attacking" then return end
        local threat=unit:find_nearest_enemy(game,unit.attack_range)
        if threat and unit.energy>20 then unit.attack_target=threat; unit.state="attacking"; return end
        self:_command_repair(unit, my, enemy, game)
        return
    end
    local escort=game.objective and game.objective.unit
    if escort and escort.alive and escort.team~=unit.team and unit.hp>unit.max_hp*0.4
        and (unit.unit_type=="light" or unit.unit_type=="interceptor" or unit.unit_type=="sniper")
        and unit:distance_to(escort)<2200 then
        unit.attack_target=escort;unit.state="attacking";return
    end
    if unit.attack_target and unit.attack_target.alive and (unit.state=="attacking" or unit.state=="circle_strafing") and unit.hp>unit.max_hp*0.3 then return end

    -- combat units: score possible actions
    local nearest, nearest_dist = self:_nearest_enemy_anywhere(unit, enemy)
    local actions = {
        {name="focus_fire", score=self:_score_focus_fire(unit, enemy)},
        {name="attack_nearest", score=self:_score_attack_nearest(unit, enemy)},
        {name="flank", score=self:_score_flank(unit, enemy)},
        {name="defend_ms", score=self:_score_defend_ms(unit, game)},
        {name="retreat", score=self:_score_retreat(unit, enemy)},
        {name="patrol_hunt", score=self:_score_patrol_hunt(unit, nearest, nearest_dist)},
    }

    -- pick best action
    table.sort(actions, function(a, b) return a.score > b.score end)
    local best = actions[1]

    if best.score <= 0 then
        -- idle: patrol near mothership
        local ms = game:get_mothership(self.team)
        if ms and unit.state == "idle" then
            local angle = math.random() * math.pi * 2
            unit.target_pos = {ms.x + math.cos(angle) * 200, ms.y + math.sin(angle) * 200}
            unit.state = "moving"
        end
        return
    end

    -- execute best action
    if best.name == "focus_fire" and self.focus_target then
        if unit.attack_target ~= self.focus_target or unit.state ~= "attacking" then
            unit.attack_target = self.focus_target
            unit.state = "attacking"
        end
    elseif best.name == "attack_nearest" then
        local nearest = unit:find_nearest_enemy(game)
        if nearest then
            unit.attack_target = nearest
            unit.state = "attacking"
        end
    elseif best.name == "flank" then
        self:_execute_flank(unit, enemy, game)
    elseif best.name == "defend_ms" then
        local ms = game:get_mothership(self.team)
        if ms then
            -- attack enemies near mothership
            local threats = {}
            for _, e in ipairs(enemy) do
                if ms:distance_to(e) < 300 then table.insert(threats, e) end
            end
            if #threats > 0 then
                table.sort(threats, function(a,b) return ms:distance_to(a) < ms:distance_to(b) end)
                unit.attack_target = threats[1]
                unit.state = "attacking"
            else
                unit.follow_target = ms
                unit.state = "following"
            end
        end
    elseif best.name == "retreat" then
        if game:get_mothership(self.team) then unit.state="returning"
        elseif nearest then unit.attack_target=nearest; unit.state="attacking" end
    elseif best.name == "patrol_hunt" and nearest then
        local hunt_x = nearest.x
        local hunt_y = nearest.y
    if nearest_dist > unit.attack_range * 0.9 then
            local angle = math.atan2 and math.atan2(nearest.y - unit.y, nearest.x - unit.x) or math.atan((nearest.y - unit.y), (nearest.x - unit.x))
            hunt_x = nearest.x + math.cos(angle + math.pi * 0.5) * math.min(180, nearest_dist * 0.25)
            hunt_y = nearest.y + math.sin(angle + math.pi * 0.5) * math.min(180, nearest_dist * 0.25)
        end
        unit.target_pos = {hunt_x, hunt_y}
        unit.state = "moving"
        unit.attack_target = nearest
    end
end

function AI:_command_repair(unit, my, enemy, game)
    -- find damaged allies, prioritize by importance
    local damaged = {}
    for _, u in ipairs(my) do
        if u ~= unit and u.unit_type~="mothership" and u.hp < u.max_hp * 0.85 then
            local priority = (1 - u.hp/u.max_hp) * 100
            if u.unit_type == "mothership" then priority = priority + 500 end
            if u.unit_type == "heavy" then priority = priority + 100 end
            local dist = unit:distance_to(u)
            table.insert(damaged, {unit=u, priority=priority, dist=dist})
        end
    end

    if #damaged > 0 then
        table.sort(damaged, function(a, b)
            return (a.priority - a.dist * 0.1) > (b.priority - b.dist * 0.1)
        end)
        unit.repair_target = damaged[1].unit
        unit.state = "repairing"
    else
        -- follow mothership
        local ms = game:get_mothership(self.team)
        if ms then
            unit.follow_target = ms
            unit.state = "following"
        end
    end
end

function AI:_command_mothership(ms, enemy, game)
    if ms.state == "dead" or ms.state == "disabled" then return end
    -- attack nearest enemy in range
    local nearest = ms:find_nearest_enemy(game,ms.attack_range)
    if nearest then
        ms.attack_target = nearest
        if ms.state ~= "attacking" then ms.state = "attacking" end
    end
    -- use repair_all skill when allies are damaged
    if ms.sp >= ms.max_sp then
        local need_heal = false
        for _, u in ipairs(game:get_units_by_team(self.team)) do
            if u.hp < u.max_hp * 0.5 then need_heal = true; break end
        end
        if need_heal then ms:use_skill(game) end
    end
end

-- Utility scoring functions
function AI:_score_focus_fire(unit, enemy)
    if not self.focus_target or not self.focus_target.alive then return 0 end
    local dist = unit:distance_to(self.focus_target)
    local cfg = (_G.SETTINGS and _G.SETTINGS.gameplay) or {}
    local lock = cfg.ai_lock_range or 2600
    if dist > lock then return 0 end
    local dist_score = math.max(0, 100 - dist * 0.1)
    local hp_bonus = (1 - self.focus_target.hp / self.focus_target.max_hp) * 80
    return (dist_score + hp_bonus) * self.profile.focus_fire_weight
end

function AI:_score_attack_nearest(unit, enemy)
    if #enemy == 0 then return 0 end
    local nearest = unit:find_nearest_enemy({get_enemy_units=function() return enemy end})
    if not nearest then return 0 end
    local dist = unit:distance_to(nearest)
    local cfg = (_G.SETTINGS and _G.SETTINGS.gameplay) or {}
    local lock = cfg.ai_lock_range or 2600
    if dist > lock then return 0 end
    return math.max(15, 95 - dist * 0.025) * self.profile.attack_weight
end

function AI:_score_flank(unit, enemy)
    -- flanking: approach from a different angle than allies
    if #enemy < 2 then return 0 end
    -- higher score for fast units
    local speed_bonus = unit.speed / 200 * 30
    return (20 + speed_bonus) * self.profile.flank_weight
end

function AI:_score_defend_ms(unit, game)
    local ms = game:get_mothership(self.team)
    if not ms then return 0 end
    local dist = unit:distance_to(ms)
    if dist < 150 then return 10 * self.profile.defend_weight end
    -- check if mothership is under threat
    local enemies = game:get_enemy_units(self.team)
    local under_threat = false
    for _, e in ipairs(enemies) do
        if ms:distance_to(e) < 300 then under_threat = true; break end
    end
    if under_threat then
        return (50 + math.min(dist, 500) * 0.1) * self.profile.defend_weight
    end
    return 0
end

function AI:_score_retreat(unit, enemy)
    local hp_ratio = unit.hp / unit.max_hp
    if hp_ratio > 0.35 then return 0 end
    -- also consider nearby enemies
    local nearby = 0
    for _, e in ipairs(enemy) do
        if unit:distance_to(e) < 250 then nearby = nearby + 1 end
    end
    return ((1 - hp_ratio) * 100 + nearby * 20) * self.profile.retreat_weight
end

function AI:_score_patrol_hunt(unit, nearest, nearest_dist)
    if not nearest then return 0 end
    if unit.unit_type == "repair" then return 0 end
    local cfg = (_G.SETTINGS and _G.SETTINGS.gameplay) or {}
    local lock = cfg.ai_lock_range or 2600
    if nearest_dist < 80 then return 25 end
    if nearest_dist < lock then return 70 end
    return 20
end

function AI:_execute_flank(unit, enemy, game)
    if #enemy == 0 then return end
    if unit.state=="moving" and unit.flank_until and game.level_time<unit.flank_until then return end
    unit.flank_until=game.level_time+3
    -- pick a target and approach from side/behind
    local target = enemy[math.random(#enemy)]
    if self.focus_target then target = self.focus_target end
    local angle = math.random() * math.pi * 2
    local dist = unit.attack_range * 1.2
    local fx = target.x + math.cos(angle) * dist
    local fy = target.y + math.sin(angle) * dist
    unit.move_target = target
    unit.attack_target = target
    unit.target_pos = {fx, fy}
    unit.state = "moving"
end

function AI:_should_use_skill(unit, my, enemy)
    local sd = unit.skill_data
    if not sd or not sd.type then return false end
    local smart = self.difficulty.skill_smart

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

return AI

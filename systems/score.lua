local Score = {}

function Score.load(TBL)
    local scores = {}
    local data = TBL.parse_file("high_scores.tbl")
    if not data then return scores end
    for key, value in pairs(data.scores or data) do
        if type(value) == "number" then scores[key] = value end
    end
    return scores
end

function Score.save_high(game, scores, level_name, TBL)
    if not level_name or level_name == "" then return end
    if game.score <= (scores[level_name] or 0) then return end
    scores[level_name] = game.score
    love.filesystem.write("high_scores.tbl", TBL.serialize({scores=scores}))
end

function Score.calculate(game, settings)
    local sc = settings.score or {}
    local base, target = sc.base_victory or 1000, sc.time_target or 300
    local bonus = game.level_time < target and math.floor((sc.time_bonus_max or 500) * (1-game.level_time/target)) or 0
    local survival = #game:get_units_by_team(game.player_team) * (sc.unit_survival or 100)
    local defeated = math.max(0,10-#game:get_enemy_units(game.player_team)) * (sc.enemy_defeat or 50)
    local mothership = game:get_mothership(game.player_team) and (sc.mothership_survival or 500) or 0
    game.score = base + bonus + survival + defeated + mothership
    game.score_breakdown = { ["胜利基础"]=base, ["时间奖励"]=bonus, ["单位存活"]=survival, ["敌军击破"]=defeated, ["母舰存活"]=mothership }
end

return Score

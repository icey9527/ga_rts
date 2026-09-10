-- 舰队 AI 组装层：维护决策节拍，逐层调用战略审查、集火挑选与单舰执行。
-- 对外接口保持 Controller.new(team, difficulty, personality) / update(dt, game)，
-- 关卡入口（levels/manager.lua）无需感知内部分层。
-- 分层：profiles(数据) -> strategy(战略) -> focus(集火) -> executor(单舰)。
local Controller = {}
Controller.__index = Controller

local Profiles = require("battle.ai.profiles")
local Strategy = require("battle.ai.strategy")
local Focus = require("battle.ai.focus")
local Executor = require("battle.ai.executor")

local STRATEGY_INTERVAL = 4

function Controller.new(team, difficulty, personality)
    difficulty = difficulty or "normal"
    personality = personality or "balanced"
    local self = {
        team = team,
        personality = personality,
        profile = Profiles.personalities[personality] or Profiles.personalities.balanced,
        difficulty = Profiles.difficulties[difficulty] or Profiles.difficulties.normal,
        timer = 0,
        strategy_timer = 0,
        current_strategy = "balanced",
        focus_target = nil,
        -- 集火保持：新目标必须明显优于现目标才切换，防止全队火力在等分目标间震荡。
        focus_hysteresis = 150,
    }
    return setmetatable(self, Controller)
end

function Controller:update(dt, game)
    if game.tutorial_hold or game.level_time<(game.opening_grace or 0) then return end
    self.timer = self.timer + dt
    self.strategy_timer = self.strategy_timer + dt

    if self.timer < self.difficulty.reaction then return end
    self.timer = 0

    local my_units = game:get_units_by_team(self.team)
    local enemy_units = game:get_enemy_units(self.team)
    if #my_units == 0 then return end

    -- 力量对比审查每 4 秒一次，驱动攻/防/撤权重修正
    if self.strategy_timer > STRATEGY_INTERVAL then
        Strategy.review(self, my_units, enemy_units)
        self.strategy_timer = 0
    end

    Focus.update(self, enemy_units)

    for _, unit in ipairs(my_units) do
        if unit.unit_type ~= "mothership" then
            Executor.command(self, unit, my_units, enemy_units, game)
        end
    end

    -- mothership AI
    local ms = game:get_mothership(self.team)
    if ms then Executor.command_mothership(self, ms, enemy_units, game) end
end

return Controller

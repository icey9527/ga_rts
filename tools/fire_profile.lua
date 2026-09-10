-- 火力剖面：各机型对静止/机动假人的实测 DPS 与弹药数（无窗口诊断工具）。
-- 用途：平衡调整前后的对照。运行方式：lovec . --fire-profile
-- 假人放在 0.75 倍射程处并处于正面射界内；机型战术脚本正常机动，
-- 因此数值包含命中率、射界、能量与冷却的真实影响，不是纸面 DPS。
-- 机动档假人横向正弦规避（模拟侧移），直接检验前置量/散布改动的成效。
local Profile = {}

local function fake_game()
    local g = { player_team = -1, level_time = 0, terrain_objects = {}, units = {}, projectiles = {}, effects = {} }
    function g:is_position_blocked() return false end
    function g:report_event() end
    function g:add_projectile(p) self.projectiles[#self.projectiles + 1] = p end
    function g:add_effect() end
    function g:get_enemy_units(team)
        local out = {}
        for _, u in ipairs(self.units) do
            if u.team ~= team and u.alive then out[#out + 1] = u end
        end
        return out
    end
    function g:get_units_by_team(team)
        local out = {}
        for _, u in ipairs(self.units) do
            if u.team == team and u.alive then out[#out + 1] = u end
        end
        return out
    end
    return g
end

-- 返回 (dps, shots)。moving=true 时假人横向正弦规避，vx 同步供前置量计算。
local function measure(g, cfg, moving)
    local Unit = require("entities.unit")
    local ship = Unit.new(0, 0, 0, cfg)
    local base_x = math.max(700, ship.attack_range * 0.75)
    local dummy = Unit.new(base_x, 0, 1, { max_hp = 1e9, radius = 30 })
    ship.angle = 0
    ship.state = "attacking"
    ship.attack_target = dummy
    g.units = { ship, dummy }
    g.projectiles = {}
    local shots_before = g.shots_fired or 0
    local hp0 = dummy.hp
    local duration, amplitude, omega = 30, 260, 0.9
    local t = 0
    while t < duration do
        g.level_time = g.level_time + 1 / 60
        if moving then
            dummy.x = base_x + math.sin(omega * t) * amplitude
            dummy.vx = amplitude * omega * math.cos(omega * t)
        end
        ship:update(1 / 60, g)
        for i = #g.projectiles, 1, -1 do
            local p = g.projectiles[i]
            p:update(1 / 60, g)
            if not p.alive then table.remove(g.projectiles, i) end
        end
        t = t + 1 / 60
    end
    return (hp0 - dummy.hp) / duration, (g.shots_fired or 0) - shots_before
end

function Profile.run()
    local Manager = require("levels.manager")
    local g = fake_game()
    g.shots_fired = 0
    local raw_add = g.add_projectile
    function g:add_projectile(p)
        self.shots_fired = self.shots_fired + 1
        raw_add(self, p)
    end

    print(string.format("%-16s %10s %10s %8s %s", "type", "DPS_still", "DPS_move", "shots", "weapons(dmg/count/burst/cooldown/energy)"))
    local files = love.filesystem.getDirectoryItems("config/units")
    table.sort(files)
    for _, f in ipairs(files) do
        local id = f:match("^(%w+)%.tbl$")
        if id and id ~= "collector" then
            local cfg = Manager.unit_config(id)
            if cfg then
                local dps_still, shots = measure(g, cfg, false)
                local dps_move = select(1, measure(g, cfg, true))
                local ship = require("entities.unit").new(0, 0, 0, cfg)
                local names = {}
                for _, w in ipairs(ship.weapons) do
                    names[#names + 1] = string.format("%s(%d/%d/%d/%.1f/%.0f)",
                        w.id or "?", w.damage or 0, w.count or 1, w.burst_count or 1,
                        w.cooldown or 0, w.energy_cost or 5)
                end
                print(string.format("%-16s %10.1f %10.1f %8d %s",
                    id, dps_still, dps_move, shots, table.concat(names, ",")))
            end
        end
    end
    print("fire profile complete")
end

return Profile

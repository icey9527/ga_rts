-- Central game state management
local Game = {}

function Game.new()
    -- 默认队伍取 teams 目录扫描结果的前两队，任何队伍都可作我方/敌方
    local ok, Registry = pcall(require, "systems.pack_registry")
    local self = {
        units = {},
        projectiles = {},
        effects = {},
        selected_units = {},
        player_team = 0,
        player_team_id = ok and Registry.default_player() or nil,
        enemy_team_id = ok and Registry.default_enemy() or nil,
        ai_controllers = {},
        level_time = 0,
        paused = false,
        stars = {},
        terrain_objects = {},
        environment_layers = {},
        background = nil,
        pending_waves = {},
        mission = nil,
        score = 0,
        score_breakdown = {},
    }
    setmetatable(self, {__index = Game})
    return self
end

function Game:generate_starfield()
    self.stars = {}
    for _ = 1, 500 do
        table.insert(self.stars, {
            x = math.random(-4000, 4000),
            y = math.random(-4000, 4000),
            layer = math.random(1, 3),
            size = math.random(10, 30) / 10,
            brightness = math.random(60, 255),
            twinkle = math.random() * math.pi * 2,
            twinkle_speed = math.random(10, 30) / 10,
        })
    end
end

function Game:add_unit(unit)
    self.next_unit_id = (self.next_unit_id or 0)+1
    unit.id = self.next_unit_id
    unit.pilot_id = (unit.id-1)%7+1
    unit.callsign = string.format("%s-%02d",unit.team == self.player_team and "A" or "B",unit.id)
    unit.game = self
    unit.team_id = unit.team_id or (unit.team==self.player_team and self.player_team_id or self.enemy_team_id)
    require("ui.pilots").assign(unit)
    unit.name=require("ui.pilots").profile(unit).name
    require("systems.preferences").apply(unit)
    require("systems.economy").apply(self,unit)
    table.insert(self.units, unit)
end

function Game:get_units_center()
    local x,y,count=0,0,0
    for _,u in ipairs(self.units) do
        if u.alive and u.state~="dead" then x=x+u.x; y=y+u.y; count=count+1 end
    end
    if count>0 then return x/count,y/count end
    return 600,500
end

function Game:report_event(unit,kind,text)
    if not unit then return end
    -- 采集站是无人设施，不显示驾驶员通讯或战斗播报。
    if unit.unit_type == "collector" then return end
    local enemy=unit.team~=self.player_team
    local is_follow=(kind=="camera_follow_start" or kind=="camera_follow_continue" or kind=="camera_follow_end")
    local priority=is_follow and 3 or (enemy and 1 or 2)
    local CommsConfig=require("config.comms")
    local last_priority=self.report_priority or 0
    local last_priority_time=self.report_priority_time or -100
    if self.level_time-last_priority_time < (CommsConfig.follow_priority_window or 0.40)
       and priority < last_priority then return end
    if kind=="lost" and not unit.loss_recorded then
        unit.loss_recorded=true
        if not enemy then self.losses=(self.losses or 0)+1 end
    end
    if enemy and (kind=="command" or kind=="failed" or kind=="skill") then return end
    unit.report_times = unit.report_times or {}
    local last = unit.report_times[kind] or -100
    -- 同一角色所有事件共用最小发言间隔，避免受击/充能/释放在同一帧连播三句。
    local global_last = unit.report_global_last or -100
    if self.level_time - global_last < (CommsConfig.report_interval or 0.30) then return end
    local urgent = kind == "lost" or kind == "failed"
    if self.level_time-last < (enemy and 14 or (urgent and 3 or 10)) then return end
    unit.report_times[kind] = self.level_time
    unit.report_global_last = self.level_time
    local Pilots=require("ui.pilots")
    self.reports=self.reports or {}
    local line=Pilots.line(unit,kind,text)
    print("DBG REP",unit.name,kind,line)
    if not line then return end
    self.report_priority=priority
    self.report_priority_time=self.level_time
    local report={unit=unit,kind=kind,text=line,life=5.5,age=0}
    if #self.reports>=3 then table.remove(self.reports,1) end
    self.reports[#self.reports+1]=report
    self.report=report
    if kind=="follow_end" then
        self.report_priority=0
        self.report_priority_time=self.level_time
    end
    if kind=="lost" then
        local opponents=self:get_enemy_units(unit.team)
        if opponents[1] then self:report_event(opponents[1],"praise", "命中判定成功。") end
    end
end

function Game:add_projectile(p)
    table.insert(self.projectiles, p)
end

function Game:add_effect(e)
    table.insert(self.effects, e)
end

function Game:add_terrain(t)
    table.insert(self.terrain_objects, t)
end

function Game:add_environment(layer)
    table.insert(self.environment_layers, layer)
end

function Game:get_units_by_team(team)
    local result = {}
    for _, u in ipairs(self.units) do
        if u.team == team and u.alive and u.state ~= "dead" then
            table.insert(result, u)
        end
    end
    return result
end

function Game:get_enemy_units(team)
    local result = {}
    for _, u in ipairs(self.units) do
        if u.team ~= team and u.alive and u.state ~= "dead" then
            table.insert(result, u)
        end
    end
    return result
end

function Game:get_mothership(team)
    for _, u in ipairs(self.units) do
        if u.team == team and u.unit_type == "mothership" and u.alive and u.state ~= "dead" then
            return u
        end
    end
    return nil
end

function Game:get_all_friendly_units(team)
    local result = {}
    for _, u in ipairs(self.units) do
        if u.team == team and u.unit_type ~= "mothership" and u.unit_type~="collector" and u.alive and u.state ~= "dead" then
            table.insert(result, u)
        end
    end
    return result
end

function Game:get_unit_at(x, y, radius, zoom)
    local best = nil
    local best_dist = math.huge
    for _, u in ipairs(self.units) do
        if u.alive and u.state ~= "dead" then
            local dx, dy = u.x - x, u.y - (u.z or 0) * 0.22 - y
            local d = math.sqrt(dx*dx + dy*dy)
            local r = radius or u.radius * (1 + math.min(u.z or 0, 260) / 520) * 1.4
            if zoom then r=math.max(r,8/zoom) end
            if d <= r and d < best_dist then
                best = u
                best_dist = d
            end
        end
    end
    return best
end

function Game:clear_selection()
    for _, u in ipairs(self.units) do
        u.selected = false
    end
    self.selected_units = {}
end

function Game:select_unit(unit)
    self:clear_selection()
    if unit.team ~= self.player_team then return end
    unit.selected = true
    table.insert(self.selected_units, unit)
end

function Game:select_units_in_rect(x1, y1, x2, y2)
    self:clear_selection()
    local min_x, max_x = math.min(x1, x2), math.max(x1, x2)
    local min_y, max_y = math.min(y1, y2), math.max(y1, y2)
    for _, u in ipairs(self.units) do
        if u.team == self.player_team and u.alive and u.state ~= "dead" then
            local sy = u.y - (u.z or 0) * 0.22
            if u.x >= min_x and u.x <= max_x and sy >= min_y and sy <= max_y then
                u.selected = true
                table.insert(self.selected_units, u)
            end
        end
    end
end

function Game:pause()
    self.paused = true
end

function Game:resume()
    self.paused = false
end

function Game:is_paused()
    return self.paused
end

function Game:update(dt,real_dt)
    if self.paused then return end
    require("systems.space_scene").apply_fields(self, dt)
    self.level_time = self.level_time + dt
    require("systems.economy").update(self,dt)
    require("systems.mission_script").tick(self)
    require("systems.special_attacks").update(self,dt)
    require("systems.objectives").update(self,dt)

    -- update units
    for _, u in ipairs(self.units) do
        if u.update then u:update((u.skill_pending or u.dash or (self.skill_slow and self.skill_slow.unit==u)) and (real_dt or dt) or dt, self) end
    end

    -- update projectiles
    local alive_proj = {}
    for _, p in ipairs(self.projectiles) do
        if p:update(dt, self) then
            table.insert(alive_proj, p)
        end
    end
    self.projectiles = alive_proj

    -- update effects
    local alive_eff = {}
    for _, e in ipairs(self.effects) do
        if e:update(e.realtime and (real_dt or dt) or dt) then
            table.insert(alive_eff, e)
        end
    end
    self.effects = alive_eff

    -- update AI
    for _, ai in ipairs(self.ai_controllers) do
        ai:update(dt, self)
    end

    -- timed reinforcements
    if self.pending_waves and #self.pending_waves > 0 then
        local Unit = require("entities.unit")
        for i = #self.pending_waves, 1, -1 do
            local w = self.pending_waves[i]
            local enemy_wave=(w.team or 1)~=self.player_team
            if enemy_wave and require("systems.preferences").get("disable_enemy_reinforcements",false) then
                table.remove(self.pending_waves,i)
            elseif self.level_time >= (w.time or 0) then
                local first_spawned
                for n = 1, (w.count or 1) do
                    local angle = math.random() * math.pi * 2
                    local dist = math.random() * (w.spread or 120)
                    local x = (w.x or 0) + math.cos(angle) * dist
                    local y = (w.y or 0) + math.sin(angle) * dist
                    local u=Unit.new(x,y,w.team or 1,w.cfg)
                    if n==1 then u.character_id=w.character_id end
                    self:add_unit(u)
                    first_spawned=first_spawned or u
                end
                require("systems.audio").play("reinforce")
                require("systems.cinematic").reinforcement(self,first_spawned)
                table.remove(self.pending_waves, i)
            end
        end
    end

    -- remove dead units
    local alive_units = {}
    for _, u in ipairs(self.units) do
        if u.alive and u.state ~= "dead" then
            table.insert(alive_units, u)
        end
    end
    self.units = alive_units

    -- update star twinkle
    for _, s in ipairs(self.stars) do
        s.twinkle = s.twinkle + s.twinkle_speed * dt
    end

    -- clean up selection of dead units
    local valid_sel = {}
    for _, u in ipairs(self.selected_units) do
        if u.alive and u.state ~= "dead" then
            table.insert(valid_sel, u)
        end
    end
    self.selected_units = valid_sel
end

function Game:is_position_blocked(x, y, r, unit_or_z)
    local z = 0
    local unit_type = nil
    if type(unit_or_z) == "table" then
        z = unit_or_z.z or 0
        unit_type = unit_or_z.unit_type
    elseif type(unit_or_z) == "number" then
        z = unit_or_z
    end

    for _, t in ipairs(self.terrain_objects) do
        local obstacle_height = t.height or t.z_height or ((t.type == "asteroid") and 72 or 36)
        if unit_type == "mothership" then obstacle_height = obstacle_height * 0.55 end
        if z > obstacle_height then
            goto continue
        end
        local dx, dy = t.x - x, t.y - y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < (t.radius or 50) + (r or 10) then
            return true
        end
        ::continue::
    end
    return false
end

function Game:find_clear_position(x, y, r)
    if not self:is_position_blocked(x, y, r) then
        return x, y
    end
    for i = 1, 12 do
        local angle = math.random() * math.pi * 2
        local dist = i * 40
        local tx = x + math.cos(angle) * dist
        local ty = y + math.sin(angle) * dist
        if not self:is_position_blocked(tx, ty, r) then
            return tx, ty
        end
    end
    return x, y
end

function Game:reset()
    self.exchange_times={}
    self.screen_flash=nil;self.skill_focus=nil;self.simulation=false
    self.skill_slow=nil
    self.skill_jobs={}
    self.economy=nil
    self.researcher=nil
    self.logistics=nil
    self.mission=nil
    self.objective=nil
    self.minerals={}
    self.advisor=nil
    self.bad_orders=0
    self.tutorial_hold=false
    self.tutorial_complete=false
    self.cinematic=nil
    self.cutins={}
    self.reports={}
    self.losses=0
    self.inspected_unit = nil
    self.report = nil
    self.next_unit_id = 0
    self.units = {}
    self.projectiles = {}
    self.effects = {}
    self.selected_units = {}
    self.ai_controllers = {}
    self.terrain_objects = {}
    self.environment_layers = {}
    self.background = nil
    self.pending_waves = {}
    self.level_time = 0
    self.paused = false
    self.score = 0
    self.score_breakdown = {}
    self:generate_starfield()
end

return Game

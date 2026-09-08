-- Unit entity with state machine
local Unit = {}
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

function Unit.new(x, y, team, cfg)
    local s = cfg.stats or cfg  -- accept both parsed TBL (with [stats]) and raw table
    local u = {
        x = x, y = y,
        vx = 0, vy = 0,
        team = team,
        unit_type = s.type or "fighter",
        name = s.name or "Unit",
        type_name = s.name or s.type or "fighter",
        description = s.description or "",
        alive = true,

        -- stats
        max_hp = s.max_hp or 100,
        hp = s.max_hp or 100,
        max_energy = s.max_energy or 100,
        energy = s.max_energy or 100,
        base_speed = s.speed or 150,
        speed = s.speed or 150,
        attack_damage = s.attack_damage or 10,
        base_attack_damage = s.attack_damage or 10,
        attack_range = s.attack_range or 150,
        attack_cooldown = s.attack_cooldown or 1.0,
        attack_type = s.attack_type or "ranged",
        projectile_count = s.projectile_count or 1,
        burst_count = s.burst_count or 1,
        burst_delay = s.burst_delay or 0.06,
        spread_angle = s.spread_angle or 0.16,
        target_spread = s.target_spread or 24,
        projectile_speed = s.projectile_speed or 400,
        splash_radius = s.splash_radius or 0,
        accuracy = s.accuracy or 0.78,
        evasion = s.evasion or 0.12,
        radius = s.radius or 15,
        sprite_color = s.sprite_color or {100, 255, 100},
        repair_range = s.repair_range or 100,
        repair_rate = s.repair_rate or 10,

        -- state
        state = "idle",
        target = nil,
        target_pos = nil,
        attack_target = nil,
        repair_target = nil,
        follow_target = nil,
        move_target = nil,

        -- timers
        attack_timer = 0,
        burst_queue = {},
        state_timer = 0,

        -- SP / skills
        sp = 0,
        max_sp = 100,
        skill_data = cfg.skill or {},

        -- buffs / shields
        buffs = {},
        shield = 0,
        shield_time = 0,

        -- visual
        selected = false,
        angle = math.random() * math.pi * 2,
        circle_direction = math.random() < 0.5 and -1 or 1,
        flash_timer = 0,

        -- pseudo-3D flight layer
        z = s.z or 0,
        target_z = s.z or 0,
        vz = 0,
        bank = 0,
    }
    setmetatable(u, {__index = Unit})
    local path="units/"..u.unit_type.."/logic.lua"
    if love.filesystem.getInfo(path) then u.behavior=require("units."..u.unit_type..".logic") end
    return u
end

function Unit:distance_to(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return math.sqrt(dx*dx + dy*dy)
end

function Unit:dist_to_pos(px, py)
    local dx = self.x - px
    local dy = self.y - py
    return math.sqrt(dx*dx + dy*dy)
end

function Unit:take_damage(dmg)
    if not self.alive then return end
    dmg=dmg*(self.game and require("config.pacing").damage_multiplier or 1)
    -- shield absorbs first
    if self.shield > 0 then
        local absorbed = math.min(dmg, self.shield)
        self.shield = self.shield - absorbed
        dmg = dmg - absorbed
    end
    self.hp = self.hp - dmg
    if self.game and self.game.tutorial_hold then self.hp=math.max(self.hp,1) end
    if dmg>0 then require("systems.audio").play("impact") end
    self.flash_timer = 0.1
    if self.hp <= 0 then
        self.hp = 0
        self.alive = false
        self.state = "dead"
        if self.game then
            require("systems.audio").play("destroyed")
            if self.team~=self.game.player_team and self.game.economy then
                self.game.economy.credits=self.game.economy.credits+require("config.economy").bounty
            end
            self.game:report_event(self,"lost","机体失去响应……通讯中断。")
            self.game:add_effect(require("entities.effect").explosion(self.x,self.y-(self.z or 0)*0.22,self.radius*2.5))
        end
    elseif dmg > 0 and self.game then
        self.game:report_event(self,"hit",self.hp < self.max_hp*0.3 and "装甲严重受损，请求支援！" or "受到攻击，正在规避！")
    end
end

function Unit:heal(amount)
    self.hp = math.min(self.hp + amount, self.max_hp)
end

function Unit:find_nearest_enemy(game, max_range)
    local enemies = game:get_enemy_units(self.team)
    local best, best_dist = nil, math.huge
    for _, e in ipairs(enemies) do
        local d = self:distance_to(e)
        if (not max_range or d <= max_range) and d < best_dist then
            best, best_dist = e, d
        end
    end
    return best
end

function Unit:find_mothership(game)
    return game:get_mothership(self.team)
end

-- Main update
function Unit:update(dt, game)
    if not self.alive or self.state == "dead" then return end

    self.state_timer = self.state_timer + dt
    if self.sp<self.max_sp then self.skill_announced=false end
    if self.sp>=self.max_sp and not self.skill_announced and self.team==game.player_team then
        self.skill_announced=true
        game:report_event(self,"ready","特殊装备已就绪，随时可以出击。")
    end
    if self.skill_pending then
        self.skill_pending=self.skill_pending-dt
        if self.state=="disabled" then self.skill_pending=nil; self.sp=self.max_sp
        elseif self.skill_pending<=0 then
            self.skill_pending=nil
            local Skill=require("systems.skill")
            if Skill.can_execute(self,game) then Skill.execute(self,game)
            else self.sp=self.max_sp; game:report_event(self,"failed","目标脱离，蓄力已取消。") end
        end
    end
    local p=require("config.pacing")
    self.energy=math.min(self.max_energy,self.energy+p.passive_energy_per_second*dt)
    self.attack_timer = math.max(0, self.attack_timer - dt)
    if self.state ~= "disabled" then self:_update_burst_queue(dt, game) else self.burst_queue={} end

    -- update buffs
    local expired = {}
    for k, b in pairs(self.buffs) do
        b.time = b.time - dt
        if b.time <= 0 then
            table.insert(expired, k)
        end
    end
    for _, k in ipairs(expired) do
        self.buffs[k] = nil
        if k == "disable" then self.state = "idle" end
    end
    self:_recalc_stats()

    -- update shield timer
    if self.shield_time > 0 then
        self.shield_time = self.shield_time - dt
        if self.shield_time <= 0 then self.shield = 0 end
    end

    -- flash timer
    self.flash_timer = math.max(0, self.flash_timer - dt)
    self:_update_flight_layer(dt)

    -- auto behaviors for player team
    if self.team == game.player_team and self.state ~= "disabled" then
        self:_player_auto(dt, game)
    end

    -- state machine
    local old_x, old_y = self.x, self.y
    if not require("systems.special_attacks").update_dash(self,dt,game) then self:_update_state(dt, game) end
    if self.behavior and self.state~="disabled" then self.behavior.update(self,dt,game) end
    if dt > 0 then
        self.vx, self.vy = (self.x-old_x)/dt, (self.y-old_y)/dt
    end
    self.trail_time=(self.trail_time or 0)+dt
    if self.trail_time>=0.04 then
        self.trail_time=self.trail_time%0.04
        self.flight_trail=self.flight_trail or {}
        self.flight_trail[#self.flight_trail+1]={x=self.x,y=self.y-(self.z or 0)*0.22}
        if #self.flight_trail>12 then table.remove(self.flight_trail,1) end
    end
end

function Unit:_base_altitude()
    if self.unit_type == "mothership" then return 18 end
    if self.unit_type == "repair" then return 24 end
    if self.unit_type == "heavy" then return 38 end
    if self.unit_type == "bomber" then return 82 end
    if self.unit_type == "scout" then return 92 end
    if self.unit_type == "interceptor" then return 76 end
    if self.unit_type == "gunship" then return 58 end
    if self.unit_type == "missile_frigate" then return 72 end
    if self.unit_type == "carrier" then return 42 end
    return 64
end

function Unit:_update_flight_layer(dt)
    local target = self:_base_altitude()
    if self.state == "moving" then
        target = target + 18
    elseif self.state == "attacking" then
        target = target + 24
    elseif self.state == "circle_strafing" then
        target = target + 42 + math.sin((self.angle or 0) * 2) * 18
    elseif self.state == "returning" then
        target = target + 10
    elseif self.state == "supplying" or self.state == "repairing" then
        target = math.max(8, target - 14)
    end

    self.target_z = target
    local diff = self.target_z - (self.z or 0)
    local accel = math.max(-180, math.min(180, diff * 5))
    self.vz = (self.vz or 0) + accel * dt
    self.vz = self.vz * math.max(0, 1 - dt * 4)
    self.z = math.max(0, (self.z or 0) + self.vz * dt + diff * dt * 2.2)

    local speed = math.sqrt((self.vx or 0) ^ 2 + (self.vy or 0) ^ 2)
    self.bank = math.max(-0.75, math.min(0.75, ((self.circle_direction or 1) * speed / 420)))
end

function Unit:_player_auto(dt, game)
    if self.objective_ship then return end
    if self.unit_type=="repair" and self.state=="idle" then
        local nearest,dist=nil,math.huge
        for _,ally in ipairs(game:get_units_by_team(self.team)) do
            local d=self:distance_to(ally)
            if ally~=self and ally.hp<ally.max_hp and d<math.max(self.repair_range*2,300) and d<dist then nearest,dist=ally,d end
        end
        if nearest then self.repair_target=nearest; self.state="repairing" end
    end
    -- auto use skill when SP full
    if self.auto_skill and self.sp >= self.max_sp then self:use_skill(game) end

    -- auto return for supply when energy low and idle
    if self.energy < 5 and self.state ~= "returning" and self.state ~= "supplying" and self.unit_type ~= "mothership" then
        local ms = self:find_mothership(game)
        if ms then
            self.state = "returning"
        end
    end

    -- very limited auto-engage when idle
    if self.state == "idle" and self.state_timer > 1.4 and self.unit_type ~= "repair" and self.energy > 5 then
        local cfg = (_G.SETTINGS and _G.SETTINGS.gameplay) or {}
        local range = self.manual_order and self.attack_range or math.min(cfg.fighter_auto_range or 1800,self.attack_range*1.4)
        local enemy = self:find_nearest_enemy(game, range)
        if enemy then
            self.attack_target = enemy
            self.state = "attacking"
        end
    end
end

function Unit:_update_state(dt, game)
    if self.state == "idle" then
        -- nothing
    elseif self.state == "moving" then
        self:_state_moving(dt, game)
    elseif self.state == "attacking" then
        self:_state_attacking(dt, game)
    elseif self.state == "circle_strafing" then
        self:_state_circle_strafing(dt, game)
    elseif self.state == "repairing" then
        self:_state_repairing(dt, game)
    elseif self.state == "following" then
        self:_state_following(dt, game)
    elseif self.state == "returning" then
        self:_state_returning(dt, game)
    elseif self.state == "supplying" then
        self:_state_supplying(dt, game)
    elseif self.state == "undocking" then
        if not self.target_pos or self:_move_towards(self.target_pos[1],self.target_pos[2],self.speed*dt,game) then
            self.state="idle";self.state_timer=0;self.target_pos=nil;self.route=nil
        end
    elseif self.state == "disabled" then
        -- can't act
    end
end

function Unit:_state_moving(dt, game)
    if self.attack_move then
        local enemy=self:find_nearest_enemy(game,self.attack_range*1.15)
        if enemy then self.attack_target=enemy; self.state="attacking"; return end
    end
    if not self.target_pos then
        self.state = "idle"
        return
    end
    local arrived = self:_move_towards(self.target_pos[1], self.target_pos[2], self.speed * dt, game)
    if arrived then
        self.target_pos = nil
        self.attack_move = nil
        self.state = "idle"
    end
end

function Unit:_state_attacking(dt, game)
    if not self.attack_target or not self.attack_target.alive or self.attack_target.state == "dead" then
        self.attack_target = nil
        local next_enemy=self:find_nearest_enemy(game,self.attack_range*1.5)
        if next_enemy then self.attack_target=next_enemy; return end
        -- AI handled separately; player units go idle
        self.state = self.attack_move and "moving" or "idle"
        if self.attack_move then self.target_pos={self.attack_move[1],self.attack_move[2]} end
        return
    end

    local dist = self:distance_to(self.attack_target)

    -- fighters/scouts/interceptors use circle strafing
    local strafe_types = {fighter=true, scout=true, interceptor=true, light=true}
    if strafe_types[self.unit_type] and dist <= self.attack_range + 120 then
        self.orbit_angle=atan2(self.y-self.attack_target.y,self.x-self.attack_target.x)
        self.state = "circle_strafing"
        return
    end

    if dist <= self.attack_range then
        self:_try_attack(game)
    else
        self:_move_towards(self.attack_target.x, self.attack_target.y, self.speed * dt, game)
    end
end

function Unit:_state_circle_strafing(dt, game)
    if not self.attack_target or not self.attack_target.alive or self.attack_target.state == "dead" then
        self.attack_target = nil
        local next_enemy=self:find_nearest_enemy(game,self.attack_range*1.5)
        if next_enemy then self.attack_target=next_enemy; self.state="attacking"; return end
        self.state = self.attack_move and "moving" or "idle"
        if self.attack_move then self.target_pos={self.attack_move[1],self.attack_move[2]} end
        return
    end

    local dist = self:distance_to(self.attack_target)
    local cfg = (_G.SETTINGS and _G.SETTINGS.circle_strafe) or {radius=100, speed=3}
    local sr = math.min(cfg.radius or 100,self.attack_range*0.75)
    local ss = cfg.speed or 3

    if dist > self.attack_range + sr * 2 then
        self.state = "attacking"
        return
    end

    self.orbit_angle = (self.orbit_angle or atan2(self.y-self.attack_target.y,self.x-self.attack_target.x)) + math.min(ss,self.speed/math.max(sr,1))*dt*self.circle_direction
    local cx = self.attack_target.x + math.cos(self.orbit_angle) * sr
    local cy = self.attack_target.y + math.sin(self.orbit_angle) * sr
    self:_move_towards(cx, cy, self.speed * dt, game)

    if dist <= self.attack_range then
        self:_try_attack(game)
    end
end

function Unit:_state_repairing(dt, game)
    if not self.repair_target or not self.repair_target.alive then
        self.repair_target = nil
        self.state = "idle"
        return
    end
    if self.repair_target.hp >= self.repair_target.max_hp then
        self.repair_target = nil
        self.state = "idle"
        return
    end

    local dist = self:distance_to(self.repair_target)
    if dist <= self.repair_range then
        if self.energy > 0 then
            local rate = self.repair_rate * dt
            self.repair_target:heal(rate)
            self.energy = math.max(0, self.energy - 3 * dt)
        end
    else
        self:_move_towards(self.repair_target.x, self.repair_target.y, self.speed * dt, game)
    end
end

function Unit:_state_following(dt, game)
    if not self.follow_target or not self.follow_target.alive then
        self.follow_target = nil
        self.state = "idle"
        return
    end

    local dist = self:distance_to(self.follow_target)
    if dist > 80 then
        self:_move_towards(self.follow_target.x, self.follow_target.y, self.speed * dt, game)
    end

    -- assist in combat
    if self.follow_target.state == "attacking" and self.follow_target.attack_target
       and self.attack_damage > 0 then
        local at = self.follow_target.attack_target
        if self:distance_to(at) <= self.attack_range then
            self.attack_target = at
            self:_try_attack(game)
        end
    end
end

function Unit:_state_returning(dt, game)
    if self.unit_type == "mothership" then
        self.state = "idle"
        return
    end
    local ms = self:find_mothership(game)
    if not ms or ms == self then
        self.state = "idle"
        return
    end
    local dist = self:distance_to(ms)
    local cfg = (_G.SETTINGS and _G.SETTINGS.gameplay) or {}
    local sr = cfg.supply_range or 100
    if dist <= sr then
        self.state = "supplying"
    else
        self:_move_towards(ms.x, ms.y, self.speed * dt, game)
    end
end

function Unit:_state_supplying(dt, game)
    if self.unit_type == "mothership" then
        self.state = "idle"
        return
    end
    local ms = self:find_mothership(game)
    local cfg = (_G.SETTINGS and _G.SETTINGS.gameplay) or {}
    local sr = cfg.supply_range or 100
    local rate = cfg.supply_rate or 80
    local hp_rate = cfg.supply_hp_rate or 50

    if not ms or ms == self then
        self.state = "idle"
        return
    end
    if self:distance_to(ms)>sr then self.state="returning";self.route=nil;return end

    self.energy = math.min(self.energy + rate * dt, self.max_energy)
    self.hp = math.min(self.hp + hp_rate * dt, self.max_hp)

    if self.energy >= self.max_energy and self.hp >= self.max_hp then
        local angle=(self.id or 1)*2.399963
        local radius=ms.radius+self.radius+150
        local x,y=game:find_clear_position(ms.x+math.cos(angle)*radius,ms.y+math.sin(angle)*radius,self.radius)
        self.state="undocking";self.state_timer=0
        self.attack_target=nil;self.attack_move=nil;self.follow_target=nil;self.repair_target=nil
        self.route=nil;self.burst_queue={};self.target_pos={x,y}
    end
end

-- Movement helper: returns true if arrived
function Unit:_move_towards(tx, ty, step, game)
    if step<=0 then return false end
    if game:is_position_blocked(self.x,self.y,self.radius,self) then
        self.z=math.min(300,(self.z or 0)+step*0.8)
        self.route=nil
        return false
    end
    local nav=require("systems.navigation")
    if not self.route or math.abs(tx-(self.route_x or 0))+math.abs(ty-(self.route_y or 0))>12 or game.level_time>=(self.route_time or 0) then
        self.route=nav.route(game,self,tx,ty)
        self.route_x,self.route_y,self.route_time=tx,ty,game.level_time+1.5
    end
    local point=self.route[1]
    if not point then
        game:report_event(self,"failed","航线受阻，请重新指定航点。")
        return false
    end
    local dx,dy=point.x-self.x,point.y-self.y
    local dist=math.sqrt(dx*dx+dy*dy)
    local travel=math.min(step,dist)
    local nx,ny=self.x,self.y
    if dist>0 then nx,ny=self.x+dx/dist*travel,self.y+dy/dist*travel end
    if game:is_position_blocked(nx,ny,self.radius,self) then
        self.route=nil
        return false
    end
    self.x,self.y=nx,ny
    if dist>0.1 then
        local desired=atan2(dy,dx)
        local diff=(desired-self.angle+math.pi)%(2*math.pi)-math.pi
        local turn=math.min(1,step/math.max(self.speed,1)*8)
        self.angle=self.angle+diff*turn
        self.bank=math.max(-0.65,math.min(0.65,diff))
    end
    if dist<=step+0.01 then
        table.remove(self.route,1)
        if #self.route==0 then self.route=nil; return true end
    end
    return false
end

function Unit:_spawn_projectile(game, target, index, total)
    local Projectile = require("entities.projectile")
    if not target or not target.alive then return end
    if self.state=="disabled" or target.team==self.team or self:distance_to(target)>self.attack_range+20 then return end
    self.muzzle_time=game.level_time
    local angle_off = 0
    if total > 1 then angle_off = (index - (total - 1) / 2) * (self.spread_angle or 0.16) end
    local base = atan2(target.y - self.y, target.x - self.x)
    local dist = math.max(120, self:distance_to(target))
    local pacing=require("config.pacing")
    local flight=math.min(1.8,dist/math.max(1,self.projectile_speed))*pacing.lead_fraction
    local spread=pacing.spread_pixels*(1-(self.accuracy or 0.78))+(target.evasion or 0.12)*20
    local error_angle=math.random()*math.pi*2
    local error_radius=math.random()*spread
    local tx = target.x+(target.vx or 0)*flight+math.cos(error_angle)*error_radius+math.cos(base+math.pi/2)*angle_off*(self.target_spread or 120)
    local ty = target.y+(target.vy or 0)*flight+math.sin(error_angle)*error_radius+math.sin(base+math.pi/2)*angle_off*(self.target_spread or 120)
    local dmg = math.max(1, math.floor(self.attack_damage / math.max(1, self.projectile_count)))

    if self.attack_type == "beam" then
        target:take_damage(dmg)
        local Effect = require("entities.effect")
        game:add_effect(Effect.beam(self.x, self.y - (self.z or 0) * 0.22, target.x, target.y - (target.z or 0) * 0.22))
    elseif self.attack_type == "missile" then
        game:add_projectile(Projectile.missile(self.x, self.y, target, dmg, self.projectile_speed, self.z or 0))
    elseif self.attack_type == "artillery" then
        game:add_projectile(Projectile.artillery(self.x, self.y, tx, ty, dmg, self.splash_radius, self.projectile_speed, self.z or 0,self.team))
    else
        game:add_projectile(Projectile.basic(self.x, self.y, tx, ty, dmg, self.projectile_speed, target, self.z or 0))
    end
end

function Unit:_update_burst_queue(dt, game)
    for i = #self.burst_queue, 1, -1 do
        local shot = self.burst_queue[i]
        shot.delay = shot.delay - dt
        if shot.delay <= 0 then
            self:_spawn_projectile(game, shot.target, shot.index, shot.total)
            table.remove(self.burst_queue, i)
        end
    end
end

function Unit:_try_attack(game)
    if not self.alive or self.state=="disabled" then return end
    if self.attack_timer > 0 then return end
    if self.energy <= 0 then return end
    if not self.attack_target then return end
    if not self.attack_target.alive or self.attack_target.team==self.team or self:distance_to(self.attack_target)>self.attack_range then return end

    local cfg = (_G.SETTINGS and _G.SETTINGS.gameplay) or {}
    local cost = (self.unit_type == "mothership") and 0 or (cfg.energy_attack_cost or 5)
    if self.energy < cost then return end

    self.attack_timer = self.attack_cooldown
    self.energy = self.energy - cost
    game:report_event(self,"attack","目标进入射程，开始攻击。")
    require("systems.audio").play("shot")

    local at = self.attack_target
    local bursts = math.max(1, self.burst_count or 1)
    for b = 1, bursts do
        for i = 0, self.projectile_count - 1 do
            if b == 1 then
                self:_spawn_projectile(game, at, i, self.projectile_count)
            else
                table.insert(self.burst_queue, {
                    target = at,
                    index = i,
                    total = self.projectile_count,
                    delay = (b - 1) * (self.burst_delay or 0.06),
                })
            end
        end
    end

    -- gain SP
    self.sp = math.min(self.sp + (cfg.sp_gain_per_attack or 8), self.max_sp)
end

function Unit:use_skill(game)
    if not self.alive or self.state=="disabled" or not self.skill_data or not self.skill_data.type then return false end
    if self.sp < self.max_sp or self.skill_pending then return false end

    local Skill = require("systems.skill")
    if not Skill.can_execute(self,game) then return false end
    require("systems.special_attacks").prepare(self)
    self.skill_pending=self.skill_data.windup or require("config.pacing").skill_windup
    game:add_effect(require("entities.effect").charge(self,self.skill_pending))
    -- 敌我双方都启动侧边必杀演出；样式与尺寸由 cinematic 按阵营区分。
    require("systems.cinematic").start(game,self)
    require("systems.advisor").event(game,"skill")
    self.sp = 0
    require("systems.audio").play("skill")
    game:report_event(self,"skill","特殊装备启动！")
    return true
end

function Unit:_recalc_stats()
    self.speed = self.base_speed
    self.attack_damage = self.base_attack_damage
    for _, b in pairs(self.buffs) do
        if b.type == "speed" then
            self.speed = self.speed * (b.multiplier or 1.5)
        elseif b.type == "attack" then
            self.attack_damage = math.floor(self.attack_damage * (b.multiplier or 1.5))
        end
    end
end

function Unit:apply_buff(btype, multiplier, duration)
    self.buffs[btype] = {type=btype, multiplier=multiplier, time=duration}
    self:_recalc_stats()
end

return Unit

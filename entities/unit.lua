-- Unit entity with state machine
local Unit = {}
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local Targeting=require("battle.unit.targeting")
local Weapons=require("battle.unit.weapons")
local Combat=require("battle.unit.combat")
local Movement=require("battle.unit.movement")
local ProjectileCombat=require("battle.unit.projectile")

function Unit.new(x, y, team, cfg)
    local s = cfg.stats or cfg  -- accept both parsed TBL (with [stats]) and raw table
    local configured_weapons={}
    for section,weapon in pairs(cfg or {}) do
        if type(section)=="string" and section:match("^weapon%.") and type(weapon)=="table" then
            local definition={}
            for k,v in pairs(weapon) do definition[k]=v end
            definition.id=definition.id or section:match("^weapon%.(.+)$")
            configured_weapons[#configured_weapons+1]=definition
        end
    end
    table.sort(configured_weapons,function(a,b) return a.id<b.id end)
    local u = {
        x = x, y = y,
        vx = 0, vy = 0,
        team = team,
        unit_type = s.type or "fighter",
        name = s.name or "Unit",
        type_name = s.name or s.type or "fighter",
        description = s.description or "",
        behavior_config = cfg.behavior or {},
        alive = true,

        -- stats
        max_hp = s.max_hp or 100,
        hp = s.max_hp or 100,
        max_energy = (s.max_energy or 100)*1.25,
        energy = (s.max_energy or 100)*1.25,
        base_speed = s.speed or 150,
        speed = s.speed or 150,
        acceleration = s.acceleration or 900,
        deceleration = s.deceleration or 1100,
        turn_rate = s.turn_rate or 3,
        attack_damage = s.attack_damage or 10,
        base_attack_damage = s.attack_damage or 10,
        configured_attack_damage = s.attack_damage or 10,
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
        -- 武器按机体类型配置；未配置时自动生成一门主炮，兼容现有单位表。
        weapons = Weapons.normalize((#configured_weapons>0 and configured_weapons) or s.weapons, {id="main",range=s.attack_range or 150,damage=s.attack_damage or 10,cooldown=s.attack_cooldown or 1.0,count=s.projectile_count or 1,arc=s.attack_arc or 100,direction=s.attack_direction or "front"}),
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
    for _,weapon in ipairs(u.weapons) do u.attack_range=math.max(u.attack_range,weapon.range or 0) end
    u.behavior=require("battle.unit.type_loader").load(u.unit_type)
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

function Unit:take_damage(dmg,attacker)
    if not self.alive then return end
    dmg=dmg*(self.game and require("config.pacing").damage_multiplier or 1)
    -- shield absorbs first
    if self.shield > 0 then
        local absorbed = math.min(dmg, self.shield)
        self.shield = self.shield - absorbed
        dmg = dmg - absorbed
    end
    self.hp = self.hp - dmg
    if dmg>0 and self.hp>0 and self.unit_type~="collector" and not self.objective_ship
       and Targeting.is_valid_enemy(self,attacker)
       and not Targeting.is_valid_enemy(self,self.attack_target) then
        self.attack_target=attacker
        self.retarget_timer=0.45
        if self.state=="idle" or self.state=="moving" then self.state="attacking" end
    end
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
    return Targeting.nearest_enemy(self,game,max_range)
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
        if self.state=="disabled" then self.skill_pending=nil; self.sp=self.max_sp;self.skill_aim=nil;self.skill_target=nil
        elseif self.skill_pending<=0 then
            self.skill_pending=nil
            local Skill=require("systems.skill")
            if Skill.can_execute(self,game) then Skill.execute(self,game)
            else self.sp=self.max_sp;self.skill_aim=nil;self.skill_target=nil; game:report_event(self,"failed","目标脱离，蓄力已取消。") end
        end
    end
    local p=require("config.pacing")
    self.energy=math.min(self.max_energy,self.energy+p.passive_energy_per_second*dt)
    self.attack_timer = math.max(0, self.attack_timer - dt)
    self.retarget_timer=math.max(0,(self.retarget_timer or 0)-dt)
    Weapons.update(self.weapons,dt)
    if self.state ~= "disabled" then self:_update_burst_queue(dt, game) else Combat.cancel_bursts(self) end

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
    self.combat_move_intent=nil
    self._movement_active=true;self._movement_used=false
    if self.behavior and self.state~="disabled" then self.behavior.update(self,dt,game) end
    if not require("systems.special_attacks").update_dash(self,dt,game) then self:_update_state(dt, game) end
    self._movement_active=false
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
    if self.energy < 5 and self.state ~= "returning" and self.state ~= "supplying"
       and self.unit_type ~= "mothership" and self.unit_type ~= "collector" then
        if not self.energy_warn_report or game.level_time - self.energy_warn_report > 20 then
            self.energy_warn_report = game.level_time
            game:report_event(self, "energy", "能量不足，准备返航补给。")
        end
        self.supply_resume_target = self.attack_target
        local ms = self:find_mothership(game)
        if ms then
            self.state = "returning"
        end
    end

    -- very limited auto-engage when idle
    if self.state == "idle" and self.state_timer > 1.4 and self.unit_type ~= "repair" and self.unit_type~="collector" and self.energy > 5 then
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
    if self.state~="attacking" and self.state~="circle_strafing" then self.combat_pass=nil end
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
            if self.supply_resume_target and self.supply_resume_target.alive then
                self.attack_target=self.supply_resume_target; self.supply_resume_target=nil; self.state="attacking"
                game:report_event(self,"return_battle","重返战场，继续攻击。")
            end
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
        if self.retarget_timer<=0 then
            local next_enemy=self:find_nearest_enemy(game,self.attack_range*1.5)
            self.retarget_timer=0.45
            if next_enemy then self.attack_target=next_enemy; return end
        end
        -- AI handled separately; player units go idle
        self.state = self.attack_move and "moving" or "idle"
        if self.attack_move then self.target_pos={self.attack_move[1],self.attack_move[2]} end
        return
    end

    local dist = self:distance_to(self.attack_target)

    if self.behavior and self.behavior.fly and self.behavior.fly(self,dt,game) then return end

    if self.combat_move_intent then
        self._approach_speed_multiplier=nil
        self:_move_towards(self.combat_move_intent.x,self.combat_move_intent.y,self.speed*dt,game)
        self:_try_attack(game)
        return
    end

    -- 高速机体在射程外主动加速接敌，进入射程后恢复正常航速。
    local fast_types={light=true,scout=true}
    if fast_types[self.unit_type] and dist>self.attack_range then
        self._approach_speed_multiplier=1.35
        self:_move_towards(self.attack_target.x,self.attack_target.y,self.speed*1.35*dt,game)
        return
    end
    self._approach_speed_multiplier=nil

    -- 近中程战舰保持缠斗，不在射程内原地停死；远程炮舰和母舰继续保持阵位。
    local strafe_types = {
        scout=true, light=true,
        heavy=true, gunship=true, bomber=true, tiger=true, carrier=true,
        missile_frigate=true,
    }
    if strafe_types[self.unit_type] and dist <= self.attack_range + 120 then
        self.orbit_angle=atan2(self.y-self.attack_target.y,self.x-self.attack_target.x)
        self.state = "circle_strafing"
        return
    end

    if dist <= self.attack_range then
        Combat.aim(self,self.attack_target,dt)
        self:_try_attack(game)
    else
        self:_move_towards(self.attack_target.x, self.attack_target.y, self.speed * dt, game)
    end
end

function Unit:_state_circle_strafing(dt, game)
    if self.behavior and self.behavior.fly and self.behavior.fly(self,dt,game) then return end
    if not self.attack_target or not self.attack_target.alive or self.attack_target.state == "dead" then
        self.attack_target = nil
        if self.retarget_timer<=0 then
            local next_enemy=self:find_nearest_enemy(game,self.attack_range*1.5)
            self.retarget_timer=0.45
            if next_enemy then self.attack_target=next_enemy; self.state="attacking"; return end
        end
        self.state = self.attack_move and "moving" or "idle"
        if self.attack_move then self.target_pos={self.attack_move[1],self.attack_move[2]} end
        return
    end

    local dist = self:distance_to(self.attack_target)
    local cfg = (_G.SETTINGS and _G.SETTINGS.circle_strafe) or {radius=100, speed=3}
    local sr = math.min(cfg.radius or 100,self.attack_range*0.75)
    if self.combat_orbit_radius then sr=math.min(self.combat_orbit_radius,self.attack_range*0.88) end
    -- Small hysteresis keeps range-edge movement stable without orbiting out of firing range for seconds.
    if dist > self.attack_range + math.max(80,self.attack_range*0.12) then
        self.state = "attacking"
        return
    end

    -- Anchor the steering point to the actual position: a free-running orbit point can outrun the ship.
    self.orbit_angle = atan2(self.y-self.attack_target.y,self.x-self.attack_target.x) + math.min(0.5,math.max(0.18,self.speed/math.max(sr,1)*0.6))*self.circle_direction
    local cx = self.attack_target.x + math.cos(self.orbit_angle) * sr
    local cy = self.attack_target.y + math.sin(self.orbit_angle) * sr
    -- Turn into a firing pass when a forward weapon is ready. Constant tangential
    -- orbiting otherwise leaves the target outside the gun arc indefinitely.
    local ready=false
    for _,weapon in ipairs(self.weapons) do
        if (weapon.cooldown_timer or 0)<=0.6 and Weapons.can_fire(weapon) then ready=true;break end
    end
    local pass=self.combat_pass
    if pass and (pass.target~=self.attack_target or pass.until_time<=game.level_time) then pass=nil;self.combat_pass=nil end
    if pass then cx,cy=pass.x,pass.y
    elseif ready then cx,cy=self.attack_target.x,self.attack_target.y end
    self:_move_towards(cx, cy, self.speed * dt, game)

    if dist <= self.attack_range then
        if self:_try_attack(game) and not pass then
            local angle=self.angle+self.circle_direction*0.6
            local length=math.max(90,math.min(240,self.speed*1.2))
            self.combat_pass={target=self.attack_target,until_time=game.level_time+1.0,x=self.x+math.cos(angle)*length,y=self.y+math.sin(angle)*length}
        end
    end
end

function Unit:_state_repairing(dt, game)
    if not self.repair_target or not self.repair_target.alive or self.repair_target.unit_type=="mothership" then
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
            self.repair_target:heal(self.repair_target.max_hp)
            self.energy = math.max(0, self.energy - 12)
            game:report_event(self,"repair_done","维修完成，目标机体可以继续作战。")
            self.repair_target=nil;self.state="idle"
        end
    else
        self:_move_towards(self.repair_target.x, self.repair_target.y, self.speed * dt, game)
    end
end

function Unit:_state_following(dt, game)
    if not self.follow_target or not self.follow_target.alive then
        if self.follow_target then
            game:report_event(self,"formation_follow_end","")
        end
        self.follow_target = nil
        self.state = "idle"
        return
    end

    local CommsConfig=require("config.comms")
    self.follow_report_time=self.follow_report_time or game.level_time
    if game.level_time-self.follow_report_time >= (CommsConfig.formation_follow_continue_interval or 20) then
        game:report_event(self,"formation_follow_continue","")
        self.follow_report_time=game.level_time
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

    if not ms or ms == self then
        self.state = "idle"
        return
    end
    if self:distance_to(ms)>sr then self.state="returning";self.route=nil;return end

    self.energy = self.max_energy
    self.hp = self.max_hp

    if self.energy >= self.max_energy and self.hp >= self.max_hp then
        local angle=(self.id or 1)*2.399963
        local radius=ms.radius+self.radius+150
        local x,y=game:find_clear_position(ms.x+math.cos(angle)*radius,ms.y+math.sin(angle)*radius,self.radius)
        self.state="undocking";self.state_timer=0
        self.attack_target=nil;self.attack_move=nil;self.follow_target=nil;self.repair_target=nil
        game:report_event(self,"supplied","补给完成，重新加入战斗。")
        self.route=nil;Combat.cancel_bursts(self);self.target_pos={x,y}
    end
end

-- Movement helper: returns true if arrived
function Unit:_move_towards(tx, ty, step, game)
    if self._movement_active then
        assert(not self._movement_used,"Multiple movement integrations in one unit update: "..self.unit_type)
        self._movement_used=true
    end
    return Movement.move_towards(self,tx,ty,step,game)
end

function Unit:_spawn_projectile(game, target, index, total, weapon)
    return ProjectileCombat.spawn(self,game,target,index,total,weapon)
end

function Unit:_update_burst_queue(dt, game)
    Combat.update_bursts(self,dt,game)
end

function Unit:_try_attack(game)
    return Combat.fire(self,game,function(target,index,count,weapon) return self:_spawn_projectile(game,target,index,count,weapon) end)
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

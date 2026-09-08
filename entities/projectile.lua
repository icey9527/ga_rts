-- Projectile entity
local Projectile = {}
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local image_cache = {}

local function get_image(path)
    if image_cache[path] ~= nil then return image_cache[path] end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
        image_cache[path] = img
    else
        image_cache[path] = false
    end
    return image_cache[path]
end

local P = {}
P.__index = P

function Projectile.basic(x, y, tx, ty, dmg, speed, target, z)
    local dx, dy = tx - x, ty - y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist == 0 then dist = 1 end
    return setmetatable({
        x = x, y = y,
        vx = (dx/dist) * speed,
        vy = (dy/dist) * speed,
        z = z or 0,
        target_z = target and (target.z or 0) or 0,
        damage = dmg,
        speed = speed,
        target = target,
        target_pos = {tx, ty},
        splash = 0,
        homing = false,
        alive = true,
        life = 3.0,
        trail = {},
    }, P)
end

function Projectile.artillery(x, y, tx, ty, dmg, splash, speed, z, team)
    local dx, dy = tx - x, ty - y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist == 0 then dist = 1 end
    return setmetatable({
        x = x, y = y,
        vx = (dx/dist) * speed,
        vy = (dy/dist) * speed,
        z = z or 0,
        target_z = 0,
        damage = dmg,
        speed = speed,
        target = nil,
        target_pos = {tx, ty},
        splash = splash or 60,
        team = team,
        homing = false,
        alive = true,
        life = 3.0,
        trail = {},
    }, P)
end

function Projectile.missile(x, y, target, dmg, speed, z)
    return setmetatable({
        x = x, y = y,
        vx = 0, vy = 0,
        z = z or 0,
        target_z = target and (target.z or 0) or 0,
        damage = dmg,
        speed = speed,
        target = target,
        target_pos = {target.x, target.y},
        splash = 0,
        homing = true,
        turn_rate = require("config.pacing").missile_turn_rate,
        heading = atan2(target.y-y,target.x-x)+(math.random()-0.5)*0.7,
        alive = true,
        life = 8.0,
        trail = {},
        smoke_timer = 0,
    }, P)
end

function P:update(dt, game)
    self.life = self.life - dt
    if self.life <= 0 then
        self.alive = false
        return false
    end

    -- homing: update target position
    if self.homing and self.target and self.target.alive and self.target.state ~= "dead" then
        self.target_pos = {self.target.x, self.target.y}
        self.target_z = self.target.z or 0
    end

    -- move toward target
    local tx, ty = self.target_pos[1], self.target_pos[2]
    local dx, dy = tx - self.x, ty - self.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist < 8 then
        -- hit
        self:_on_hit(game)
        return false
    end

    self.trail[#self.trail + 1] = {x = self.x, y = self.y, z = self.z or 0}
    if #self.trail > (self.homing and 18 or 8) then
        table.remove(self.trail, 1)
    end

    local old_x, old_y = self.x, self.y
    -- update velocity for homing missiles
    if self.homing and dist > 0 then
        local desired = atan2(dy, dx)
        local diff = (desired - self.heading + math.pi) % (math.pi * 2) - math.pi
        local max_turn = (self.turn_rate or 5) * dt
        diff = math.max(-max_turn, math.min(max_turn, diff))
        self.heading = self.heading + diff
        self.vx = math.cos(self.heading) * self.speed
        self.vy = math.sin(self.heading) * self.speed
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
    else
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
    end
    -- Sweep the traveled segment so fast projectiles cannot skip the impact point.
    local sx, sy = self.x - old_x, self.y - old_y
    local length2 = sx*sx + sy*sy
    if self.target and self.target.alive and self.splash==0 then
        local target=self.target
        local hit_t=length2>0 and math.max(0,math.min(1,((target.x-old_x)*sx+(target.y-old_y)*sy)/length2)) or 0
        local px,py=old_x+sx*hit_t,old_y+sy*hit_t
        if (px-target.x)^2+(py-target.y)^2<=(target.radius or 15)^2 then
            self.x,self.y=px,py
            self:_on_hit(game)
            return false
        end
    end
    local t = length2 > 0 and math.max(0, math.min(1, ((tx-old_x)*sx + (ty-old_y)*sy)/length2)) or 0
    local hx, hy = old_x + sx*t, old_y + sy*t
    if (hx-tx)^2 + (hy-ty)^2 <= 64 then
        self.x, self.y = hx, hy
        self:_on_hit(game)
        return false
    end
    self.z = math.max(0, (self.z or 0) + ((self.target_z or 0) - (self.z or 0)) * dt * 2.5)
    return true
end

function P:_on_hit(game)
    local Effect = require("entities.effect")
    if self.splash > 0 then
        -- splash damage
        for _, u in ipairs(game.units) do
            if u.alive and u.state ~= "dead" and (self.team==nil or u.team~=self.team) then
                local d = math.sqrt((u.x-self.x)^2 + (u.y-self.y)^2)
                if d <= self.splash then
                    local ratio = 1 - (d / self.splash) * 0.5
                    u:take_damage(math.floor(self.damage * ratio))
                end
            end
        end
        game:add_effect(Effect.explosion(self.x, self.y-(self.z or 0)*0.22, self.splash))
    else
        -- direct hit
        if self.target and self.target.alive and self.target.state ~= "dead" and (self.target.x-self.x)^2+(self.target.y-self.y)^2<=((self.target.radius or 15)+8)^2 then
            self.target:take_damage(self.damage)
        end
        game:add_effect(Effect.hit_spark(self.x, self.y-(self.z or 0)*0.22))
    end
    self.alive = false
end

function P:draw()
    local z = self.z or 0
    local y = self.y - z * 0.22
    local smoke = get_image("assets/effects/beaml.bmp.png")
    local flash = get_image("assets/effects/beams.bmp.png")

    for i = 1, #self.trail do
        local t = self.trail[i]
        local k = i / #self.trail
        local alpha = (self.homing and 0.22 or 0.12) * k
        local radius = self.homing and (7 * (1 - k) + 2) or 2
        if smoke then
            love.graphics.setColor(0.75, 0.82, 0.88, alpha * 2.0)
            local s = radius / math.max(1, smoke:getWidth()) * 2.8
            love.graphics.draw(smoke, t.x, t.y - (t.z or 0) * 0.22, 0, s, s, smoke:getWidth() / 2, smoke:getHeight() / 2)
        else
            love.graphics.setColor(0.55, 0.66, 0.72, alpha)
            love.graphics.circle("fill", t.x, t.y - (t.z or 0) * 0.22, radius)
        end
    end

    if self.homing then
        if flash then
            love.graphics.setColor(1, 0.62, 0.24, 0.92)
            local s = 18 / math.max(1, flash:getWidth())
            love.graphics.draw(flash, self.x, y, love.timer.getTime() * 6, s, s, flash:getWidth() / 2, flash:getHeight() / 2)
        else
            love.graphics.setColor(1, 0.48, 0.18, 0.45)
            love.graphics.circle("fill", self.x, y, 8)
        end
        love.graphics.setColor(1, 0.92, 0.35, 0.96)
        love.graphics.circle("fill", self.x, y, 3.5)
    else
        love.graphics.setColor(1, 0.82, 0.25, 0.92)
        love.graphics.circle("fill", self.x, y, 3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Projectile

-- Camera with pan, zoom, edge scrolling, and smooth follow
local Camera = {}

function Camera.new(map_w, map_h)
    local self = {
        x = 0, y = 0,
        zoom = 1.0,
        target_zoom = 1.0,
        map_w = map_w,
        map_h = map_h,
        follow_target = nil,
        follow_speed = 5,
        shake_amount = 0,
        shake_duration = 0,
        edge_scroll = false,
        edge_scroll_outside_only = false,
        zoom_min = 0.10,
        zoom_max = 4.0,
    }
    setmetatable(self, {__index = Camera})
    return self
end

function Camera:screen_to_world(sx, sy)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local wx = (sx - w/2) / self.zoom + self.x
    local wy = (sy - h/2) / self.zoom + self.y
    return wx, wy
end

function Camera:world_to_screen(wx, wy)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local sx = (wx - self.x) * self.zoom + w/2
    local sy = (wy - self.y) * self.zoom + h/2
    return sx, sy
end

function Camera:set_follow(unit)
    if self.follow_target==unit then return end
    local old_target=self.follow_target
    if old_target and old_target.alive and old_target.game then
        local cfg=require("config.comms")
        local started=old_target.camera_follow_started_at or -100
        if cfg.camera_follow_end_enabled
           and (old_target.game.level_time-started) >= (cfg.camera_follow_end_min_duration or 3.0) then
            old_target.game:report_event(old_target,"camera_follow_end","")
        end
    end
    self.follow_target = unit
    if unit and unit.game then
        local cfg=require("config.comms")
        local g=unit.game
        unit.camera_follow_started_at=g.level_time
        unit.camera_follow_continue_report_time=nil
        local last=g.camera_follow_start_time or -100
        if g.level_time-last >= (cfg.camera_follow_start_interval or 2.5) then
            g.camera_follow_start_time=g.level_time
            g:report_event(unit,"camera_follow_start","")
        end
    end
end

function Camera:stop_follow()
    if self.follow_target and self.follow_target.alive and self.follow_target.game then
        local cfg=require("config.comms")
        local started=self.follow_target.camera_follow_started_at or -100
        if cfg.camera_follow_end_enabled
           and (self.follow_target.game.level_time-started) >= (cfg.camera_follow_end_min_duration or 10.0) then
            self.follow_target.game:report_event(self.follow_target,"camera_follow_end","")
        end
    end
    self.follow_target = nil
end

function Camera:focus_on(wx, wy)
    self.x = wx
    self.y = wy
end

function Camera:zoom_in()
    self.target_zoom = math.min(self.zoom_max, self.target_zoom * 1.35)
end

function Camera:zoom_out()
    self.target_zoom = math.max(self.zoom_min, self.target_zoom / 1.35)
end

function Camera:shake(amount, duration)
    self.shake_amount = math.max(self.shake_amount, amount)
    self.shake_duration = math.max(self.shake_duration, duration or 0.3)
end

function Camera:update(dt)
    -- smooth follow
    if self.follow_target and self.follow_target.alive then
        local cfg=require("config.comms")
        local g=self.follow_target.game
        if g then
            local started=self.follow_target.camera_follow_started_at or g.level_time
            local last=self.follow_target.camera_follow_continue_report_time
            local delay=cfg.camera_follow_continue_delay or 5.0
            local interval=cfg.camera_follow_continue_interval or 20.0
            local due=(not last and g.level_time-started>=delay)
                or (last and g.level_time-last>=interval)
            if due then
                g:report_event(self.follow_target,"camera_follow_continue","")
                self.follow_target.camera_follow_continue_report_time=g.level_time
            end
        end
        local tx = self.follow_target.x
        local ty = self.follow_target.y - (self.follow_target.z or 0)*0.22
        self.x = self.x + (tx - self.x) * math.min(self.follow_speed * dt, 1)
        self.y = self.y + (ty - self.y) * math.min(self.follow_speed * dt, 1)
    end

    -- smooth zoom
    self.zoom = self.zoom + (self.target_zoom - self.zoom) * math.min(10 * dt, 1)

    -- screen shake
    if self.shake_duration > 0 then
        self.shake_duration = self.shake_duration - dt
        if self.shake_duration <= 0 then
            self.shake_amount = 0
        end
    end
end

function Camera:edge_scroll_update(dt)
    if not self.edge_scroll then return end
    local mx, my = love.mouse.getPosition()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local cfg = (_G.SETTINGS and _G.SETTINGS.gameplay) or {}
    local margin = cfg.edge_scroll_margin or 40
    local speed = cfg.edge_scroll_speed or 620
    if mx < margin or mx > w-margin or my < margin or my > h-margin then
        self:stop_follow()
    end

    if self.edge_scroll_outside_only then
        if mx < 0 then self.x = self.x - speed * dt / self.zoom end
        if mx > w then self.x = self.x + speed * dt / self.zoom end
        if my < 0 then self.y = self.y - speed * dt / self.zoom end
        if my > h then self.y = self.y + speed * dt / self.zoom end
    else
        if mx < margin then self.x = self.x - speed * dt / self.zoom end
        if mx > w - margin then self.x = self.x + speed * dt / self.zoom end
        if my < margin then self.y = self.y - speed * dt / self.zoom end
        if my > h - margin then self.y = self.y + speed * dt / self.zoom end
    end
end

function Camera:enable_edge_scroll(v, outside_only)
    self.edge_scroll = v
    self.edge_scroll_outside_only = outside_only or false
end

function Camera:apply()
    love.graphics.push()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    love.graphics.translate(w/2, h/2)

    -- shake offset
    local sx, sy = 0, 0
    if self.shake_duration > 0 then
        sx = (math.random() - 0.5) * 2 * self.shake_amount
        sy = (math.random() - 0.5) * 2 * self.shake_amount
    end

    love.graphics.scale(self.zoom, self.zoom)
    love.graphics.translate(-self.x + sx, -self.y + sy)
end

function Camera:reset()
    love.graphics.pop()
end

return Camera

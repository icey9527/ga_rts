-- Visual effects
local Effect = {}
local spark
local textures={}
local function sprite(name,x,y,size,angle,color,alpha)
    if textures[name]==nil then
        local ok,img=pcall(love.graphics.newImage,"assets/effects/"..name..".png")
        textures[name]=ok and img or false
    end
    local img=textures[name]
    if not img then return end
    love.graphics.push("all");love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1],color[2],color[3],alpha)
    love.graphics.draw(img,x,y,angle,size/img:getWidth(),size/img:getHeight(),img:getWidth()/2,img:getHeight()/2)
    love.graphics.pop()
end
local function draw_flash(x, y, radius, alpha)
    if spark == nil then
        local ok, img = pcall(love.graphics.newImage,"assets/effects/impact-flash.png")
        spark = ok and img or false
    end
    if not spark then return end
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1,0.78,0.4,alpha)
    local s = radius*2/spark:getWidth()
    love.graphics.draw(spark,x,y,0,s,s,spark:getWidth()/2,spark:getHeight()/2)
    love.graphics.pop()
end

local E = {}
E.__index = E

function Effect.new(duration)
    return setmetatable({
        timer = duration,
        duration = duration,
        alive = true,
    }, E)
end

function E:update(dt)
    self.timer = self.timer - dt
    return self.timer > 0
end

function E:progress()
    return 1 - (self.timer / self.duration)
end

-- specific effects
function Effect.hit_spark(x, y)
    local e = Effect.new(0.15)
    e.x, e.y = x, y
    e.draw = function(self)
        local p = self:progress()
        local r = 15 * (1 - p)
        local a = 1 - p
        draw_flash(self.x,self.y,28,a)
        love.graphics.setColor(1, 0.8, 0.2, a)
        love.graphics.circle("line", self.x, self.y, r)
        love.graphics.setColor(1, 1, 1, a * 0.8)
        love.graphics.circle("line", self.x, self.y, r * 0.5)
        love.graphics.setColor(1, 1, 1, 1)
    end
    return e
end

function Effect.beam(x1, y1, x2, y2)
    local e = Effect.new(0.25)
    e.x1, e.y1 = x1, y1
    e.x2, e.y2 = x2, y2
    e.draw = function(self)
        local p = self:progress()
        local a = 1 - p
        love.graphics.setColor(0.2, 0.8, 1, a)
        love.graphics.setLineWidth(5 * (1 - p))
        love.graphics.line(self.x1, self.y1, self.x2, self.y2)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
    return e
end

function Effect.charged_beam(x1,y1,x2,y2,color,duration)
    local e=Effect.new(duration or 0.9);e.realtime=true
    color=color or {0.25,0.8,1}
    e.draw=function(self)
        local g=love.graphics
        local alpha=1-self:progress()
        g.push("all");g.setBlendMode("add")
        for i=4,1,-1 do
            g.setColor(color[1],color[2],color[3],alpha/(i*1.7))
            g.setLineWidth(i*9*alpha+1);g.line(x1,y1,x2,y2)
        end
        g.setColor(1,1,1,alpha);g.setLineWidth(3);g.line(x1,y1,x2,y2)
        if duration then sprite("dash-streak",(x1+x2)/2,(y1+y2)/2,110,math.atan2(y2-y1,x2-x1)-math.pi/2,color,alpha*0.65) end
        draw_flash(x2,y2,75,alpha)
        g.pop()
    end
    return e
end

function Effect.charge(unit,duration)
    local e=Effect.new(duration);e.realtime=true
    e.draw=function(self)
        if not unit.alive or not unit.skill_pending then return end
        local p=self:progress()
        local x,y=unit.x,unit.y-(unit.z or 0)*0.22
        sprite("charge-glint",x,y,40+p*130,p*2,{0.55,0.85,1},0.35+p*0.6)
        local aim=unit.skill_aim
        if aim then
            love.graphics.push("all");love.graphics.setColor(1,0.35,0.25,0.3+p*0.3);love.graphics.setLineWidth(1)
            local ty=aim.y-(aim.z or 0)*0.22
            if unit.skill_data.type=="charge_beam" then love.graphics.line(x,y,aim.x,ty)
            else love.graphics.ellipse("line",aim.x,ty,unit.skill_data.radius or 60,(unit.skill_data.radius or 60)*0.6) end
            love.graphics.pop()
        end
    end
    return e
end

function Effect.explosion(x, y, radius)
    local e = Effect.new(0.5)
    e.x, e.y = x, y
    e.radius = radius
    e.draw = function(self)
        local p = self:progress()
        local r = self.radius * p
        local a = 1 - p
        draw_flash(self.x,self.y,self.radius*(0.5+p),a)
        -- outer ring
        love.graphics.setColor(1, 0.5, 0.1, a)
        love.graphics.circle("line", self.x, self.y, r)
        -- inner flash
        love.graphics.setColor(1, 0.9, 0.3, a * 0.7)
        love.graphics.circle("fill", self.x, self.y, r * 0.4)
        -- particles
        for i = 1, 6 do
            local angle = i * math.pi / 3 + p * 3
            local px = self.x + math.cos(angle) * r * 1.2
            local py = self.y + math.sin(angle) * r * 1.2
            love.graphics.setColor(1, 0.7, 0.1, a)
            love.graphics.circle("fill", px, py, 3 * a)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    return e
end

function Effect.shield_glow(unit, duration)
    local e = Effect.new(duration or 0.5)
    e.unit = unit
    e.draw = function(self)
        if not self.unit or not self.unit.alive then return end
        local p = self:progress()
        local a = 0.5 + math.sin(p * math.pi * 4) * 0.3
        love.graphics.setColor(0.3, 0.9, 1, a)
        local u=self.unit
        local x,y=u.x,u.y-(u.z or 0)*0.22
        local radius=u.radius*(1+math.min(u.z or 0,260)/520)+14
        love.graphics.setColor(0.25,0.8,1,a*0.16)
        love.graphics.ellipse("fill",x,y,radius*1.5,radius)
        love.graphics.setColor(0.4,0.95,1,a)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line",x,y,radius*1.5,radius)
        for i=0,5 do
            local angle=p*6+i*math.pi/3
            love.graphics.arc("line","open",x,y,radius*1.15,angle,angle+0.4)
        end
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
    return e
end

function Effect.heal_pulse(x, y, radius)
    local e = Effect.new(0.6)
    e.x, e.y = x, y
    e.radius = radius
    e.draw = function(self)
        local p = self:progress()
        local r = self.radius * p
        local a = 1 - p
        love.graphics.setColor(0.2, 1, 0.4, a)
        sprite("repair-sparks",self.x,self.y,self.radius*(0.6+p),p,{0.45,1,0.75},a)
        love.graphics.circle("line", self.x, self.y, r)
        love.graphics.setColor(0.5, 1, 0.6, a * 0.5)
        love.graphics.circle("fill", self.x, self.y, r * 0.3)
        love.graphics.setColor(1, 1, 1, 1)
    end
    return e
end

function Effect.skill_flash(x, y, radius, color)
    local e = Effect.new(0.8)
    e.x, e.y = x, y
    e.radius = radius
    e.color = color or {1, 0.8, 0.2}
    e.draw = function(self)
        local p = self:progress()
        local r = self.radius * (0.5 + math.sin(p * math.pi) * 0.5)
        local a = 1 - p
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], a)
        love.graphics.circle("line", self.x, self.y, r)
        -- expanding ring
        love.graphics.circle("line", self.x, self.y, self.radius * p)
        love.graphics.setColor(1, 1, 1, 1)
    end
    return e
end

function Effect.skill_signature(unit)
    local kind=unit and unit.unit_type or "fighter"
    local x,y=unit.x,unit.y-(unit.z or 0)*0.22
    if kind=="sniper" then
        local e=Effect.new(1.15);e.x,e.y=x,y;e.radius=900;e.draw=function(self)
            local p=self:progress(); local a=math.sin(p*math.pi)
            love.graphics.setColor(0.3,0.85,1,a);love.graphics.setLineWidth(5*(1-p))
            love.graphics.line(self.x,self.y,self.x+self.radius*(0.2+p*0.8),self.y)
            love.graphics.setLineWidth(1)
        end;return e
    elseif kind=="bomber" or kind=="artillery" then
        local e=Effect.new(1.2);e.x,e.y=x,y;e.radius=260;e.draw=function(self)
            local p=self:progress();local a=1-p
            love.graphics.setColor(1,0.4,0.08,a);love.graphics.circle("line",self.x,self.y,self.radius*(0.3+p))
            for i=1,8 do local q=p*260+i*42;love.graphics.circle("fill",self.x+math.cos(i*2.4)*q,self.y+math.sin(i*2.4)*q,4) end
        end;return e
    elseif kind=="interceptor" or kind=="light" then
        local e=Effect.new(0.8);e.x,e.y=x,y;e.radius=120;e.draw=function(self)
            local p=self:progress();love.graphics.setColor(1,0.85,0.25,1-p);love.graphics.polygon("fill",self.x+self.radius*p,self.y,self.x-30,self.y-18,self.x-30,self.y+18)
        end;return e
    end
    return Effect.skill_flash(x,y,220,{0.4,0.8,1})
end

function Effect.unit_death(x, y, radius)
    local e = Effect.new(0.7)
    e.x, e.y = x, y
    e.radius = radius
    e.particles = {}
    for i = 1, 15 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 200)
        table.insert(e.particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = math.random(2, 6),
            life = math.random(30, 70) / 100,
        })
    end
    e.draw = function(self)
        local p = self:progress()
        local a = 1 - p
        for _, pt in ipairs(self.particles) do
            pt.x = pt.x + pt.vx * 0.016
            pt.y = pt.y + pt.vy * 0.016
            pt.life = pt.life - 0.016
            if pt.life > 0 then
                love.graphics.setColor(1, 0.5, 0.1, a * pt.life)
                love.graphics.circle("fill", pt.x, pt.y, pt.size * a)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    return e
end

return Effect

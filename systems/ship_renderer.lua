local Ships = {}
local cache = {}
local function image(path)
    if cache[path] == nil then
        local ok, value = pcall(love.graphics.newImage, path)
        cache[path] = ok and value or false
    end
    return cache[path]
end

local hulls = {
    fighter = {1.35,0, -0.8,-0.65, -0.35,0, -0.8,0.65},
    interceptor = {1.6,0, -1,-0.85, -0.5,0, -1,0.85},
    scout = {1.5,0, -0.7,-0.42, -0.35,0, -0.7,0.42},
    bomber = {1.1,0, 0.25,-0.85, -0.9,-0.7, -1,0, -0.9,0.7, 0.25,0.85},
    heavy = {1.35,0, 0.5,-0.65, -1,-0.55, -1,0.55, 0.5,0.65},
    mothership = {1.5,0, 0.7,-0.55, -0.6,-0.8, -1.2,-0.35, -1.2,0.35, -0.6,0.8, 0.7,0.55},
    repair = {1,0, 0.25,-0.55, -0.8,-0.55, -1,0, -0.8,0.55, 0.25,0.55},
}
hulls.carrier = hulls.mothership
hulls.gunship = hulls.heavy
hulls.missile_frigate = hulls.heavy
hulls.light=hulls.interceptor
hulls.sniper={1.9,0,0.1,-0.22,-1,-0.48,-0.8,0,-1,0.48,0.1,0.22}
hulls.artillery={1.2,0.25,1.2,-0.25,0,-0.8,-1.1,-0.7,-1.1,0.7,0,0.8}
hulls.tiger={1.1,-0.5,-0.9,-0.75,-1.2,0,-0.9,0.75,1.1,0.5,0.8,0}

function Ships.draw(u, player_team)
    local g = love.graphics
    local radius = u.radius or 15
    local scale = 1 + math.min(u.z or 0, 260) / 520
    local y = u.y - (u.z or 0) * 0.22
    local friendly = u.team == player_team
    local accent = friendly and {0.25,0.88,0.76} or {1,0.32,0.22}
    local hull = hulls[u.unit_type] or hulls.heavy
    g.push("all")
    if u.skill_pending then
        local progress=1-u.skill_pending/require("config.pacing").skill_windup
        g.setColor(1,0.8,0.25,0.7)
        g.setLineWidth(2)
        g.arc("line","open",u.x,y,radius*2.2,0,math.pi*2*math.max(0.01,progress))
        g.circle("line",u.x,y,radius*(2.8-progress))
    end
    if u.flight_trail then
        g.setLineWidth(1.2)
        for i=2,#u.flight_trail do
            local a,b=u.flight_trail[i-1],u.flight_trail[i]
            g.setColor(accent[1],accent[2],accent[3],i/#u.flight_trail*0.3)
            g.line(a.x,a.y,b.x,b.y)
        end
    end
    g.translate(u.x, y)
    g.scale(scale)
    if u.selected then
        local ring = image("assets/comms/selection.agi.png")
        g.setColor(accent[1],accent[2],accent[3],0.8)
        if ring then
            local s = radius * 3.6 / ring:getWidth()
            g.draw(ring,0,0,0,s,s,ring:getWidth()/2,ring:getHeight()/2)
        end
    end
    g.rotate(u.angle or 0)
    local speed = math.sqrt((u.vx or 0)^2 + (u.vy or 0)^2)
    if speed > 1 then
        local frame=math.floor(((u.game and u.game.level_time) or 0)*18+(u.id or 0))%8
        local flame = image("assets/effects/thrusterg"..frame..".agi.png")
        if flame then
            g.setBlendMode("add")
            g.setColor(0.35,0.75,1,0.8)
            local length = radius * (1.2 + math.min(speed / 160, 1))
            g.draw(flame,-radius*0.85,0,math.pi/2,radius*0.65/flame:getWidth(),length/flame:getHeight(),flame:getWidth()/2,0)
            g.setBlendMode("alpha")
        end
    end
    if u.muzzle_time and u.game and u.game.level_time-u.muzzle_time<0.08 then
        local flash=image("assets/effects/impact-flash.png")
        if flash then
            g.setBlendMode("add")
            g.setColor(1,0.8,0.4,0.8)
            local s=radius*0.8/flash:getWidth()
            g.draw(flash,radius*1.2,0,0,s,s,flash:getWidth()/2,flash:getHeight()/2)
            g.setBlendMode("alpha")
        end
    end
    g.scale(radius, radius * (1 - math.abs(u.bank or 0)*0.12))
    g.translate(0,0.13)
    g.setColor(0.07,0.09,0.12,1)
    g.polygon("fill", hull)
    g.translate(0,-0.13)
    g.setColor(0.48,0.56,0.61,1)
    if (u.flash_timer or 0)>0 then g.setColor(1,1,1,1) end
    g.polygon("fill",hull)
    g.setLineWidth(0.045)
    g.setColor(0.78,0.85,0.87,0.9)
    g.polygon("line",hull)
    g.setColor(0.22,0.29,0.34,1)
    g.polygon("fill",0.9,0,-0.65,-0.28,-0.9,0,-0.65,0.28)
    g.setColor(accent)
    g.polygon("fill",0.65,0,0.05,-0.17,-0.25,0,0.05,0.17)
    g.setColor(0.9,0.94,0.94,1)
    g.rectangle("fill",-0.65,-0.45,0.4,0.08)
    g.rectangle("fill",-0.65,0.37,0.4,0.08)
    g.pop()
    if (u.shield or 0)>0 then
        g.setColor(0.3,0.8,1,0.35)
        g.ellipse("line",u.x,y,radius*scale*1.65,radius*scale*1.25)
    end
    if u.selected or u.hp < u.max_hp then
        local w = radius*scale*2.6
        g.setColor(0.05,0.07,0.08,0.9)
        g.rectangle("fill",u.x-w/2,y-radius*scale-12,w,3)
        g.setColor(accent)
        g.rectangle("fill",u.x-w/2,y-radius*scale-12,w*math.max(0,u.hp/u.max_hp),3)
    end
    g.setColor(1,1,1,1)
end
return Ships

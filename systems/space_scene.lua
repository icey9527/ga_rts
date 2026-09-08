-- Space scene rendering with dome-like background mapping.
local SpaceScene = {}
local image_cache = {}
local dome_shader

local function load_image(path)
    if not path or path == "" then return nil end
    if image_cache[path] ~= nil then return image_cache[path] end
    local ok, img = pcall(love.graphics.newImage, path)
    image_cache[path] = ok and img or false
    return image_cache[path]
end

local function get_shader()
    if dome_shader then return dome_shader end
    local ok, shader = pcall(love.graphics.newShader, [[
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec2 p = tc * 2.0 - 1.0;
            float r = length(p);
            float dome = clamp(1.0 - r * r * 0.85, 0.0, 1.0);
            vec2 warped = p / (1.0 + r * 0.8);
            warped = warped * 0.5 + 0.5;
            vec4 c = Texel(tex, warped);
            c.rgb *= dome;
            c.a *= dome;
            return c * color;
        }
    ]])
    dome_shader = ok and shader or false
    return dome_shader or nil
end

function SpaceScene.default_layers(level_name)
    local seed = 0
    for i = 1, #(level_name or "") do
        seed = (seed + level_name:byte(i) * i) % 9973
    end
    return {
        {type = "sun", x = -650 + (seed % 400), y = -260 + (seed % 260), radius = 420},
        {type = seed % 2 == 0 and "white_hole" or "void_rift", x = 1600 + (seed % 260), y = 250 + (seed % 520), radius = 260},
    }
end

function SpaceScene.new(layer)
    return {
        type = layer.type or "nebula",
        x = layer.x or 0,
        y = layer.y or 0,
        radius = layer.radius or 500,
        strength = layer.strength or 1.0,
    }
end

local function draw_dome_background(game, camera)
    local cfg = game.background
    if not cfg or not cfg.image then return false end

    local img = load_image(cfg.image)
    if not img then return false end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local iw, ih = img:getWidth(), img:getHeight()
    local scale = math.max(w / iw, h / ih) * (cfg.scale or 1.0)
    local parallax = cfg.parallax or 0.03
    local zoom = camera.zoom or 1.0
    local ox = (camera.x or 0) * parallax
    local oy = (camera.y or 0) * parallax
    local sx = scale * (0.92 + zoom * 0.08)
    local sy = scale * (0.92 + zoom * 0.08)

    if get_shader() then
        love.graphics.setShader(dome_shader)
    end

    love.graphics.setColor(1, 1, 1, cfg.alpha or 1)
    love.graphics.draw(img, w / 2 - ox, h / 2 - oy, 0, sx, sy, iw / 2, ih / 2)

    if cfg.glow then
        local glow = load_image(cfg.glow)
        if glow then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 0.94, 0.78, cfg.glow_alpha or 0.28)
            love.graphics.draw(glow, w / 2 - ox * 0.75, h / 2 - oy * 0.75, 0, sx, sy, glow:getWidth() / 2, glow:getHeight() / 2)
            love.graphics.setBlendMode("alpha")
        end
    end

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

function SpaceScene.draw_background(game, camera)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.clear(0.015, 0.02, 0.04)
    draw_dome_background(game, camera)

    -- subtle lens haze only; no artificial large circles.
    love.graphics.setColor(0.015, 0.02, 0.025, 0.48)
    love.graphics.rectangle("fill", 0, 0, w, h)
    for _, star in ipairs(game.stars) do
        local parallax = star.layer * 0.025
        local x = (star.x - camera.x * parallax) % w
        local y = (star.y - camera.y * parallax) % h
        love.graphics.setColor(0.8,0.88,1,star.brightness/255*0.65)
        love.graphics.circle("fill",x,y,star.size*0.4)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function SpaceScene.draw_world_layers(game)
    local t = love.timer.getTime()
    for _, layer in ipairs(game.environment_layers) do
        if layer.type == "sun" then
            local pulse = 0.08 + math.sin(t * 1.2) * 0.02
            love.graphics.setColor(1.0, 0.72, 0.25, 0.10)
            love.graphics.circle("fill", layer.x, layer.y, layer.radius * pulse)
        elseif layer.type == "white_hole" then
            love.graphics.setColor(0.75, 0.95, 1.0, 0.08)
            love.graphics.circle("fill", layer.x, layer.y, layer.radius * 0.18)
        elseif layer.type == "void_rift" then
            love.graphics.setColor(0.08, 0.85, 1.0, 0.06)
            love.graphics.circle("line", layer.x, layer.y, layer.radius * 0.36)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function SpaceScene.apply_fields(game, dt)
    for _, layer in ipairs(game.environment_layers) do
        if layer.type == "sun" or layer.type == "white_hole" or layer.type == "void_rift" then
            for _, u in ipairs(game.units) do
                if u.alive and u.state ~= "dead" then
                    local dx, dy = u.x - layer.x, u.y - layer.y
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d < layer.radius then
                        local k = 1 - d / layer.radius
                        if layer.type == "sun" then
                            u.energy = math.min(u.max_energy, u.energy + 10 * k * dt)
                        elseif layer.type == "white_hole" then
                            u.shield = math.min((u.shield or 0) + 6 * k * dt, 40)
                            u.shield_time = math.max(u.shield_time or 0, 0.4)
                        elseif layer.type == "void_rift" then
                            u.energy = math.max(0, u.energy - 8 * k * dt)
                        end
                    end
                end
            end
        end
    end
end

return SpaceScene

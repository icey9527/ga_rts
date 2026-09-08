-- Terrain / obstacle system
local Terrain = {}

function Terrain.new(x, y, ttype, radius)
    return {
        x = x, y = y,
        type = ttype or "asteroid",
        radius = radius or 50,
        hp = 100,
        max_hp = 100,
    }
end

function Terrain.draw(obj)
    if obj.type == "asteroid" then
        love.graphics.setColor(0.35, 0.3, 0.28)
        love.graphics.circle("fill", obj.x, obj.y, obj.radius)
        love.graphics.setColor(0.45, 0.4, 0.35)
        love.graphics.circle("line", obj.x, obj.y, obj.radius)
        -- craters
        for i = 1, 3 do
            local a = i * 2.1 + obj.x * 0.01
            local r = obj.radius * 0.3
            love.graphics.setColor(0.25, 0.2, 0.18)
            love.graphics.circle("fill", obj.x + math.cos(a)*obj.radius*0.4, obj.y + math.sin(a)*obj.radius*0.4, r)
        end
    elseif obj.type == "debris" then
        love.graphics.setColor(0.4, 0.38, 0.35)
        love.graphics.circle("fill", obj.x, obj.y, obj.radius)
        love.graphics.setColor(0.5, 0.45, 0.4)
        love.graphics.circle("line", obj.x, obj.y, obj.radius)
    elseif obj.type == "crystal" then
        love.graphics.setColor(0.2, 0.6, 0.9, 0.6)
        love.graphics.circle("fill", obj.x, obj.y, obj.radius)
        love.graphics.setColor(0.4, 0.8, 1, 0.8)
        love.graphics.circle("line", obj.x, obj.y, obj.radius)
        love.graphics.setColor(1, 1, 1, 1)
    elseif obj.type == "barrier" then
        love.graphics.setColor(0.3, 0.3, 0.8, 0.5)
        love.graphics.circle("fill", obj.x, obj.y, obj.radius)
        love.graphics.setColor(0.5, 0.5, 1, 0.7)
        love.graphics.circle("line", obj.x, obj.y, obj.radius)
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Terrain

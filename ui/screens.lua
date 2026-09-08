local Fonts = require("core.fonts")

local Screens = {}

function Screens.update(dt)
    Screens.clock = (Screens.clock or 0) + dt
end

function Screens.draw_victory(game, level_name)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local clock = Screens.clock or 0

    love.graphics.clear(0.02, 0.08, 0.04)
    love.graphics.setColor(0.0, 0.12, 0.05, 0.85)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(Fonts.get(48))
    love.graphics.setColor(0.25, 1, 0.38, 0.72 + math.sin(clock * 2) * 0.25)
    love.graphics.printf("胜利", 0, h * 0.15, w, "center")

    love.graphics.setFont(Fonts.get(28))
    love.graphics.setColor(1, 0.88, 0.26)
    love.graphics.printf((level_name or "") .. "  总分: " .. (game.score or 0), 0, h * 0.29, w, "center")

    love.graphics.setFont(Fonts.get(18))
    local y = h * 0.42
    for k, v in pairs(game.score_breakdown or {}) do
        love.graphics.setColor(0.84, 0.88, 0.90)
        love.graphics.printf(k .. ": " .. v, 0, y, w, "center")
        y = y + 30
    end

    love.graphics.setColor(1, 0.82, 0.25)
    love.graphics.printf("按回车 / 空格 / 点击返回主菜单", 0, h - 82, w, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function Screens.draw_defeat()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local clock = Screens.clock or 0

    love.graphics.clear(0.09, 0.025, 0.025)
    love.graphics.setColor(0.14, 0, 0, 0.86)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setFont(Fonts.get(52))
    love.graphics.setColor(0.95, 0.22, 0.20, 0.74 + math.sin(clock * 2) * 0.24)
    love.graphics.printf("失败", 0, h * 0.36, w, "center")

    love.graphics.setFont(Fonts.get(18))
    love.graphics.setColor(0.78, 0.78, 0.82)
    love.graphics.printf("按回车 / 空格 / 点击返回主菜单", 0, h - 82, w, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function Screens.accept_key(key)
    return key == "return" or key == "space" or key == "escape"
end

return Screens

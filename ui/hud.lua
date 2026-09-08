local Fonts = require("core.fonts")

local HUD = {}

function HUD.draw(game, level_name, command_mode)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setFont(Fonts.get(14))

    love.graphics.setColor(0, 0, 0, 0.48)
    love.graphics.rectangle("fill", 0, 0, w, 32)
    love.graphics.setColor(0.24, 0.28, 0.34, 0.45)
    love.graphics.line(0, 32, w, 32)

    love.graphics.setColor(0.86, 0.82, 0.34)
    love.graphics.print("关卡: " .. (level_name or "---"), 240, 7)
    love.graphics.setColor(0.74, 0.78, 0.82)
    love.graphics.print(string.format("时间: %.1f", game.level_time), 460, 7)

    local my_count = #game:get_units_by_team(game.player_team)
    local enemy_count = #game:get_enemy_units(game.player_team)
    love.graphics.setColor(0.30, 0.92, 0.38)
    love.graphics.print("友军: " .. my_count, 610, 7)
    love.graphics.setColor(0.94, 0.32, 0.30)
    love.graphics.print("敌军: " .. enemy_count, 700, 7)
    love.graphics.setColor(0.95, 0.82, 0.25)
    love.graphics.print("分数: " .. (game.score or 0), 790, 7)

    if command_mode == "targeting" then
        love.graphics.setFont(Fonts.get(18))
        love.graphics.setColor(1, 0.90, 0.22, 0.88)
        love.graphics.printf("选择目标中... 左键确认 | 右键取消", 0, h - 54, w, "center")
    elseif game:is_paused() then
        love.graphics.setFont(Fonts.get(18))
        love.graphics.setColor(1, 0.80, 0.12, 0.72)
        love.graphics.printf("游戏已暂停", 0, h - 54, w, "center")
    end

    love.graphics.setFont(Fonts.get(12))
    love.graphics.setColor(0.48, 0.52, 0.58)
    love.graphics.print("TAB: 面板 | 左键: 选择 | 右键: 命令 | 滚轮: 缩放 | 中键拖拽: 平移 | ESC: 菜单",
        10, h - 18)
    love.graphics.setColor(1, 1, 1, 1)
end

return HUD

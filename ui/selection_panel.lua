local Fonts = require("core.fonts")

local SelectionPanel = {}

local labels = {
    idle = "待命",
    moving = "移动",
    attacking = "攻击",
    circle_strafing = "绕飞",
    repairing = "修理",
    following = "跟随",
    returning = "返航",
    supplying = "补给",
    undocking = "离舰",
    disabled = "瘫痪",
}

local function bar(x, y, w, h, ratio, r, g, b)
    ratio = math.max(0, math.min(1, ratio or 0))
    love.graphics.setColor(0.10, 0.12, 0.16, 0.92)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(r, g, b, 0.95)
    love.graphics.rectangle("fill", x, y, w * ratio, h, 3, 3)
end

function SelectionPanel.draw(game)
    if game.researcher and game.researcher.life>0 then return end
    local inspected = game.inspected_unit
    if inspected and not inspected.alive then inspected = nil; game.inspected_unit = nil end
    if #game.selected_units == 0 and not inspected then return end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local panel_w, panel_h = 340, 150
    local x,y=w-panel_w-18, h-panel_h-30
    if game.advisor and game.advisor.life>0 then
        if w<1150 then return end
    end

    love.graphics.setColor(0.025, 0.045, 0.080, 0.90)
    love.graphics.rectangle("fill", x, y, panel_w, panel_h, 12, 12)
    love.graphics.setColor(0.20, 0.58, 0.88, 0.58)
    love.graphics.rectangle("line", x, y, panel_w, panel_h, 12, 12)

    love.graphics.setFont(Fonts.get(15))
    love.graphics.setColor(0.95, 0.90, 0.34)

    if #game.selected_units == 1 or inspected then
        local u = inspected or game.selected_units[1]
        local state = labels[u.state] or u.state
        love.graphics.print(require("ui.pilots").profile(u).name, x + 18, y + 14)
        love.graphics.setFont(Fonts.get(12))
        love.graphics.setColor(0.70, 0.78, 0.88)
        love.graphics.print(string.format("%s | 高度 %.0f | %s", u.type_name or u.name, u.z or 0, state), x + 18, y + 38)

        bar(x + 18, y + 66, panel_w - 36, 9, u.hp / u.max_hp, 0.85, 0.22, 0.18)
        bar(x + 18, y + 86, panel_w - 36, 8, u.max_energy > 0 and u.energy / u.max_energy or 0, 0.20, 0.48, 0.95)
        if u.unit_type ~= "mothership" then
            bar(x + 18, y + 105, panel_w - 36, 7, u.sp / u.max_sp, 0.95, 0.78, 0.18)
        end

        love.graphics.setColor(0.82, 0.88, 0.94)
        love.graphics.print(string.format("HP %d/%d   EN %d/%d   DMG %d",
            math.floor(u.hp), u.max_hp, math.floor(u.energy), u.max_energy, u.attack_damage or 0), x + 18, y + 124)
    else
        love.graphics.print("编队选择", x + 18, y + 14)
        love.graphics.setFont(Fonts.get(13))
        love.graphics.setColor(0.82, 0.88, 0.94)
        love.graphics.print("单位数量: " .. #game.selected_units, x + 18, y + 44)

        local hp, max_hp, energy, max_energy = 0, 0, 0, 0
        for _, u in ipairs(game.selected_units) do
            hp = hp + u.hp
            max_hp = max_hp + u.max_hp
            energy = energy + u.energy
            max_energy = max_energy + u.max_energy
        end
        bar(x + 18, y + 76, panel_w - 36, 10, hp / math.max(1, max_hp), 0.85, 0.22, 0.18)
        bar(x + 18, y + 102, panel_w - 36, 9, energy / math.max(1, max_energy), 0.20, 0.48, 0.95)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return SelectionPanel

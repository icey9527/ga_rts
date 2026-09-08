-- Right-click context menu
local Fonts = require("core.fonts")
local ContextMenu = {}

function ContextMenu.new()
    local self = { active = false, x = 0, y = 0, options = {}, width = 168, item_h = 30 }
    setmetatable(self, {__index = ContextMenu})
    return self
end

function ContextMenu:show(x, y, options)
    self.active = true
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    self.x = math.max(8,math.min(x, w - self.width - 12))
    self.y = math.max(8,math.min(y, h - #options * self.item_h - 12))
    self.options = options
end

function ContextMenu:hide()
    self.active = false
end

function ContextMenu:get_clicked(mx, my)
    if not self.active then return nil end
    local h = #self.options * self.item_h
    if mx >= self.x and mx <= self.x + self.width and my >= self.y and my <= self.y + h then
        local idx = math.floor((my - self.y) / self.item_h) + 1
        if idx >= 1 and idx <= #self.options then
            return self.options[idx][2]  -- return action key
        end
    end
    return nil
end

function ContextMenu:draw()
    if not self.active then return end

    local h = #self.options * self.item_h
    local font = Fonts.get(14)

    -- background
    love.graphics.setColor(0.02, 0.05, 0.10, 0.94)
    love.graphics.rectangle("fill", self.x, self.y, self.width, h, 8, 8)
    love.graphics.setColor(0.15, 0.62, 0.95, 0.7)
    love.graphics.rectangle("line", self.x, self.y, self.width, h, 8, 8)
    love.graphics.setColor(0.0, 0.75, 1.0, 0.22)
    love.graphics.rectangle("fill", self.x + 2, self.y + 2, 3, h - 4, 3, 3)

    local mx, my = love.mouse.getPosition()
    love.graphics.setFont(font)
    for i, opt in ipairs(self.options) do
        local oy = self.y + (i - 1) * self.item_h
        -- hover highlight
        if mx >= self.x and mx <= self.x + self.width and my >= oy and my <= oy + self.item_h then
            love.graphics.setColor(0.10, 0.35, 0.58, 0.85)
            love.graphics.rectangle("fill", self.x + 5, oy + 3, self.width - 10, self.item_h - 6, 6, 6)
        end
        love.graphics.setColor(0.90, 0.96, 1.0)
        love.graphics.print(opt[1], self.x + 16, oy + 7)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ContextMenu

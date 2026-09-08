local Fonts = require("core.fonts")

local MainMenu = {}

function MainMenu.new(level_names, high_scores)
    local self = {
        level_names = level_names or {},
        high_scores = high_scores or {},
        selected = 1,
        scroll = 0,
        item_h = 58,
        visible = 7,
        list_y = 148,
        clock = 0,
    }
    setmetatable(self, {__index = MainMenu})
    return self
end

function MainMenu:set_levels(level_names, high_scores)
    self.level_names = level_names or {}
    self.high_scores = high_scores or {}
    self.selected = math.max(1, math.min(self.selected, math.max(1, #self.level_names)))
    self:clamp_scroll()
end

function MainMenu:clamp_scroll()
    local total_h = #self.level_names * self.item_h
    local visible_h = self.visible * self.item_h
    self.scroll = math.max(0, math.min(self.scroll, math.max(0, total_h - visible_h)))
end

function MainMenu:ensure_selected_visible()
    local visible_h = self.visible * self.item_h
    local sel_y = (self.selected - 1) * self.item_h
    if sel_y < self.scroll then
        self.scroll = sel_y
    elseif sel_y >= self.scroll + visible_h - self.item_h then
        self.scroll = sel_y - visible_h + self.item_h
    end
    self:clamp_scroll()
end

function MainMenu:update(dt)
    self.visible=math.max(3,math.floor((love.graphics.getHeight()-self.list_y-66)/self.item_h))
    self:clamp_scroll()
    self.clock = self.clock + dt
    local mx, my = love.mouse.getPosition()
    local w = love.graphics.getWidth()
    local visible_h = self.visible * self.item_h
    if my >= self.list_y and my <= self.list_y + visible_h and mx >= 150 and mx <= w - 150 then
        local idx = math.floor((my - self.list_y + self.scroll) / self.item_h) + 1
        if idx >= 1 and idx <= #self.level_names then self.selected = idx end
    end
end

function MainMenu:keypressed(key)
    if key == "escape" then return "quit" end
    if key == "return" or key == "space" then
        if #self.level_names > 0 then return "start", self.selected end
    elseif key == "up" then
        self.selected = math.max(1, self.selected - 1)
        self:ensure_selected_visible()
    elseif key == "down" then
        self.selected = math.min(#self.level_names, self.selected + 1)
        self:ensure_selected_visible()
    end
    return nil
end

function MainMenu:wheelmoved(_, dy)
    self.scroll = self.scroll - dy * 45
    self:clamp_scroll()
end

function MainMenu:mousepressed(mx, my, button)
    if button ~= 1 then return nil end
    local visible_h = self.visible * self.item_h
    if my >= self.list_y and my <= self.list_y + visible_h and mx >= 150 and mx <= love.graphics.getWidth() - 150 then
        local idx = math.floor((my - self.list_y + self.scroll) / self.item_h) + 1
        if idx >= 1 and idx <= #self.level_names then return "start", idx end
    end
    return nil
end

function MainMenu:draw()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local font_big = Fonts.get(36)
    local font_med = Fonts.get(19)
    local font_sm = Fonts.get(16)
    local visible_h = self.visible * self.item_h
    local total_h = #self.level_names * self.item_h

    love.graphics.clear(0.025, 0.035, 0.075)
    local background=require("ui.pilots").image("assets/backgrounds/ob1205a_1.bmp.png")
    if background then
        love.graphics.setColor(0.3,0.38,0.4,1)
        local scale=math.max(w/background:getWidth(),h/background:getHeight())
        love.graphics.draw(background,w/2,h/2,0,scale,scale,background:getWidth()/2,background:getHeight()/2)
    end

    love.graphics.setFont(font_big)
    love.graphics.setColor(1, 0.90, 0.30)
    love.graphics.printf("深空指挥", 0, 52, w, "center")
    love.graphics.setFont(font_sm)
    love.graphics.setColor(0.72, 0.78, 0.92)
    love.graphics.printf("Deep Space Command", 0, 98, w, "center")

    if #self.level_names == 0 then
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.printf("没有找到关卡文件", 0, h * 0.45, w, "center")
        return
    end

    love.graphics.setScissor(148,self.list_y-4,w-296,visible_h+4)
    for i = 1, #self.level_names do
        local y = self.list_y + (i - 1) * self.item_h - self.scroll
        if y > self.list_y - self.item_h and y < self.list_y + visible_h then
            local is_sel = i == self.selected
            if is_sel then
                love.graphics.setColor(0.10, 0.18, 0.32, 0.82)
                love.graphics.rectangle("fill", 150, y - 3, w - 300, self.item_h - 4, 8, 8)
                love.graphics.setColor(0.35, 0.62, 0.95, 0.9)
                love.graphics.rectangle("line", 150, y - 3, w - 300, self.item_h - 4, 8, 8)
            end

            love.graphics.setFont(font_med)
            love.graphics.setColor(is_sel and 1 or 0.72, is_sel and 0.92 or 0.75, is_sel and 0.36 or 0.62)
            love.graphics.print(self.level_names[i], 170, y + 8)

            local hs = self.high_scores[i] or 0
            if hs > 0 then
                love.graphics.setFont(font_sm)
                love.graphics.setColor(0.86, 0.74, 0.25)
                love.graphics.print("最高分: " .. hs, w - 260, y + 23)
            end
        end
    end

    love.graphics.setScissor()
    if total_h > visible_h then
        local bar_h = math.max(30, visible_h * visible_h / total_h)
        local bar_y = self.list_y + self.scroll * visible_h / total_h
        love.graphics.setColor(0.22, 0.24, 0.30, 0.6)
        love.graphics.rectangle("fill", w - 34, self.list_y, 8, visible_h)
        love.graphics.setColor(0.55, 0.62, 0.72, 0.85)
        love.graphics.rectangle("fill", w - 34, bar_y, 8, bar_h)
    end

    love.graphics.setFont(font_sm)
    love.graphics.setColor(0.55, 0.60, 0.70)
    love.graphics.printf("↑↓ 选择 | 回车/点击 开始 | ESC 退出", 0, h - 42, w, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return MainMenu

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
        confirm = false,
        confirm_rects = {},
        page = "home",
        menu_rects = {},
        setting_rects = {},
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
    -- ESC 不再直接退出：先弹确认，回车才真正退出，防止误触。
    if key == "escape" and self.page == "home" then
        self.confirm = not self.confirm
        return nil
    end
    if self.confirm then
        if key == "return" or key == "space" then return "quit" end
        return nil
    end
    if self.page == "home" then
        if key == "up" then self.selected=math.max(1,self.selected-1)
        elseif key == "down" then self.selected=math.min(5,self.selected+1)
        elseif key == "return" or key == "space" then
            local actions={"levels","story","preview","settings","quit"}
            local a=actions[self.selected]
            if a=="levels" then self.page="levels"; self.selected=1
            elseif a=="settings" then self.page="settings"; self.selected=1
            elseif a=="quit" then self.confirm=true
            else return nil
            end
        end
        return nil
    elseif self.page == "settings" then
        local P=require("systems.preferences")
        if key=="escape" then self.page="home";self.selected=1
        elseif key=="left" or key=="right" then
            local d=key=="left" and -0.1 or 0.1
            local v=math.max(0,math.min(1,P.get("volume",0.9)+d)); P.set("volume",math.floor(v*10+0.5)/10)
        elseif key=="return" or key=="space" then
            if self.selected==2 then P.set("auto_skill_all",not P.get("auto_skill_all",false))
            elseif self.selected==3 then P.set("disable_enemy_reinforcements",not P.get("disable_enemy_reinforcements",false))
            elseif self.selected==4 then P.values={};P.save()
            end
        elseif key=="up" then self.selected=math.max(1,self.selected-1)
        elseif key=="down" then self.selected=math.min(4,self.selected+1)
        end
        return nil
    elseif self.page == "levels" and key=="escape" then self.page="home";self.selected=1;return nil end
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

-- 皮肤系统：扫描 teams/<队>/skins/<皮肤名>/，有 skins 目录的队伍才出现在切换列表。
-- getInfo 对目录首返回值为 nil，目录存在性一律用 getDirectoryItems 判断。
function MainMenu:skin_teams()
    local out={}
    for _,team in ipairs(love.filesystem.getDirectoryItems("teams")) do
        local sdir="teams/"..team.."/skins"
        local subs=love.filesystem.getDirectoryItems(sdir)
        if #subs>0 then
            local skins={"default"}
            for _,sk in ipairs(subs) do
                if sk~="default" and #(love.filesystem.getDirectoryItems(sdir.."/"..sk))>0 then skins[#skins+1]=sk end
            end
            if #skins>1 then out[#out+1]={team=team,skins=skins} end
        end
    end
    return out
end
function MainMenu:cycle_skin(mx,my)
    for team,rect in pairs(self._skin_rects or {}) do
        if mx>=rect[1] and mx<=rect[1]+rect[3] and my>=rect[2] and my<=rect[2]+rect[4] then
            local Preferences=require("systems.preferences")
            local skins=self._skin_skins[team] or {"default"}
            local cur=Preferences.get("skin_player."..team,"default")
            local idx=1
            for i,s in ipairs(skins) do if s==cur then idx=i break end end
            local nsk=skins[idx%#skins+1]
            Preferences.set("skin_player."..team,nsk)
            return true
        end
    end
    return false
end

function MainMenu:mousepressed(mx, my, button)
    if button ~= 1 then return nil end
    if self.confirm then
        local yes,no=self.confirm_rects[1],self.confirm_rects[2]
        if yes and mx>=yes[1] and mx<=yes[1]+yes[3] and my>=yes[2] and my<=yes[2]+yes[4] then return "quit" end
        self.confirm=false
        return nil
    end
    if self.page=="home" then
        for i,r in ipairs(self.menu_rects) do if mx>=r[1] and mx<=r[1]+r[3] and my>=r[2] and my<=r[2]+r[4] then
            self.selected=i; if i==1 then self.page="levels";self.selected=1 elseif i==4 then self.page="settings";self.selected=1 elseif i==5 then self.confirm=true end; return nil
        end end
        return nil
    elseif self.page=="settings" then
        local P=require("systems.preferences")
        for i,r in ipairs(self.setting_rects) do if mx>=r[1] and mx<=r[1]+r[3] and my>=r[2] and my<=r[2]+r[4] then
            if i==1 then P.set("volume",math.max(0,math.min(1,(mx-r[1])/r[3]))) elseif i==2 then P.set("auto_skill_all",not P.get("auto_skill_all",false)) elseif i==3 then P.set("disable_enemy_reinforcements",not P.get("disable_enemy_reinforcements",false)) elseif i==4 then P.values={};P.save() end
            return nil
        end end
        if my>love.graphics.getHeight()-70 then self.page="home" end
        return nil
    elseif self.page=="levels" and my<120 then self.page="home";return nil end
    if self:cycle_skin(mx,my) then return nil end
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
    if self.page=="home" then
        love.graphics.clear(0.025,0.035,0.075)
        -- 头像俄罗斯方块背景（进入主菜单时重建，canvas 预渲染一次 draw）
        local mosaic=require("ui.menu_mosaic").get()
        if mosaic then love.graphics.draw(mosaic,0,0) end
        love.graphics.setFont(font_big);love.graphics.setColor(1,0.90,0.30);love.graphics.printf("深空指挥",0,52,w,"center")
        love.graphics.setFont(font_sm);love.graphics.setColor(0.72,0.78,0.92);love.graphics.printf("DEEP SPACE COMMAND",0,98,w,"center")
        local labels={"关卡模式","剧情模式（未开放）","必杀技预览（准备中）","设置","退出游戏"};self.menu_rects={}
        for i,label in ipairs(labels) do local bw,bh=420,54;local x=(w-bw)/2;local y=160+(i-1)*70;self.menu_rects[i]={x,y,bw,bh};local on=i==self.selected
            love.graphics.setColor(on and 0.10 or 0.06,on and 0.22 or 0.10,on and 0.36 or 0.17,0.95);love.graphics.rectangle("fill",x,y,bw,bh,8,8)
            love.graphics.setColor(on and 0.35 or 0.18,on and 0.65 or 0.30,on and 0.95 or 0.45,0.9);love.graphics.rectangle("line",x,y,bw,bh,8,8)
            love.graphics.setColor(i==2 and 0.45 or 0.9,i==2 and 0.48 or 0.92,i==2 and 0.55 or 0.98,1);love.graphics.printf(label,x,y+15,bw,"center")
        end
        love.graphics.setColor(0.55,0.60,0.70);love.graphics.printf("上下选择 | 回车确认",0,h-42,w,"center");return
    elseif self.page=="settings" then
        love.graphics.clear(0.025,0.035,0.075);love.graphics.setFont(font_big);love.graphics.setColor(1,0.90,0.30);love.graphics.printf("设置",0,62,w,"center")
        local P=require("systems.preferences");local v=P.get("volume",0.9);local auto=P.get("auto_skill_all",false);local no_enemy=P.get("disable_enemy_reinforcements",false);self.setting_rects={}
        love.graphics.setFont(font_med);love.graphics.setColor(0.9,0.92,1);love.graphics.print("主音量",180,170);local bx,by,bw=360,178,360;self.setting_rects[1]={bx,by,bw,24};love.graphics.setColor(0.12,0.16,0.24);love.graphics.rectangle("fill",bx,by,bw,10,4,4);love.graphics.setColor(0.35,0.72,0.95);love.graphics.rectangle("fill",bx,by,bw*v,10,4,4)
        love.graphics.setColor(0.9,0.92,1);love.graphics.print("全员自动释放必杀技",180,245);self.setting_rects[2]={180,238,500,48};love.graphics.setColor(auto and 0.25 or 0.18,auto and 0.70 or 0.24,auto and 0.42 or 0.30,1);love.graphics.rectangle("fill",620,240,60,30,6,6);love.graphics.setColor(1,1,1);love.graphics.printf(auto and "开" or "关",620,246,60,"center")
        love.graphics.setColor(0.9,0.92,1);love.graphics.print("禁止敌方增援",180,305);self.setting_rects[3]={180,298,500,48};love.graphics.setColor(no_enemy and 0.25 or 0.18,no_enemy and 0.70 or 0.24,no_enemy and 0.42 or 0.30,1);love.graphics.rectangle("fill",620,300,60,30,6,6);love.graphics.setColor(1,1,1);love.graphics.printf(no_enemy and "开" or "关",620,306,60,"center")
        self.setting_rects[4]={250,380,300,48};love.graphics.setColor(0.16,0.28,0.42);love.graphics.rectangle("fill",250,380,300,48,8,8);love.graphics.setColor(0.9,0.92,1);love.graphics.printf("恢复默认",250,393,300,"center");love.graphics.setColor(0.55,0.60,0.70);love.graphics.printf("ESC 返回主菜单",0,h-42,w,"center");return
    end
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
    love.graphics.printf("↑↓ 选择 | 回车/点击 开始 | ESC 退出游戏（需确认）", 0, h - 42, w, "center")

    -- 皮肤切换：仅有 skins 目录的队伍显示，点击循环（写偏好，进战斗即生效）。
    self._skin_rects={}
    self._skin_skins={}
    local Registry=require("systems.pack_registry")
    local yy=h-70
    for _,t in ipairs(self:skin_teams()) do
        local ok,pack=pcall(function() return Registry.load(t.team) end)
        local name=(ok and pack and pack.team and pack.team.name) or t.team
        local cur=require("systems.preferences").get("skin_player."..t.team,"default")
        love.graphics.setFont(font_sm)
        love.graphics.setColor(0.78,0.84,0.98)
        love.graphics.print(name.."皮肤："..(cur=="default" and "默认" or cur).."（点击切换）",24,yy)
        self._skin_rects[t.team]={24,yy-4,340,26}
        self._skin_skins[t.team]=t.skins
        yy=yy-28
    end

    -- 标题徽章：取自原始素材库，作装饰水印。
    local logo = require("ui.pilots").image("assets/ui/title_logo.png")
    if logo then
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1, 0.16)
        local lw = math.min(430, w * 0.34)
        love.graphics.draw(logo, w - lw * 0.42 - 24, h * 0.30, 0, lw / logo:getWidth(), lw / logo:getWidth(), logo:getWidth() / 2, logo:getHeight() / 2)
        love.graphics.pop()
    end

    if self.confirm then
        local pw, ph = 380, 150
        local px, py = (w - pw) / 2, (h - ph) / 2
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(0.04, 0.08, 0.14, 0.97)
        love.graphics.rectangle("fill", px, py, pw, ph, 12, 12)
        love.graphics.setColor(0.35, 0.62, 0.95, 0.9)
        love.graphics.rectangle("line", px, py, pw, ph, 12, 12)
        love.graphics.setFont(font_med)
        love.graphics.setColor(0.95, 0.95, 1)
        love.graphics.print("确认退出游戏？", px + 28, py + 24)
        love.graphics.setFont(font_sm)
        love.graphics.setColor(0.7, 0.76, 0.88)
        love.graphics.print("进行中的战斗不会保存。", px + 28, py + 56)
        local by, bw, bh = py + 92, 140, 38
        self.confirm_rects = {
            {px + 40, by, bw, bh},
            {px + pw - bw - 40, by, bw, bh},
        }
        love.graphics.setColor(0.85, 0.30, 0.26, 0.95)
        love.graphics.rectangle("fill", self.confirm_rects[1][1], by, bw, bh, 8, 8)
        love.graphics.setColor(0.22, 0.50, 0.30, 0.95)
        love.graphics.rectangle("fill", self.confirm_rects[2][1], by, bw, bh, 8, 8)
        love.graphics.setFont(font_med)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("退出", self.confirm_rects[1][1], by + 9, bw, "center")
        love.graphics.printf("取消", self.confirm_rects[2][1], by + 9, bw, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return MainMenu

local Fonts = require("core.fonts")
local Pilots = require("ui.pilots")
local Panel = {}
local labels = {idle="待命",moving="航行",attacking="交战",repairing="维修",following="护航",returning="返航",supplying="补给",undocking="离舰",disabled="失能"}
function Panel.new()
    return setmetatable({visible=true,x=12,y=48,width=238,scroll=0,item_h=58,side="friendly"},{__index=Panel})
end
function Panel:toggle() self.visible = not self.visible end
function Panel:layout(game)
    self.height = math.max(140,love.graphics.getHeight()-122)
    self.units = self.side=="friendly" and game:get_units_by_team(game.player_team) or game:get_enemy_units(game.player_team)
    self.scroll = math.max(0,math.min(self.scroll,math.max(0,#self.units*self.item_h-(self.height-42))))
end
function Panel:contains(mx,my)
    return self.visible and mx>=self.x and mx<=self.x+self.width and my>=self.y and my<=self.y+(self.height or 140)
end
function Panel:draw(game)
    if not self.visible then return end
    self:layout(game)
    local g=love.graphics
    g.push("all")
    g.setColor(0.035,0.045,0.05,0.96)
    g.rectangle("fill",self.x,self.y,self.width,self.height,4,4)
    g.setFont(Fonts.get(13))
    for i,side in ipairs({"friendly","enemy"}) do
        local active=self.side==side
        g.setColor(active and 0.16 or 0.07,active and 0.23 or 0.09,active and 0.25 or 0.1,1)
        g.rectangle("fill",self.x+(i-1)*self.width/2,self.y,self.width/2,36)
        g.setColor(side=="friendly" and 0.42 or 1,side=="friendly" and 0.9 or 0.48,0.65,1)
        local n=side=="friendly" and #game:get_units_by_team(game.player_team) or #game:get_enemy_units(game.player_team)
        g.printf((side=="friendly" and "我方  " or "敌方  ")..n,self.x+(i-1)*self.width/2,self.y+10,self.width/2,"center")
    end
    g.setScissor(self.x,self.y+42,self.width,self.height-42)
    local mx,my=love.mouse.getPosition()
    for i,u in ipairs(self.units) do
        local y=self.y+42+(i-1)*self.item_h-self.scroll
        if y+self.item_h>self.y+42 and y<self.y+self.height then
            if u.selected or game.inspected_unit==u then
                g.setColor(0.13,0.27,0.28,1)
            elseif self:contains(mx,my) and my>=y and my<y+self.item_h then
                g.setColor(0.12,0.15,0.17,1)
            else g.setColor(0.055,0.07,0.08,1) end
            g.rectangle("fill",self.x+4,y,self.width-8,self.item_h-2,2,2)
            local expression=(u.flash_timer or 0)>0 and "hit" or (u.state=="attacking" and "attack" or nil)
            Pilots.draw(u,self.x+8,y+5,44,expression)
            g.setColor(0.9,0.93,0.94,1)
            g.setFont(Fonts.get(12))
            g.printf(Pilots.profile(u).name,self.x+60,y+5,self.width-66)
            g.setColor(0.57,0.65,0.68,1)
            local caption=(u.type_name or u.name).." / "..(labels[u.state] or u.state)
            local font=Fonts.get(12)
            if font:getWidth(caption)>self.width-66 then font=Fonts.get(10) end
            g.setFont(font)
            g.printf(caption,self.x+60,y+23,self.width-66)
            local ratios={u.hp/u.max_hp,u.energy/math.max(1,u.max_energy),u.sp/math.max(1,u.max_sp)}
            for j,v in ipairs(ratios) do
                local by=y+40+(j-1)*4
                g.setColor(0.17,0.2,0.21,1)
                g.rectangle("fill",self.x+60,by,self.width-70,2)
                if j==1 then g.setColor(0.35,0.82,0.65,1) elseif j==2 then g.setColor(0.35,0.63,0.95,1) else g.setColor(0.92,0.75,0.35,1) end
                g.rectangle("fill",self.x+60,by,(self.width-70)*math.max(0,math.min(1,v)),2)
            end
        end
    end
    g.pop()
end
function Panel:handle_click(mx,my,game,button)
    self:layout(game)
    if not self:contains(mx,my) then return nil end
    if my<self.y+36 then
        if button==1 then self.side=mx<self.x+self.width/2 and "friendly" or "enemy"; self.scroll=0 end
        return "consume"
    end
    if my<self.y+42 then return "consume" end
    local unit=self.units[math.floor((my-self.y-42+self.scroll)/self.item_h)+1]
    if not unit then return "consume" end
    if self.side=="enemy" then return "inspect",unit end
    return button==2 and "select_and_menu" or "select",unit
end
function Panel:handle_scroll(dir) self.scroll=self.scroll-dir*self.item_h*2 end
return Panel

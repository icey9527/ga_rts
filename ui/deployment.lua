local UI={choice=1,formation="line"}
local Fonts=require("core.fonts")
local Pilots=require("ui.pilots")
local teams=require("config.squadrons")
function UI.click(x,y)
    local w=love.graphics.getWidth()
    if y>=120 and y<170 then UI.choice=x<w/2 and 1 or 2 end
    if y>=350 and y<398 then UI.formation=({"line","wedge","spread"})[math.max(1,math.min(3,math.floor((x-100)/((w-200)/3))+1))] end
    if x>=w/2-140 and x<=w/2+140 and y>=love.graphics.getHeight()-88 and y<=love.graphics.getHeight()-40 then return true end
end
function UI.draw(game)
    local g=love.graphics
    local w,h=g.getDimensions()
    require("systems.space_scene").draw_background(game,{x=0,y=0,zoom=0.5})
    g.setFont(Fonts.get(26));g.setColor(0.94,0.97,1,1);g.printf("模拟战 / 战前部署",0,56,w,"center")
    for i,t in ipairs(teams) do
        local x=100+(i-1)*(w-200)/2
        g.setColor(i==UI.choice and 0.18 or 0.07,0.28,0.31,0.95);g.rectangle("fill",x,120,(w-220)/2,48,4,4)
        g.setColor(1,1,1,1);g.setFont(Fonts.get(19));g.printf(t.name,x,134,(w-220)/2,"center")
    end
    local squad=teams[UI.choice]
    for i,m in ipairs(squad.members) do
        local x=100+(i-1)*(w-200)/#squad.members
        local u={character_id=m[1],unit_type=m[2]}
        Pilots.draw(u,x,210,48)
        g.setColor(0.9,0.95,1,1);g.setFont(Fonts.get(12));g.printf(Pilots.profile(u).name,x-8,272,(w-200)/#squad.members,"center")
    end
    for i,f in ipairs({"line","wedge","spread"}) do
        local x=100+(i-1)*(w-200)/3
        g.setColor(f==UI.formation and 0.22 or 0.07,0.3,0.3,0.95);g.rectangle("fill",x,350,(w-220)/3,48,4,4)
        g.setColor(1,1,1,1);g.setFont(Fonts.get(16));g.printf(({"横列 / 相互支援","楔形 / 纵深突进","散开 / 降低溅射"})[i],x,365,(w-220)/3,"center")
    end
    g.setColor(0.16,0.42,0.4,1);g.rectangle("fill",w/2-140,h-88,280,48,4,4)
    g.setColor(1,1,1,1);g.printf("进入演习",w/2-140,h-74,280,"center")
end
return UI

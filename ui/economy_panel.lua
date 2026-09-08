local Panel={}
local config=require("config.economy")
local Economy=require("systems.economy")
local Fonts=require("core.fonts")
function Panel.bounds()
    return love.graphics.getWidth()-264,72,252,math.min(510,love.graphics.getHeight()-252)
end
local function entries(game)
    local result={}
    for _,a in ipairs(config.actions) do
        local tab=a.tech and "research" or (a.id=="collector" and "build" or "fleet")
        if tab==(game.economy.tab or "fleet") then result[#result+1]=a end
    end
    return result
end
function Panel.contains(game,mx,my)
    local x,y,w,h=Panel.bounds()
    return game.economy and game.economy.open and mx>=x and mx<=x+w and my>=y and my<=y+h
end
function Panel.click(game,mx,my)
    local e=game.economy
    if not e then return false end
    local x,y,w,h=Panel.bounds()
    if mx>=x and mx<=x+w and my>=34 and my<68 then Economy.toggle(game); return true end
    if not Panel.contains(game,mx,my) then return false end
    if my<y+36 then
        if mx>x+w-28 then Economy.toggle(game)
        elseif mx>x+w-96 then
            local P=require("systems.preferences")
            local volume=tonumber(P.get("volume",0.65)) or 0.65
            P.set("volume",volume>0 and 0 or 0.65)
        end
        return true
    end
    if my<y+70 then
        e.tab=({"fleet","build","research"})[math.min(3,math.floor((mx-x)/(w/3))+1)]
        return true
    end
    local items=entries(game)
    local i=math.floor((my-y-76)/46)+1
    if my>=y+76 and i>=1 and i<=#items then Economy.enqueue(game,items[i].id); return true end
    local qy=y+80+#items*46
    if my>=qy then Economy.cancel(game,math.floor((my-qy)/28)+1) end
    return true
end
function Panel.draw(game)
    local e=game.economy
    if not e then return end
    local g=love.graphics
    local x,y,w,h=Panel.bounds()
    g.push("all"); g.setFont(Fonts.get(12))
    g.setColor(0.1,0.3,0.29,0.98);g.rectangle("fill",x,34,w,32,6,6)
    g.setColor(0.72,0.8,0.46,0.9);g.rectangle("line",x,34,w,32,6,6)
    g.setColor(0.95,0.85,0.5,1)
    g.printf(string.format("资源 %d   舰队管理  %s",math.floor(e.credits),e.open and "-" or "+"),x+8,44,w-16,"center")
    if e.open then
        g.setColor(0.045,0.075,0.095,0.94); g.rectangle("fill",x,y,w,h,4,4)
        g.setColor(0.45,0.72,0.75,0.65); g.rectangle("line",x,y,w,h,4,4)
        g.setColor(0.92,0.96,0.96,1); g.setFont(Fonts.get(15)); g.print("舰队后勤",x+12,y+10); g.print("×",x+w-24,y+8)
        g.setFont(Fonts.get(11));g.setColor(0.7,0.9,0.85,1)
        g.print(require("systems.preferences").get("volume",0.65)>0 and "音效 开" or "音效 关",x+w-88,y+12)
        g.setFont(Fonts.get(12))
        for i,t in ipairs({"fleet","build","research"}) do
            local bx=x+(i-1)*w/3
            if (e.tab or "fleet")==t then g.setColor(0.22,0.46,0.46,1) else g.setColor(0.08,0.13,0.16,1) end
            g.rectangle("fill",bx,y+36,w/3,32)
            g.setColor(0.9,0.95,0.95,1); g.printf(({"招募","建设","科技"})[i],bx,y+45,w/3,"center")
        end
        local items=entries(game)
        for i,a in ipairs(items) do
            local by=y+76+(i-1)*46
            g.setColor(0.3,0.43,0.46,0.5); g.line(x+10,by+42,x+w-10,by+42)
            g.setColor(e.credits>=a.cost and 0.9 or 0.5,0.85,0.75,1)
            local level=a.tech and (" "..e[a.id].."/"..a.max) or ""
            g.print(a.label..level,x+12,by+3)
            g.setColor(0.55,0.7,0.75,1); g.print(a.cost.." 资源 / "..a.time.." 秒",x+12,by+23)
            g.setColor(0.7,0.9,0.85,1); g.print("+",x+w-25,by+10)
        end
        local qy=y+80+#items*46
        if e.tab=="build" then
            local remaining=0
            for _,node in ipairs(game.minerals or {}) do remaining=remaining+node.remaining end
            g.setColor(0.5,0.9,0.72,1);g.print("矿藏余量  "..math.floor(remaining),x+12,y+h-22)
        end
        for i,job in ipairs(e.queue) do
            local by=qy+(i-1)*28
            if by+25<y+h then
                g.setColor(0.18,0.35,0.37,1); g.rectangle("fill",x+10,by,w-20,24)
                g.setColor(0.32,0.63,0.56,1); g.rectangle("fill",x+10,by,(w-20)*(1-job.remaining/job.action.time),24)
                g.setColor(0.95,0.96,0.9,1); g.print(job.action.label.." "..math.ceil(job.remaining).."秒",x+14,by+5);g.print("×",x+w-25,by+4)
            end
        end
    end
    g.pop()
end
return Panel

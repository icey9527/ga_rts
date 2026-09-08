local Fonts=require("core.fonts")
local Pilots=require("ui.pilots")
local utf8=require("utf8")
local Comms={}
function Comms.update(game,dt)
    for i=#(game.reports or {}),1,-1 do
        local r=game.reports[i]
        r.age=r.age+dt; r.life=r.life-dt
        if r.life<=0 then table.remove(game.reports,i) end
    end
end
local function bounds(game)
    local w=math.min(342,love.graphics.getWidth()-290)
    local x=love.graphics.getWidth()-w-18
    if game.economy and game.economy.open then w=math.min(w,love.graphics.getWidth()-540); x=love.graphics.getWidth()-w-282 end
    return x,w
end
function Comms.contains(game,mx,my)
    local x,w=bounds(game)
    return #(game.reports or {})>0 and mx>=x and mx<=x+w and my>=48 and my<=48+#game.reports*100
end
function Comms.bubble(unit,text,kind,x,y,w,age,life,size)
    local g=love.graphics
    size=size or 64
    local font=Fonts.get(14)
    local _,lines=font:getWrap(text,w-size-48)
    local bh=math.max(64,#lines*font:getHeight()+24)
    local enter=math.min(1,age/0.42)
    local flip=math.max(0.04,math.abs(math.cos((1-enter)*math.pi/2)))
    local alpha=math.min(1,age*8,life*3)
    g.push("all")
    g.translate(x+w/2,y+46)
    g.scale(flip,0.93+enter*0.07)
    g.translate(-w/2,-46)
    g.setColor(1,1,1,alpha)
    Pilots.draw(unit,2,43-size/2,size,kind)
    local bx=size+14
    local left=Pilots.image("assets/comms/slg_tbox00.agi.png")
    local mid=Pilots.image("assets/comms/slg_tbox01.agi.png")
    local right=Pilots.image("assets/comms/slg_tbox02.agi.png")
    if left and mid and right then
        g.setColor(1,1,1,alpha)
        g.draw(left,bx,24,0,22/left:getWidth(),bh/left:getHeight())
        g.draw(mid,bx+22,24,0,(w-bx-36)/mid:getWidth(),bh/mid:getHeight())
        g.draw(right,w-14,24,0,14/right:getWidth(),bh/right:getHeight())
    end
    g.setFont(Fonts.get(12))
    g.setColor(0.94,0.98,1,alpha)
    g.setFont(Fonts.get(14))
    g.setColor(0.09,0.15,0.2,alpha)
    local count=math.floor(math.max(0,age-0.25)*32)
    local stop=utf8.offset(text,count+1)
    local visible=stop and text:sub(1,stop-1) or text
    g.printf(visible,bx+22,35,w-bx-34)
    if kind=="hit" or kind=="lost" then
        g.setScissor(x+2,y+43-size/2,size,size)
        for i=1,14 do
            local py=(i*17+math.floor(age*24)*7)%size
            g.setColor(0.8,0.94,1,alpha*0.3)
            g.rectangle("fill",2,43-size/2+py,size,1)
        end
    end
    g.pop()
end
function Comms.draw(game)
    local x,w=bounds(game)
    for i,r in ipairs(game.reports or {}) do
        Comms.bubble(r.unit,r.text,r.kind,x,48+(i-1)*100,w,r.age,r.life)
    end
end
return Comms

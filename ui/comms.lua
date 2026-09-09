local Fonts=require("core.fonts")
local Pilots=require("ui.pilots")
local utf8=require("utf8")
local Comms={}
-- 报告数量（跳过过期槽）
function Comms.count(game)
    local n = 0
    for i = 1, 3 do
        local r = game.reports and game.reports[i]
        if r and not r.expired then n = n + 1 end
    end
    return n
end

-- 报告落位：同单位回原槽 > 过期槽 > 最旧（槽位固定，不重排）
function Comms.place(game, report)
    game.reports = game.reports or {}
    local slot
    for i, r in ipairs(game.reports) do
        if r.unit == report.unit then slot = i break end
        if r.expired and not slot then slot = i end
    end
    if not slot then
        if #game.reports < 3 then slot = #game.reports + 1
        else
            slot = 1
            for i, r in ipairs(game.reports) do
                if r.age < game.reports[slot].age then slot = i end
            end
        end
    end
    game.reports[slot] = report
end

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
    if #(game.reports or {})==0 then return false end
    local h=0
    for _,r in ipairs(game.reports or {}) do h=h+Comms.measure(r.text,w)+8 end
    return mx>=x and mx<=x+w and my>=48 and my<=48+h
end
-- 气泡实际高度：按换行行数计算，绘制堆叠与点击判定共用同一套算法。
function Comms.measure(text,w,size)
    local font=Fonts.get(14)
    local _,lines=font:getWrap(tostring(text or ""),w-(size or 64)-48)
    return math.max(64,#lines*font:getHeight()+24)
end
function Comms.bubble(unit,text,kind,x,y,w,age,life,size,enemy)
    local g=love.graphics
    size=size or 64
    local font=Fonts.get(14)
    text=tostring(text or "")
    local bh=Comms.measure(text,w,size)
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
        -- 敌方通讯仅轻微暖色区分，保留左侧红色阵营线；不做整框重染（旧式纯红框已废弃）。
        g.setColor(1,enemy and 0.9 or 1,enemy and 0.87 or 1,alpha)
        g.draw(left,bx,24,0,22/left:getWidth(),bh/left:getHeight())
        g.draw(mid,bx+22,24,0,(w-bx-36)/mid:getWidth(),bh/mid:getHeight())
        g.draw(right,w-14,24,0,14/right:getWidth(),bh/right:getHeight())
    end
    g.setFont(Fonts.get(12))
    g.setColor(0.94,0.98,1,alpha)
    g.setFont(Fonts.get(14))
    g.setColor(0.09,0.15,0.2,alpha)
    local count=math.floor(math.max(0,age-0.25)*32)
    local chars=utf8.len(text) or #text
    local visible=text
    if count<chars then
        local stop=utf8.offset(text,count+1)
        visible=stop and text:sub(1,stop-1) or ""
    end
    g.printf(visible,bx+22,35,w-bx-34,"left")
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
    local g=love.graphics
    local x,w=bounds(game)
    -- 按气泡实际高度堆叠（+8px 间距），长文本不再压进下一条。
    local y=48
    for _,r in ipairs(game.reports or {}) do
        Comms.bubble(r.unit,r.text,r.kind,x,y,w,r.age,r.life)
        y=y+Comms.measure(r.text,w)+8
    end
    -- 敌方左右手已改到画面底部镜像位绘制（见 advisor.draw）；此处仅保留敌方 R&D。
    local e=(game.logistics or {}).enemy
    if e and e.life>0 and e.text~="" then
        Comms.bubble(e.unit,e.text,e.kind,x,y,w,e.age,e.life,nil,true)
    end
end
return Comms

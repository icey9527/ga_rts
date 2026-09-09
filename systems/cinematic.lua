local Cinema={}
local ECONOMY_SHIFT=282
function Cinema.start(game,unit)
    game.cutins=game.cutins or {}
    for _,c in ipairs(game.cutins) do if c.unit==unit then return end end
    game.cutins[#game.cutins+1]={unit=unit,time=0,duration=2.3,enemy=unit.game and unit.team~=unit.game.player_team}
    if #game.cutins>3 then table.remove(game.cutins,1) end
    game.cinematic=game.cutins[1]
    game.skill_slow={time=math.max(1.8,(unit.skill_data and unit.skill_data.windup) or 1.1),scale=0.3,unit=unit}
end
function Cinema.reinforcement(game,unit)
    if not unit then return end
    game.cutins=game.cutins or {}
    game.cutins[#game.cutins+1]={unit=unit,time=0,duration=2.3,enemy=unit.team~=game.player_team,reinforcement=true}
    if #game.cutins>3 then table.remove(game.cutins,1) end
    game.cinematic=game.cutins[1]
end
function Cinema.update(game,dt)
    local list=game.cutins or {}
    for i=#list,1,-1 do
        list[i].time=list[i].time+dt
        if list[i].time>=list[i].duration or not list[i].unit.alive then table.remove(list,i) end
    end
    game.cinematic=list[1]
end
function Cinema.apply() end
function Cinema.draw(game)
    local g=love.graphics
    local w=g.getDimensions()
    -- 特写从通讯区下方开始，避免与常驻对话框重叠
    -- 特写区域固定在通讯区下方，普通对话增减时不跳动。
    local y=306
    for _,c in ipairs(game.cutins or {}) do
        -- 敌方必杀：更小的红色特写，与青色我方演出区分。
        local width=c.enemy and 200 or 240
        local height=c.enemy and 84 or 96
        local portrait=c.enemy and 128 or 160
        local a=math.max(0,math.min(1,c.time/0.24,(c.duration-c.time)/0.35))
        local x=w-width-18-((game.economy and game.economy.open) and ECONOMY_SHIFT or 0)
        local img=require("ui.pilots").standing(c.unit)
        g.push("all")
        local inset=c.enemy and 14 or 16
        local function cutin_shape()
            g.polygon("fill",x+inset,y,x+width,y,x+width-inset,y+height,x,y+height)
        end
        g.stencil(cutin_shape,"replace",1)
        g.setStencilTest("equal",1)
        if c.enemy then
            g.setColor(0.12,0.03,0.05,0.78*a)
            g.polygon("fill",x+14,y,x+width,y,x+width-14,y+height,x,y+height)
            g.setColor(0.92,0.28,0.24,a);g.setLineWidth(2)
            g.line(x+14,y+1,x+width,y+1);g.line(x,y+height-2,x+width-14,y+height-2)
        else
            g.setColor(0.03,0.1,0.13,0.78*a)
            g.polygon("fill",x+16,y,x+width,y,x+width-16,y+height,x,y+height)
            g.setColor(0.35,0.9,1,a);g.setLineWidth(2)
            g.line(x+16,y+1,x+width,y+1);g.line(x,y+height-2,x+width-16,y+height-2)
        end
        -- 背景拖影覆盖整个梯形，立绘也处在这层动态纹理之上。
        g.setBlendMode("add")
        for j=1,8 do
            local yy=y+(j*17+c.time*(c.enemy and 130 or 150))%height
            g.setColor(c.enemy and 1 or 0.5,c.enemy and 0.32 or 0.85,c.enemy and 0.28 or 1,a*0.18)
            g.line(x-20,yy,x+width+20,yy+(c.enemy and 24 or -28))
        end
        g.setBlendMode("alpha")
        if img then
            -- 自动适配：限宽 104、限高 portrait，取小缩放；顶部对齐保证露脸。
            g.setScissor(x,y,104,height)
            local scale=math.min(portrait/img:getHeight(),104/img:getWidth())
            g.setColor(1,1,1,a)
            g.draw(img,x+52-img:getWidth()*scale/2-(1-a)*60,y,0,scale,scale)
            g.setScissor()
        else require("ui.pilots").draw(c.unit,x+18,y+16,56,"skill") end
        -- 横线只在立绘背后绘制，避免覆盖人物透明立绘的可见区域。
        g.setFont(require("core.fonts").get(15))
        if c.enemy then g.setColor(1,0.85,0.82,a) else g.setColor(1,1,1,a) end
        g.printf(c.reinforcement and "增援" or require("ui.pilots").profile(c.unit).name,x+108,y+24,width-115)
        g.setFont(require("core.fonts").get(12))
        if c.enemy then g.setColor(1,0.55,0.5,a) else g.setColor(0.65,0.94,1,a) end
        if c.reinforcement then
            g.printf(c.enemy and "敌方舰队抵达" or "我方舰队抵达",x+108,y+50,width-115)
        else
            g.printf(require("systems.skill").label(c.unit),x+108,y+50,width-115)
        end
        g.setStencilTest()
        g.pop()
        y=y+(c.enemy and 92 or 104)
    end
end
return Cinema

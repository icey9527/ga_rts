local Pilots=require("ui.pilots")
local Markers={}
function Markers.position(u,camera)
    local x,y=camera:world_to_screen(u.x,u.y-(u.z or 0)*0.22)
    return x,y-math.max(18,u.radius*camera.zoom*1.2)-28
end
function Markers.pick(game,camera,mx,my)
    for i=#game.units,1,-1 do
        local u=game.units[i]
        local x,y=Markers.position(u,camera)
        if u.alive and (mx-x)^2+(my-y)^2<=18^2 then return u end
    end
end
function Markers.draw(game,camera)
    local g=love.graphics
    g.push("all")
    for _,u in ipairs(game.units) do
        local x,y=camera:world_to_screen(u.x,u.y-(u.z or 0)*0.22)
        if x>=0 and x<=g.getWidth() and y>=32 and y<=g.getHeight()-30 then
            local friendly=u.team==game.player_team
            if camera.zoom<0.45 then
                g.setColor(friendly and 0.3 or 1,friendly and 0.9 or 0.35,0.55,1)
                g.push()
                g.translate(x,y); g.rotate(u.angle)
                g.polygon("fill",7,0,-5,-4,-2,0,-5,4)
                g.pop()
            end
            if u.alive then
                local _,py=Markers.position(u,camera)
                g.setColor(friendly and 0.3 or 1,0.7,0.95,1)
                g.polygon("fill",x-6,py+16,x+6,py+16,x,py+28)
                Pilots.draw(u,x-16,py-16,32,nil,"circle")
            end
        end
    end
    g.pop()
end
return Markers

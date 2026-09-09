local M={}
function M.start(game)
    local base=game:get_mothership(game.player_team)
    game.minerals={}
    if not base then return end
    for i,delta in ipairs({{400,350},{1050,-420},{1750,650}}) do
        local x,y=game:find_clear_position(base.x+delta[1],base.y+delta[2],65)
        game.minerals[i]={x=x,y=y,remaining=1800,capacity=1800}
    end
end
function M.available(game)
    for _,node in ipairs(game.minerals or {}) do
        if node.remaining>0 and (not node.station or not node.station.alive) then return node end
    end
end
function M.update(game,dt)
    local income=0
    for _,u in ipairs(game.units) do
        if u.alive and u.team==game.player_team and u.unit_type=="collector" then
            local node=u.mineral_node
            if not node then
                node=M.available(game)
                if node then node.station=u;u.mineral_node=node end
            end
            if node and u:dist_to_pos(node.x,node.y)<140 then
                -- 采集站是达到约 90 秒生产节奏的增量来源，保持中等速率避免资源爆发。
                local amount=math.min(node.remaining,8*dt)
                node.remaining=node.remaining-amount;income=income+amount
            end
        end
    end
    return income
end
function M.draw(game)
    local g=love.graphics
    g.push("all")
    for _,node in ipairs(game.minerals or {}) do
        local alpha=node.remaining>0 and 0.7 or 0.18
        for i=1,5 do
            local angle=i*2.4
            local x,y=node.x+math.cos(angle)*36,node.y+math.sin(angle)*24
            g.setColor(0.36,0.9,0.75,alpha)
            g.polygon("fill",x,y-13,x+8,y,x,y+17,x-8,y)
            g.setColor(0.75,1,0.9,alpha);g.line(x,y-13,x,y+17)
        end
        g.setColor(0.45,0.95,0.78,alpha*0.7);g.ellipse("line",node.x,node.y,65,40)
    end
    g.pop()
end
return M

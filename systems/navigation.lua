local Nav = {}
local function obstacles(game,unit)
    local result={}
    for _,t in ipairs(game.terrain_objects) do
        local height=t.height or t.z_height or (t.type=="asteroid" and 72 or 36)
        if unit.unit_type=="mothership" then height=height*0.55 end
        if (unit.z or 0)<=height then result[#result+1]={x=t.x,y=t.y,r=(t.radius or 50)+unit.radius+4} end
    end
    return result
end
local function clear(a,b,blocks)
    local dx,dy=b.x-a.x,b.y-a.y
    local length=dx*dx+dy*dy
    for _,o in ipairs(blocks) do
        local t=length>0 and math.max(0,math.min(1,((o.x-a.x)*dx+(o.y-a.y)*dy)/length)) or 0
        if (a.x+t*dx-o.x)^2+(a.y+t*dy-o.y)^2<o.r^2 then return false end
    end
    return true
end
function Nav.route(game,unit,tx,ty)
    local blocks=obstacles(game,unit)
    local start={x=unit.x,y=unit.y}
    local goal={x=tx,y=ty}
    for _,o in ipairs(blocks) do
        local dx,dy=goal.x-o.x,goal.y-o.y
        local d=math.sqrt(dx*dx+dy*dy)
        if d<o.r+2 then
            if d<0.01 then dx,dy,d=1,0,1 end
            goal={x=o.x+dx/d*(o.r+3),y=o.y+dy/d*(o.r+3)}
        end
    end
    if clear(start,goal,blocks) then return {goal} end
    -- Visibility graph around inflated obstacles; routes persist across frames.
    local nodes={start,goal}
    for _,o in ipairs(blocks) do
        for i=0,11 do
            local a=i*math.pi/6
            nodes[#nodes+1]={x=o.x+math.cos(a)*(o.r+8)/math.cos(math.pi/12),y=o.y+math.sin(a)*(o.r+8)/math.cos(math.pi/12)}
        end
    end
    local distance,previous,done={[1]=0},{},{}
    for _=1,#nodes do
        local index,best=nil,math.huge
        for i=1,#nodes do if not done[i] and (distance[i] or math.huge)<best then index,best=i,distance[i] end end
        if not index then break end
        if index==2 then
            local path={}
            while index~=1 do table.insert(path,1,nodes[index]); index=previous[index] end
            return path
        end
        done[index]=true
        for i,node in ipairs(nodes) do
            if not done[i] and clear(nodes[index],node,blocks) then
                local d=best+math.sqrt((node.x-nodes[index].x)^2+(node.y-nodes[index].y)^2)
                if d<(distance[i] or math.huge) then distance[i],previous[i]=d,index end
            end
        end
    end
    return {}
end
return Nav

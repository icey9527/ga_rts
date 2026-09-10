local Movement={}
local atan2=math.atan2 or function(y,x) return math.atan(y,x) end

function Movement.move_towards(unit,tx,ty,step,game)
    if step<=0 then return false end
    if game:is_position_blocked(unit.x,unit.y,unit.radius,unit) then
        unit.z=math.min(300,(unit.z or 0)+step*0.8);unit.route=nil;return false
    end
    local nav=require("systems.navigation")
    if not unit.route or math.abs(tx-(unit.route_x or 0))+math.abs(ty-(unit.route_y or 0))>12 or game.level_time>=(unit.route_time or 0) then
        unit.route=nav.route(game,unit,tx,ty);unit.route_x,unit.route_y,unit.route_time=tx,ty,game.level_time+1.5
    end
    local point=unit.route and unit.route[1]
    if not point then
        -- 受阻可能持续多帧，同一单位 2 秒内只播报一次。
        if game.level_time-(unit.route_warn_time or -math.huge)>=2 then
            unit.route_warn_time=game.level_time
            game:report_event(unit,"failed","航线受阻，请重新指定航点。")
        end
        return false
    end
    local dx,dy=point.x-unit.x,point.y-unit.y
    local dist=math.sqrt(dx*dx+dy*dy)
    local max_speed=unit.speed* (unit.state=="attacking" and (unit._approach_speed_multiplier or 1) or 1)
    local travel=math.min(step,dist)
    if dist>0 then
        -- 统一惯性：速度逐步接近期望速度，避免所有机体到点即停。
        local dt=step/math.max(max_speed,1)
        local cruise=unit.state=="attacking"
        -- Propulsion follows heading; weapon aiming cannot turn a translating hull sideways.
        local desired=atan2(dy,dx)
        local diff=(desired-unit.angle+math.pi)%(2*math.pi)-math.pi
        local turn=(unit.turn_rate or 3)*dt
        unit.angle=unit.angle+math.max(-turn,math.min(turn,diff))
        local remaining=(desired-unit.angle+math.pi)%(2*math.pi)-math.pi
        local desired_speed=math.min(max_speed,cruise and max_speed or math.sqrt(2*(unit.deceleration or 1100)*dist))
        desired_speed=desired_speed*math.max(0.25,math.cos(remaining))
        local velocity=math.sqrt((unit.vx or 0)^2+(unit.vy or 0)^2)
        local rate=desired_speed>velocity and (unit.acceleration or 900) or (unit.deceleration or 1100)
        velocity=math.max(0,velocity+math.max(-rate*dt,math.min(rate*dt,desired_speed-velocity)))
        local vx,vy=math.cos(unit.angle)*velocity,math.sin(unit.angle)*velocity
        unit.vx,unit.vy=vx,vy
        local nx,ny=unit.x+vx*dt,unit.y+vy*dt
        local moved=math.sqrt((nx-unit.x)^2+(ny-unit.y)^2)
        if moved>travel and moved>0 then nx,ny=unit.x+(nx-unit.x)/moved*travel,unit.y+(ny-unit.y)/moved*travel end
        if game:is_position_blocked(nx,ny,unit.radius,unit) then unit.route=nil;return false end
        unit.x,unit.y=nx,ny
        unit.bank=math.max(-0.65,math.min(0.65,diff))
    end
    if (point.x-unit.x)^2+(point.y-unit.y)^2<=4 then
        table.remove(unit.route,1)
        if #unit.route==0 then
            unit.route=nil
            if unit.state~="attacking" then unit.vx,unit.vy=0,0 end
            return true
        end
    end
    return false
end

return Movement

local Shared={}
function Shared.update(u,dt,game,mode)
    if mode=="kite" and u.state=="attacking" and u.attack_target and u.attack_target.alive then
        local target=u.attack_target
        local dx,dy=u.x-target.x,u.y-target.y
        local d=math.sqrt(dx*dx+dy*dy)
        if d<u.attack_range*0.55 and d>1 then
            u:_move_towards(u.x+dx/d*80,u.y+dy/d*80,u.speed*dt,game)
        end
    end
end
return Shared

local S={}
local function projection(u) return u.x,u.y-(u.z or 0)*0.22 end
local function segment_distance(x,y,ax,ay,bx,by)
    local dx,dy=bx-ax,by-ay
    local t=math.max(0,math.min(1,((x-ax)*dx+(y-ay)*dy)/math.max(1,dx*dx+dy*dy)))
    return math.sqrt((x-ax-t*dx)^2+(y-ay-t*dy)^2)
end
S.distance=segment_distance
S.kinds={charge_beam=true,sweep_bombardment=true,dash_strike=true}
function S.can_execute(u)
    local t=u.skill_target or u.attack_target
    return t and t.alive and t.team~=u.team and u:distance_to(t)<=(u.skill_data.range or 1200)
end
function S.prepare(u)
    local t=u.skill_target or u.attack_target
    if t then u.skill_aim={x=t.x,y=t.y,z=t.z or 0} end
end
function S.execute(u,game)
    local sd=u.skill_data
    local aim=u.skill_aim
    if not aim then local t=u.skill_target or u.attack_target;if not t then return end; aim={x=t.x,y=t.y,z=t.z or 0} end
    local x,y=projection(u)
    local tx,ty=aim.x,aim.y-aim.z*0.22
    local Effect=require("entities.effect")
    if sd.type=="charge_beam" then
        local dx,dy=aim.x-u.x,aim.y-u.y
        local d=math.max(1,math.sqrt(dx*dx+dy*dy));local range=sd.range or 1600
        local bx,by=u.x+dx/d*range,u.y+dy/d*range
        for _,enemy in ipairs(game:get_enemy_units(u.team)) do
            if segment_distance(enemy.x,enemy.y,u.x,u.y,bx,by)<=(sd.width or 35)+enemy.radius then enemy:take_damage(sd.damage or 650) end
        end
        game:add_effect(Effect.charged_beam(x,y,bx,by-aim.z*0.22))
    elseif sd.type=="sweep_bombardment" then
        game.skill_jobs=game.skill_jobs or {}
        game.skill_jobs[#game.skill_jobs+1]={unit=u,time=0,index=0,count=sd.count or 12,x=aim.x,y=aim.y,z=aim.z,radius=sd.radius or 240,damage=sd.damage or 65}
    elseif sd.type=="dash_strike" then
        local dx,dy=aim.x-u.x,aim.y-u.y
        local d=math.max(1,math.sqrt(dx*dx+dy*dy));local length=math.min(d+80,sd.range or 650)
        u.dash={ax=u.x,ay=u.y,x=u.x+dx/d*length,y=u.y+dy/d*length,time=0,duration=0.42,damage=sd.damage or 380,hits={}}
        game:add_effect(Effect.charged_beam(x,y,u.dash.x,u.dash.y-(u.z or 0)*0.22,{1,0.75,0.2},0.45))
    end
    u.skill_target=nil;u.skill_aim=nil
end
function S.update_dash(u,dt,game)
    local dash=u.dash
    if not dash then return false end
    local ox,oy=u.x,u.y
    dash.time=dash.time+dt
    local p=math.min(1,dash.time/dash.duration)
    local nx,ny=dash.ax+(dash.x-dash.ax)*p,dash.ay+(dash.y-dash.ay)*p
    local distance=math.sqrt((nx-ox)^2+(ny-oy)^2)
    local steps=math.max(1,math.ceil(distance/math.max(5,u.radius)))
    for i=1,steps do
        local x,y=ox+(nx-ox)*i/steps,oy+(ny-oy)*i/steps
        if game:is_position_blocked(x,y,u.radius,u) then u.dash=nil;break end
        u.x,u.y=x,y
    end
    for _,enemy in ipairs(game:get_enemy_units(u.team)) do
        if not dash.hits[enemy] and segment_distance(enemy.x,enemy.y,ox,oy,u.x,u.y)<u.radius+enemy.radius+18 then
            dash.hits[enemy]=true;enemy:take_damage(dash.damage)
            game:add_effect(require("entities.effect").explosion(enemy.x,enemy.y-(enemy.z or 0)*0.22,55))
        end
    end
    if p>=1 then u.dash=nil;u.route=nil end
    return true
end
function S.update(game,dt)
    for i=#(game.skill_jobs or {}),1,-1 do
        local job=game.skill_jobs[i];job.time=job.time+dt
        if not job.unit.alive then table.remove(game.skill_jobs,i);goto continue end
        while job.index<job.count and job.time>=job.index*0.075 do
            local n=job.index;job.index=n+1
            local x=job.x+(n%4-1.5)*job.radius*0.6
            local y=job.y+(math.floor(n/4)-1)*job.radius*0.6
            local p=require("entities.projectile").artillery(job.unit.x,job.unit.y,x,y,job.damage,110,900,job.unit.z,job.unit.team)
            p.life=math.max(3,math.sqrt((x-job.unit.x)^2+(y-job.unit.y)^2)/900+1)
            game:add_projectile(p)
        end
        if job.index>=job.count then table.remove(game.skill_jobs,i) end
        ::continue::
    end
end
return S

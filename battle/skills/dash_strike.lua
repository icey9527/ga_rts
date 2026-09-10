-- 滑步突袭：短距直线突进，路径采样避开障碍，每个敌人至多命中一次。
-- 突进期间普通航行暂停（update_dash 返回 true 时状态机让位）。
local Dash = {}
local Registry = require("battle.skills.registry")
local Pacing = require("config.pacing")

Dash.dash_strike = {
    label = "滑步突袭",
    target_mode = "enemy",
    can_execute = Registry.aimed_can_execute,
    prepare = Registry.aimed_prepare,
    execute = function(u, game)
        local sd = u.skill_data
        local aim = u.skill_aim
        if not aim then
            local t = u.skill_target or u.attack_target
            if not t then return end
            aim = {x=t.x, y=t.y, z=t.z or 0}
        end
        local dx, dy = aim.x-u.x, aim.y-u.y
        local d = math.max(1, math.sqrt(dx*dx+dy*dy))
        local length = math.min(d+80, sd.range or 650)
        u.dash = {
            ax=u.x, ay=u.y,
            x=u.x+dx/d*length, y=u.y+dy/d*length,
            time=0, duration=0.42,
            damage=sd.damage or math.floor(380*Pacing.damage_multiplier),
            hits={},
        }
        game:add_effect(require("entities.effect").charged_beam(
            u.x, u.y-(u.z or 0)*0.22, u.dash.x, u.dash.y-(u.z or 0)*0.22, {1,0.75,0.2}, 0.45))
        u.skill_target=nil; u.skill_aim=nil
    end,
}

function Dash.update_dash(u,dt,game)
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
        if not dash.hits[enemy] and Registry.distance(enemy.x,enemy.y,ox,oy,u.x,u.y)<u.radius+enemy.radius+18 then
            dash.hits[enemy]=true;enemy:take_damage(dash.damage,u)
            game:add_effect(require("entities.effect").explosion(enemy.x,enemy.y-(enemy.z or 0)*0.22,55))
        end
    end
    if p>=1 then u.dash=nil;u.route=nil end
    return true
end

return Dash

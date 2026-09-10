-- 扇面轰炸：在锁定区域上空连续投放范围弹，命中按落点实际位置结算。
-- 任务队列由 registry.tick 逐帧推进；技能弹药 no_sp，不参与伤害回充。
local Sweep = {}
local Registry = require("battle.skills.registry")
local Pacing = require("config.pacing")

Sweep.sweep_bombardment = {
    label = "扇面轰炸",
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
        game.skill_jobs = game.skill_jobs or {}
        game.skill_jobs[#game.skill_jobs+1] = {
            unit=u, time=0, index=0, count=sd.count or 12,
            x=aim.x, y=aim.y, z=aim.z,
            radius=sd.radius or 240,
            damage=sd.damage or math.floor(65*Pacing.damage_multiplier),
        }
        u.skill_target=nil; u.skill_aim=nil
    end,
}

function Sweep.update(game,dt)
    for i=#(game.skill_jobs or {}),1,-1 do
        local job=game.skill_jobs[i];job.time=job.time+dt
        if not job.unit.alive then table.remove(game.skill_jobs,i);goto continue end
        while job.index<job.count and job.time>=job.index*0.075 do
            local n=job.index;job.index=n+1
            local x=job.x+(n%4-1.5)*job.radius*0.6
            local y=job.y+(math.floor(n/4)-1)*job.radius*0.6
            local p=require("entities.projectile").artillery(job.unit.x,job.unit.y,x,y,job.damage,110,900,job.unit.z,job.unit.team,"artillery",job.unit)
            p.life=math.max(3,math.sqrt((x-job.unit.x)^2+(y-job.unit.y)^2)/900+1)
            p.no_sp=true
            game:add_projectile(p)
        end
        if job.index>=job.count then table.remove(game.skill_jobs,i) end
        ::continue::
    end
end

return Sweep

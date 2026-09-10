local Combat={}
local Targeting=require("battle.unit.targeting")
local WeaponSystem=require("battle.unit.weapons")
local atan2=math.atan2 or function(y,x) return math.atan(y,x) end

function Combat.aim(unit,target,dt)
    local desired=atan2(target.y-unit.y,target.x-unit.x)
    local diff=(desired-(unit.angle or 0)+math.pi)%(math.pi*2)-math.pi
    local turn=math.min((unit.turn_rate or 3)*dt,math.abs(diff))
    unit.angle=(unit.angle or 0)+(diff<0 and -turn or turn)
end

function Combat.can_attack(unit,game)
    if not unit.alive or unit.state=="disabled" or unit.energy<=0 then return false end
    return Targeting.is_valid_enemy(unit,unit.attack_target)
end

function Combat.energy_cost(unit)
    return unit.unit_type=="mothership" and 0 or require("config.gameplay").energy_attack_cost
end

-- A cycle budget is divided across its projectiles. Cancelled shots cost nothing.
-- SP 不再按发结算：实际造成伤害时由弹道命中回充（entities/projectile.lua）。
function Combat.emit(unit,game,volley,index,spawn)
    if volley.cancelled then return false end
    local weapon=volley.runtime
    if not unit.alive or unit.state=="disabled" or unit.energy+1e-9<volley.energy
       or not WeaponSystem.can_fire(weapon)
       or not Targeting.is_valid_enemy(unit,volley.target) then
        volley.cancelled=true;return false
    end
    if not spawn(volley.target,index,volley.shot.count,volley.shot) then
        volley.cancelled=true;return false
    end
    unit.energy=math.max(0,unit.energy-volley.energy)
    WeaponSystem.on_fire(weapon,1)
    return true
end

function Combat.cancel_bursts(unit)
    for _,entry in ipairs(unit.burst_queue) do entry.volley.runtime.burst_pending=false end
    unit.burst_queue={}
end

function Combat.update_bursts(unit,dt,game)
    for _,entry in ipairs(unit.burst_queue) do entry.delay=entry.delay-dt end
    table.sort(unit.burst_queue,function(a,b)
        if a.delay==b.delay then return a.serial<b.serial end
        return a.delay<b.delay
    end)
    local i=1
    while i<=#unit.burst_queue do
        local entry=unit.burst_queue[i]
        local volley=entry.volley
        if entry.delay<=0 or volley.cancelled then
            if not volley.cancelled then
                Combat.emit(unit,game,volley,entry.index,function(target,index,count,shot)
                    return unit:_spawn_projectile(game,target,index,count,shot)
                end)
            end
            volley.remaining=volley.remaining-1
            if volley.remaining==0 then volley.runtime.burst_pending=false end
            table.remove(unit.burst_queue,i)
        else i=i+1 end
    end
end

function Combat.fire(unit,game,spawn)
    if not Combat.can_attack(unit,game) then return false end
    local target=unit.attack_target
    local fired=false
    -- 攻击增益显式乘入快照；基础数值（含 pacing 倍率）在配置加载时已确定。
    local attack_buff=(unit.buffs and unit.buffs.attack) and unit.buffs.attack.multiplier or 1
    for _,weapon in ipairs(unit.weapons or {}) do
        if not weapon.burst_pending and unit:distance_to(target)<=(weapon.range or unit.attack_range)
           and unit:distance_to(target)>=(weapon.min_range or 0)
           and (weapon.cooldown_timer or 0)<=0 and WeaponSystem.can_fire(weapon)
           and Targeting.in_weapon_arc(unit,weapon,target) then
            local count=math.max(1,math.floor(weapon.count or weapon.projectile_count or unit.projectile_count))
            local bursts=math.max(1,math.floor(weapon.burst_count or unit.burst_count or 1))
            local shot={}
            for k,v in pairs(weapon) do shot[k]=v end
            shot.damage=math.max(1,(weapon.damage or unit.attack_damage)*attack_buff)
            shot.count=count
            shot.type=weapon.type or unit.attack_type
            shot.visual=weapon.visual or weapon.id or shot.type
            local volley={runtime=weapon,shot=shot,target=target,remaining=0,
                energy=math.max(0,weapon.energy_cost or Combat.energy_cost(unit))/(count*bursts)}
            local emitted=0
            for index=0,count-1 do
                if Combat.emit(unit,game,volley,index,spawn) then emitted=emitted+1 end
            end
            if emitted>0 then
                fired=true
                weapon.cooldown_timer=weapon.cooldown
                require("systems.audio").play(weapon.sound or
                    ({ranged="main_gun",missile="missile",artillery="artillery",beam="beam"})[shot.type] or "shot")
                if not volley.cancelled then
                    for burst=2,bursts do for index=0,count-1 do
                        unit.shot_serial=(unit.shot_serial or 0)+1
                        unit.burst_queue[#unit.burst_queue+1]={volley=volley,index=index,serial=unit.shot_serial,
                            delay=(burst-1)*(weapon.burst_delay or unit.burst_delay or 0.06)}
                        volley.remaining=volley.remaining+1
                    end end
                end
                weapon.burst_pending=volley.remaining>0
            end
        end
    end
    if fired then
        unit.attack_timer=unit.attack_cooldown
        game:report_event(unit,"attack","目标进入射程，开始攻击。")
    end
    return fired
end

return Combat

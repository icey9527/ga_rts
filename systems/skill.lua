-- Skill system - executes special abilities
local Skill = {}
function Skill.label(unit)
    local kind=(unit.skill_data or {}).type
    return ({charge_beam="贯穿狙击",sweep_bombardment="扇面轰炸",dash_strike="滑步突袭",orbital_bombardment="轨道轰击",shield="屏障展开",fleet_heal="全舰修复",repair_tool="定点抢修",missile_barrage="导弹齐射",buff_speed="机动强化",buff_attack="火力强化",rapid_fire="速射压制"})[kind] or "特殊装备"
end
function Skill.target_mode(unit)
    local kind=(unit.skill_data or {}).type
    if kind=="repair_tool" then return "ally" end
    if require("systems.special_attacks").kinds[kind] or kind=="orbital_bombardment" then return "enemy" end
    return "self"
end

function Skill.can_execute(unit,game)
    local sd=unit.skill_data or {}
    local kind=sd.type
    if require("systems.special_attacks").kinds[kind] then return require("systems.special_attacks").can_execute(unit) end
    if kind=="fleet_heal" then
        for _,u in ipairs(game:get_units_by_team(unit.team)) do if u.hp<u.max_hp then return true end end
        return false
    end
    if kind=="repair_tool" then local t=unit.repair_target; return t and t~=unit and t.alive and t.team==unit.team and t.hp<t.max_hp and unit:distance_to(t)<=(sd.range or 600) end
    if kind=="orbital_bombardment" then local t=unit.skill_target or unit.attack_target;return t and t.alive and t.team~=unit.team and unit:distance_to(t)<=(sd.range or 1500) end
    if kind=="shield" then return unit.shield_time<=0 end
    if kind=="rapid_fire" then return not unit.buffs.attack and unit.attack_target and unit.attack_target.alive and unit:distance_to(unit.attack_target)<=unit.attack_range end
    if kind=="buff_speed" then return not unit.buffs.speed end
    if kind=="buff_attack" then return not unit.buffs.attack end
    local healing=kind=="heal_aoe" or kind=="repair_all"
    local ranges={damage_aoe=120,heal_aoe=180,repair_all=400,missile_barrage=900,disable=150,teleport=1500}
    if not ranges[kind] then return false end
    local range=sd.range or sd.radius or ranges[kind]
    for _,u in ipairs(game.units) do
        if u.alive and unit:distance_to(u)<=range then
            if healing and u.team==unit.team and u.hp<u.max_hp then return true end
            if not healing and u.team~=unit.team then return true end
        end
    end
    return false
end

function Skill.execute(unit, game)
    local sd = unit.skill_data
    if not sd or not sd.type then return end

    local stype = sd.type
    local Effect = require("entities.effect")
    require("systems.skill_visuals").release(game,unit,stype)
    if require("systems.special_attacks").kinds[stype] then require("systems.special_attacks").execute(unit,game);return end

    if stype=="fleet_heal" then
        for _,u in ipairs(game:get_units_by_team(unit.team)) do
            u:heal(u.max_hp*0.35)
            game:add_effect(Effect.heal_pulse(u.x,u.y-(u.z or 0)*0.22,u.radius*4))
        end
        return
    elseif stype=="repair_tool" then
        local t=unit.repair_target
        t:heal(t.max_hp*0.7)
        game:add_effect(Effect.beam(unit.x,unit.y-(unit.z or 0)*0.22,t.x,t.y-(t.z or 0)*0.22))
        game:add_effect(Effect.heal_pulse(t.x,t.y-(t.z or 0)*0.22,140))
        return
    elseif stype=="orbital_bombardment" then
        local t=unit.skill_target or unit.attack_target
        local x,y=t.x,t.y
        for _,enemy in ipairs(game:get_enemy_units(unit.team)) do if (enemy.x-x)^2+(enemy.y-y)^2<=(sd.radius or 300)^2 then enemy:take_damage(sd.damage or 350,unit) end end
        game:add_effect(Effect.explosion(x,y-(t.z or 0)*0.22,sd.radius or 300))
        unit.skill_target=nil
        return
    end

    if stype == "damage_aoe" then
        local dmg = sd.damage or 50
        local radius = sd.radius or 120
        for _, u in ipairs(game.units) do
            if u.team ~= unit.team and u.alive and u.state ~= "dead" then
                if unit:distance_to(u) <= radius then
                    u:take_damage(dmg,unit)
                end
            end
        end
        game:add_effect(Effect.skill_flash(unit.x, unit.y, radius, {1, 0.3, 0.1}))

    elseif stype == "heal_aoe" then
        local amount = sd.heal_amount or 50
        local radius = sd.radius or 180
        for _, u in ipairs(game.units) do
            if u.team == unit.team and u.alive and u.state ~= "dead" then
                if unit:distance_to(u) <= radius then
                    u:heal(amount)
                end
            end
        end
        game:add_effect(Effect.heal_pulse(unit.x, unit.y, radius))

    elseif stype == "buff_speed" then
        local mult = sd.speed_multiplier or 2.0
        local radius = sd.radius or 200
        local dur = sd.duration or 5
        for _, u in ipairs(game.units) do
            if u.team == unit.team and u.alive and u.state ~= "dead" then
                if unit:distance_to(u) <= radius then
                    u:apply_buff("speed", mult, dur)
                end
            end
        end
        game:add_effect(Effect.skill_flash(unit.x, unit.y, radius, {0.2, 0.6, 1}))

    elseif stype == "buff_attack" then
        local mult = sd.attack_multiplier or 2.0
        local radius = sd.radius or 200
        local dur = sd.duration or 5
        for _, u in ipairs(game.units) do
            if u.team == unit.team and u.alive and u.state ~= "dead" then
                if unit:distance_to(u) <= radius then
                    u:apply_buff("attack", mult, dur)
                end
            end
        end
        game:add_effect(Effect.skill_flash(unit.x, unit.y, radius, {1, 0.4, 0.1}))

    elseif stype == "shield" then
        local amount = sd.shield_amount or 100
        local dur = sd.duration or 5
        unit.shield = amount
        unit.shield_time = dur
        game:add_effect(Effect.shield_glow(unit, dur))

    elseif stype == "teleport" then
        -- teleport to nearest enemy
        local enemy = unit:find_nearest_enemy(game)
        if enemy then
            local tx, ty = enemy.x, enemy.y
            local px,py=game:find_clear_position(tx+unit.attack_range*0.5,ty,unit.radius)
            if game:is_position_blocked(px,py,unit.radius,unit) then return end
            unit.x,unit.y=px,py
            unit.route=nil
            game:add_effect(Effect.skill_flash(unit.x, unit.y, 60, {0.5, 0.3, 1}))
        end

    elseif stype == "disable" then
        local dur = sd.duration or 3
        local radius = sd.range or 150
        for _, u in ipairs(game.units) do
            if u.team ~= unit.team and u.alive and u.state ~= "dead" then
                if unit:distance_to(u) <= radius then
                    u.state = "disabled"
                    u:apply_buff("disable", 1, dur)
                end
            end
        end
        game:add_effect(Effect.skill_flash(unit.x, unit.y, radius, {0.8, 0.2, 0.8}))

    elseif stype == "repair_all" then
        local amount = sd.heal_amount or 200
        local radius = sd.radius or 400
        for _, u in ipairs(game.units) do
            if u.team == unit.team and u.alive and u.state ~= "dead" then
                if unit:distance_to(u) <= radius then
                    u:heal(amount)
                end
            end
        end
        game:add_effect(Effect.heal_pulse(unit.x, unit.y, radius))

    elseif stype == "missile_barrage" then
        local Projectile = require("entities.projectile")
        local count = sd.count or 8
        local dmg = sd.damage or unit.attack_damage
        local range = sd.range or 900
        local enemies = {}
        for _, u in ipairs(game.units) do
            if u.team ~= unit.team and u.alive and u.state ~= "dead" and unit:distance_to(u) <= range then
                table.insert(enemies, u)
            end
        end
        for i = 1, count do
            if #enemies == 0 then break end
            local target = enemies[((i - 1) % #enemies) + 1]
            game:add_projectile(Projectile.missile(unit.x, unit.y, target, dmg, sd.projectile_speed or 260, unit.z or 0, "missile", unit))
        end
        game:add_effect(Effect.skill_flash(unit.x, unit.y, math.min(range, 420), {1, 0.55, 0.1}))

    elseif stype == "rapid_fire" then
        unit:apply_buff("attack", sd.attack_multiplier or 1.8, sd.duration or 6)
        unit.attack_timer = 0
        game:add_effect(Effect.skill_flash(unit.x, unit.y, sd.radius or 180, {1, 0.85, 0.2}))
    end
end

return Skill

-- 机型战术通用引擎。两个引擎对应参考实现 dump/gardens-of-kadesh-master/src/Game/Attack.c：
--   fly_sidestep ← attackSideStep（Light/HeavyCorvette 家族）：
--     接近→开火→按 reposition_time 侧移换位→再接近的四相循环。
--   fly_straight ← attackStraightForward（IonCannonFrigate/MissileDestroyer/Carrier 家族）：
--     超出 gun_range 全速突进；gun_range 与 too_close 之间边逼近边开火；
--     进入 too_close 刹车原地射击，机头追踪目标。
-- 移动期间机头朝向由推进模块独占；刹车（静止）阶段允许 Combat.aim 转动机头，
-- 与原通用攻击路径一致。所有距离/倍率参数来自 config/units/<type>.tbl 的 [behavior]。
local Common = {}
local Targeting = require("battle.unit.targeting")
local Combat = require("battle.unit.combat")

-- ===== 侧移掠袭引擎 ====

-- 清除侧移状态；命令切换或目标失效时由各机型的 update 调用。
function Common.clear_sidestep(unit)
    unit.sidestep_pass = nil
    unit._approach_speed_multiplier = nil
end

-- cfg: break_distance(近身脱离距离) reposition_distance reposition_angle
--      reposition_time approach_boost cut_pass_when_ready(主炮就绪提前结束换位)
function Common.fly_sidestep(unit, dt, game, cfg)
    local target = unit.attack_target
    if not Targeting.is_valid_enemy(unit, target) then return false end
    unit.state = "attacking"
    local pass = unit.sidestep_pass
    if pass and (pass.target ~= target or pass.time <= 0 or unit:dist_to_pos(pass.x, pass.y) < 30) then
        pass = nil; unit.sidestep_pass = nil; unit.route = nil
    end
    local distance = unit:distance_to(target)
    local far = distance > unit.attack_range
    local boost = far and (cfg.approach_boost or 1.3) or 1

    -- 主炮就绪时机型可选择提前结束换位，重新进入射击航段。
    if pass and not pass.escape and cfg.cut_pass_when_ready then
        local ready = false
        for _, weapon in ipairs(unit.weapons) do
            if (weapon.cooldown_timer or 0) <= 0.35 and require("battle.unit.weapons").can_fire(weapon) then
                ready = true; break
            end
        end
        if ready then pass = nil; unit.sidestep_pass = nil end
    end

    -- 近身先脱离：背向目标 + 侧向分量的固定航点。
    if not pass and distance < (cfg.break_distance or 120) then
        local dx, dy = unit.x - target.x, unit.y - target.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1 then dx, dy, len = math.cos(unit.angle), math.sin(unit.angle), 1 end
        local reach = cfg.reposition_distance or 150
        local side = cfg.reposition_angle or 0.9
        pass = { target = target, escape = true, time = cfg.escape_time or 1.2,
            x = unit.x + dx / len * reach - dy / len * reach * side * 0.45 * unit.circle_direction,
            y = unit.y + dy / len * reach + dx / len * reach * side * 0.45 * unit.circle_direction }
        unit.sidestep_pass = pass
    end

    local x, y = target.x, target.y
    if pass then
        pass.time = pass.time - dt
        x, y = pass.x, pass.y
    else
        -- 接近段按目标速度少量前置，避免永远追在目标身后。
        local lead = math.min(cfg.lead_time or 0.3, distance / math.max(unit.speed, 1) * 0.2)
        x = x + (target.vx or 0) * lead
        y = y + (target.vy or 0) * lead
    end
    unit._approach_speed_multiplier = boost
    unit:_move_towards(x, y, unit.speed * boost * dt, game)
    local fired = unit:_try_attack(game)
    if fired and not pass then
        local angle = unit.angle + unit.circle_direction * (cfg.reposition_angle or 0.9)
        local length = cfg.reposition_distance or 150
        unit.sidestep_pass = { target = target, time = cfg.reposition_time or 0.6,
            x = unit.x + math.cos(angle) * length, y = unit.y + math.sin(angle) * length }
    end
    return true
end

-- ===== 直线压迫引擎 ====

function Common.clear_straight(unit)
    unit._approach_speed_multiplier = nil
end

-- cfg: too_close(刹车距离) gun_range(开火推进距离，默认 attack_range) approach_boost
function Common.fly_straight(unit, dt, game, cfg)
    local target = unit.attack_target
    if not Targeting.is_valid_enemy(unit, target) then return false end
    unit.state = "attacking"
    local distance = unit:distance_to(target)
    local gun_range = cfg.gun_range or unit.attack_range
    local too_close = cfg.too_close or unit.attack_range * 0.45
    local boost = distance > gun_range and (cfg.approach_boost or 1.15) or 1

    unit._approach_speed_multiplier = boost
    if distance > too_close then
        -- 突进/火力距离：航向目标（机头由推进模块控制），各武器按自身射界开火。
        unit:_move_towards(target.x, target.y, unit.speed * boost * dt, game)
    else
        -- 过近：刹车原地射击，机头追踪目标。
        Combat.aim(unit, target, dt)
    end
    unit:_try_attack(game)
    return true
end

return Common

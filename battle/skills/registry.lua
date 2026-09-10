-- 必杀技注册表：技能类型 -> 实现模块。每个实现提供
-- label / target_mode / can_execute(unit,game) / execute(unit,game)，
-- 可选 prepare(unit)（蓄力开始前锁定快照）。
-- 蓄力类（charge_beam/sweep/dash）共用"有效敌目标在技能射程内"判定与
-- skill_aim 快照；突进位移与轰炸任务队列的逐帧推进也挂在对应模块上，
-- 由 registry.tick / registry.update_dash 统一驱动。
local Registry = {}

function Registry.distance(x,y,ax,ay,bx,by)
    local dx,dy=bx-ax,by-ay
    local t=math.max(0,math.min(1,((x-ax)*dx+(y-ay)*dy)/math.max(1,dx*dx+dy*dy)))
    return math.sqrt((x-ax-t*dx)^2+(y-ay-t*dy)^2)
end

-- 蓄力类技能共用：目标有效且在技能射程内才可释放。
function Registry.aimed_can_execute(u)
    local t=u.skill_target or u.attack_target
    return t and t.alive and t.team~=u.team and u:distance_to(t)<=(u.skill_data.range or 1200)
end

-- 蓄力开始前锁定瞄准快照；释放按快照结算，目标可在此期间移出火线。
function Registry.aimed_prepare(u)
    local t=u.skill_target or u.attack_target
    if t then u.skill_aim={x=t.x,y=t.y,z=t.z or 0} end
end

local MODULE_FOR = {
    charge_beam = "battle.skills.charge_beam",
    sweep_bombardment = "battle.skills.sweep_bombardment",
    dash_strike = "battle.skills.dash_strike",
    orbital_bombardment = "battle.skills.orbital_bombardment",
    shield = "battle.skills.support",
    fleet_heal = "battle.skills.support",
    repair_tool = "battle.skills.support",
    buff_speed = "battle.skills.buffs",
    buff_attack = "battle.skills.buffs",
    rapid_fire = "battle.skills.buffs",
    missile_barrage = "battle.skills.missile_barrage",
    damage_aoe = "battle.skills.legacy",
    heal_aoe = "battle.skills.legacy",
    repair_all = "battle.skills.legacy",
    disable = "battle.skills.legacy",
    teleport = "battle.skills.legacy",
}

local cache = {}

function Registry.resolve(skill_type)
    local mod = MODULE_FOR[skill_type]
    if not mod then return nil end
    if cache[skill_type] == nil then
        local ok, m = xpcall(require, debug.traceback, mod)
        if not ok then error("Skill module failed to load: "..mod.."\n"..tostring(m), 0) end
        assert(type(m)=="table" and type(m[skill_type])=="table"
            and type(m[skill_type].execute)=="function",
            "Invalid skill implementation: "..mod.." for "..tostring(skill_type))
        cache[skill_type] = m[skill_type]
    end
    return cache[skill_type]
end

function Registry.prepare(unit)
    local impl = Registry.resolve((unit.skill_data or {}).type)
    if impl and impl.prepare then impl.prepare(unit) end
end

-- 逐帧技能推进：轰炸任务队列 + 突进位移的调用入口。
function Registry.tick(game,dt)
    require("battle.skills.sweep_bombardment").update(game,dt)
end

function Registry.update_dash(unit,dt,game)
    return require("battle.skills.dash_strike").update_dash(unit,dt,game)
end

return Registry

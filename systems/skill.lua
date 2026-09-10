-- 必杀技门面：对外保持 Skill.label / target_mode / can_execute / execute 签名，
-- 实现按类型分发到 battle/skills/ 注册表。单位、UI、AI 只经这里访问技能。
local Registry = require("battle.skills.registry")

local Skill = {}

function Skill.label(unit)
    local impl = Registry.resolve((unit.skill_data or {}).type)
    return (impl and impl.label) or "特殊装备"
end

function Skill.target_mode(unit)
    local impl = Registry.resolve((unit.skill_data or {}).type)
    return (impl and impl.target_mode) or "self"
end

function Skill.can_execute(unit, game)
    local impl = Registry.resolve((unit.skill_data or {}).type)
    return impl ~= nil and impl.can_execute ~= nil and impl.can_execute(unit, game)
end

function Skill.execute(unit, game)
    local impl = Registry.resolve((unit.skill_data or {}).type)
    if not impl then return end
    require("systems.skill_visuals").release(game, unit, (unit.skill_data or {}).type)
    impl.execute(unit, game)
end

return Skill

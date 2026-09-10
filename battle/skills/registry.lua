-- 必杀技注册入口。具体结算仍由 systems.skill 负责，避免本阶段改变技能行为。
local Registry={}
function Registry.resolve(skill_type)
    if type(skill_type)~="string" or skill_type=="" then return nil end
    return {type=skill_type}
end
return Registry

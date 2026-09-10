-- AI 数据层：人格权重、难度系数与战略修正，全部为纯配置。
-- 人格是舰队风格，难度是能力（反应、协同、技能判断），两者独立组合。
local Profiles = {}

-- 人格权重向量：效用评分的固定乘数，由关卡 data.ai.personality 选择。
Profiles.personalities = {
    aggressive = {
        attack_weight = 2.0,
        defend_weight = 0.5,
        retreat_weight = 0.3,
        repair_weight = 0.6,
        flank_weight = 1.5,
        focus_fire_weight = 1.5,
    },
    defensive = {
        attack_weight = 0.6,
        defend_weight = 2.0,
        retreat_weight = 1.5,
        repair_weight = 1.5,
        flank_weight = 0.4,
        focus_fire_weight = 0.8,
    },
    balanced = {
        attack_weight = 1.0,
        defend_weight = 1.0,
        retreat_weight = 0.8,
        repair_weight = 1.0,
        flank_weight = 1.0,
        focus_fire_weight = 1.2,
    },
    tricky = {
        attack_weight = 1.2,
        defend_weight = 0.8,
        retreat_weight = 1.2,
        repair_weight = 0.8,
        flank_weight = 2.0,
        focus_fire_weight = 1.0,
    },
}

-- 难度：reaction 是决策间隔（秒）；coordination 决定舰队服从集火的程度；
-- skill_smart 决定技能释放时机的判断力。
Profiles.difficulties = {
    easy   = { reaction = 0.8, coordination = 0.3, skill_smart = 0.4 },
    normal = { reaction = 0.3, coordination = 0.6, skill_smart = 0.7 },
    hard   = { reaction = 0.1, coordination = 0.85, skill_smart = 0.9 },
    insane = { reaction = 0.03, coordination = 0.95, skill_smart = 1.0 },
}

-- 战略修正：每 4 秒的力量对比审查（strategy.review）在人格权重之上
-- 再叠加的攻/防/撤乘数，让战略真正改变舰队行为。
Profiles.strategy_mods = {
    aggressive = {attack = 1.3, defend = 0.6, retreat = 0.5},
    defensive  = {attack = 0.7, defend = 1.5, retreat = 1.4},
    balanced   = {attack = 1.0, defend = 1.0, retreat = 1.0},
}

return Profiles

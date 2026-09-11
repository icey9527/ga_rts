return {
    map_scale = 2.0,
    hull_multiplier = 5.0,
    cooldown_multiplier = 1.6,
    damage_multiplier = 0.55,
    projectile_speed_multiplier = 0.9,
    missile_turn_rate = 1.65,
    lead_fraction = 0.65,
    -- 慢速炮击弹用全量前置和更小散布：直线型重火力的命中靠预测，
    -- 目标机动变向仍可躲开，但不再被匀速飞行无限戏耍。
    artillery_lead_fraction = 1.0,
    artillery_spread_factor = 0.55,
    spread_pixels = 18,
    passive_energy_per_second = 1.8,
    opening_grace = 18,
    skill_windup = 1.1,
    -- SP 来源：实际造成/承受的伤害，而不是开火次数。
    -- 造成伤害率对所有武器公平（击杀一艘同级舰≈同等 SP）；
    -- 承受伤害让重甲高受击单位自然更快充能；维修按实际修复量。
    -- sp_per_hit 是命中落点的小额回充：纯伤害率会让高频低伤武器
    -- （拦截机曳光）充能过慢，这一项把"打中"本身保持有价，
    -- 但量级远低于旧按发结算，不会回到刷必杀时代。
    sp_per_damage_dealt = 0.06,
    sp_per_damage_taken = 0.05,
    sp_per_hit = 0.4,
    sp_per_repair = 0.015,
}

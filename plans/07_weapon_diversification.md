# 计划 07：武器多元化——克制、拦截与过热差异化

## 目标

武器系统从"多条枪共享一套结算"升级为有相性的多元系统。基础已有：
每单位多武器（weapon.* 表）、每武器独立过热/冷却/射界均已实现。
本计划补三块：伤害类型克制、点防御拦截、过热差异化与可视化。

## 阶段 A：伤害/装甲类型克制

- `weapon.damage_class`：`kinetic`（动能）/ `energy`（能量）/ `explosive`（爆破），
  缺省 `kinetic`，不写就不参与克制（兼容存量配置）。
- `unit.armor_class`：`light` / `armored` / `capital`，机体表 [stats] 声明。
- 新建 `config/units/counters.lua` 克制表，例如：
  动能→轻甲加强、能量→装甲加强、爆破→群体/资本舰加强、
  轻甲受动能加重、装甲免疫部分动能。倍率范围先收敛在 0.75–1.35。
- 结算点：`battle/unit/projectile.lua` 生成弹体时把最终倍率乘入伤害快照
  （单一写入点，不进 take_damage）。
- `--fire-profile` 输出加 damage_class / armor_class 列，克制效果可实测。

## 阶段 B：点防御拦截（武器互相克制）

参考 GoK 的 DefenseFighter 与现代 RTS 的 PD 概念：

- 武器表加 `point_defense = true`（建议机枪/近防类）。
- 新建 `battle/unit/point_defense.lua`：PD 武器周期性索敌**敌方弹体**
  （导弹与炮击弹），命中判定按弹体半径；击落即销毁弹体（导弹优先级高于炮击弹）。
- PD 不打舰体：PD 武器从 `Combat.fire` 的舰船目标循环中排除，
  由 point_defense 模块独立驱动（独立冷却，不打断主武器节奏）。
- 拦截机/炮艇定位因此获得真实价值：护航拦截来袭导弹。
- 弹体侧：`battle/projectile.lua` 加 `interceptable` 标记（技能弹不可拦截，
  狙击弹高速不易拦——按 projectile_speed 折算可拦窗口）。

## 阶段 C：过热差异化 + 可视化

- 存量武器全部补齐 `heat_per_shot/max_heat/cool_rate` 三件套配置，
  让"持续压制"与"短促齐射"有机型差异（速射武器易过热需节奏管理，
  重炮低频不过热）。
- `ui` 属性面板（weapon_info）显示每武器热量条与过热状态。
- AI 执行器加一条简单规则：过热中的单位倾向脱离换位（复用 sidestep）。

## 验收

- [ ] 克制回归：同类武器打克制目标伤害 > 打非克制目标（快照断言）。
- [ ] 拦截回归：一批导弹飞向有 PD 的目标，被拦截比例 > 0 且随 PD 数量上升；
      无 PD 时拦截为 0；技能弹永不被拦。
- [ ] fire-profile 新列输出正确；全量 verify 绿。

## 前置

05（平衡实测）先定基线数值，避免克制表叠加在错误基线上。

## 完成后

删除本文件。

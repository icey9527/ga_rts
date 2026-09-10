# 计划 06：entities 拆迁入 battle + 特效归类

## 目标

删除根目录 `entities/` 文件夹：单位、弹道、特效全部并入 `battle/` 结构，
特效按"通用 vs 技能专属"归类。这是目录结构归位的最后一块主要拼图。

## 现状（2026-09-10 排查）

| 文件 | 行数 | 内容 |
| --- | --- | --- |
| `entities/unit.lua` | 575 | 构造+数值+受击（应归实体）；状态机分发+移动/攻击/跟随状态（应归状态）；返航/补给/离舰/维修支援流（应归后勤）；伪 3D 飞行层 |
| `entities/projectile.lua` | 266 | 实体弹（更新、命中结算、SP 回充、绘制） |
| `entities/effect.lua` | 270 | 13 种特效构造器：通用战斗系（hit_spark/explosion/beam）与技能专属系（charge/charged_beam/shield_glow/heal_pulse/skill_flash/skill_signature）混在一起 |

## 拆分方案

```
battle/unit/entity.lua      构造、数值、take_damage/heal、buffs（原 Unit.new 等）
battle/unit/states.lua      _update_state 及 moving/attacking/following 分支
battle/unit/logistics.lua   returning/supplying/undocking + repairing 支援流
battle/unit/flight.lua      伪 3D 高度层（_update_flight_layer/_base_altitude）
battle/projectile.lua       实体弹（原 entities/projectile.lua 整体迁移）
battle/effects/combat.lua   基类 + hit_spark/explosion/beam（战斗通用）
battle/effects/skill.lua    charge/charged_beam/shield_glow/heal_pulse/skill_flash/skill_signature
                            （技能族共享：charged_beam 同时被贯穿/突袭用，不散到单技能文件）
```

归类依据：特效被多个技能共用 → effects/skill.lua；只被弹道/受击用 → effects/combat.lua；
未来某特效只服务单一技能时，随该技能文件走（用户定的"看通用还是独占"原则）。

## 步骤

1. 先迁 projectile 与 effects（纯移动 + 全量改 require：main/ui/battle/skills/tools）。
2. unit.lua 按上表拆四文件，`Unit` 表由 entity.lua 组装（states/logistics/flight 作为
   混入模块，模式与 battle/ai 分层一致）。
3. 全仓把 `require("entities.*")` 清零后删除 `entities/` 文件夹。
4. 同步 verify 工具与 MAINTENANCE.md 结构表。

## 验收

- [ ] `entities/` 目录不存在；`grep -rn "entities%." --include=*.lua .`（除 dump/）零命中。
- [ ] 特效两文件职责清晰：技能模块不再直接引用 combat 系特效，反之亦然。
- [ ] `python tools/check_lua.py` 与 `lovec.exe . --verify` 全绿。

## 完成后

删除本文件。

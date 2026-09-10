# 计划 08：目录重组与残留清理

## 目标

`systems/` 只留"跨场服务"，战斗运行时归 `battle/`，任务编排归 `mission/`；
删除全部确认的死代码。前置：06（entities 拆迁）完成后执行，避免二次搬移。

## 已确认的死代码清单（2026-09-10 排查，删除项）

| 位置 | 说明 |
| --- | --- |
| `core/json.lua` | 全仓零引用 |
| `core/event.lua` | 全仓零引用 |
| `entities/effect.lua` 的 `Effect.unit_death` | 零调用（死亡走 explosion） |
| `battle/skills/legacy.lua` 的 teleport/disable/heal_aoe | 实现存在，无任何配置/关卡引用（damage_aoe 有 gunship 在用，保留） |
| `unit.repair_rate` 字段 | 读入后从未使用（维修是即时满血） |
| `config/gameplay.lua` 的 supply_rate/supply_hp_rate | 无读取方（补给即时满）——补给若改渐进式则启用，否则删 |

## systems/ 分流方案

```
battle/（战斗运行时，随 06 一并归位）
  navigation.lua、terrain.lua、space_scene.lua
  presentation/cinematic.lua、presentation/skill_visuals.lua、ship_renderer.lua

mission/（任务与编排）
  mission_script.lua、objectives.lua、simulation.lua（部署）、battle_flow.lua、
  economy.lua、minerals.lua、random_roster.lua

systems/（跨场服务，保留）
  audio、bgm、preferences、score、advisor、comms_slots、pack_registry、orders（玩家命令入口）
```

原则：只按运行职责分三层，不再细分；`orders` 留 systems 因为它是玩家输入侧
（命令写入仍经 battle/commands）。

## 步骤

1. 先删死代码清单（含 legacy 三技能及其 registry 映射、AI executor 对
   heal_aoe/disable 的判断分支同步清理）。
2. 逐组搬迁 + 全量改 require（battle/presentation、mission/ 两组）。
3. `levels/` 目录随计划 09 处理，此处不动。
4. MAINTENANCE.md 结构表重写为最终目录树。

## 验收

- [ ] 死代码清单全部删除；`grep` 零残留引用。
- [ ] `systems/` 只剩服务模块；根目录无 entities/。
- [ ] 全量 verify 绿。

## 完成后

删除本文件。
